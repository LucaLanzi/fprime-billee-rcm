// ======================================================================
// \title  rp2350DeploymentTopology.cpp
// \brief cpp file containing the topology instantiation code
//
// ======================================================================
// Provides access to autocoded functions
#include <rp2350Deployment/Top/rp2350DeploymentTopologyAc.hpp>
// Note: Uncomment when using Svc:TlmPacketizer
//#include <rp2350Deployment/Top/rp2350DeploymentPacketsAc.hpp>

// Necessary project-specified types
#include <Fw/Types/MallocAllocator.hpp>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/gpio.h>

// Public functions for use in main program are namespaced with deployment module rp2350Deployment
// This is also the namespace where the topology components are instantiated by FPP.
namespace rp2350Deployment {

// Instantiate a malloc allocator for cmdSeq buffer allocation
Fw::MallocAllocator mallocator;

// Subsystem power-enable outputs (billee-gpio-outputs container in the board overlay).
// All active-high, all must come up inactive/low.
static const gpio_dt_spec driveEnable1Pin = GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_1), gpios);
static const gpio_dt_spec driveEnable2Pin = GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_2), gpios);
static const gpio_dt_spec driveEnable3Pin = GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_3), gpios);
static const gpio_dt_spec driveEnable4Pin = GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_4), gpios);
static const gpio_dt_spec driveEnable5Pin = GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_5), gpios);
static const gpio_dt_spec driveEnable6Pin = GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_6), gpios);
static const gpio_dt_spec armEnablePin = GPIO_DT_SPEC_GET(DT_NODELABEL(arm_enable), gpios);
static const gpio_dt_spec scienceEnablePin = GPIO_DT_SPEC_GET(DT_NODELABEL(science_enable), gpios);
static const gpio_dt_spec auxEnablePin = GPIO_DT_SPEC_GET(DT_NODELABEL(aux_enable), gpios);

// E-STOP status input (active-low: pulled LOW = on, HIGH = off).
static const gpio_dt_spec eStopStatusPin = GPIO_DT_SPEC_GET(DT_NODELABEL(estop_status), gpios);

/**
 * \brief configure and open a single subsystem power-enable output
 *
 * Configures the pin as an output initialized inactive/low, then hands it to the
 * ZephyrGpioDriver instance. A failed GPIO does not abort deployment startup; it is
 * only reported so the remaining outputs can still be brought up.
 */
static bool configureGpioOutput(Zephyr::ZephyrGpioDriver& driver, const gpio_dt_spec& pin) {
    if (!gpio_is_ready_dt(&pin)) {
        return false;
    }

    if (gpio_pin_configure_dt(&pin, GPIO_OUTPUT_INACTIVE) != 0) {
        return false;
    }

    if (driver.open(pin, Zephyr::ZephyrGpioDriver::OUT) != Os::File::Status::OP_OK) {
        return false;
    }

    return gpio_pin_set_dt(&pin, 0) == 0;
}

/**
 * \brief configure and open a single subsystem status input
 *
 * Configures the pin as an input and hands it to the ZephyrGpioDriver instance.
 * ZephyrGpioDriver::open() applies GPIO_INPUT itself, so the devicetree's own
 * flags (e.g. the E-STOP line's internal pull-up) are what take effect. A
 * failed GPIO does not abort deployment startup; it is only reported so the
 * remaining configuration can still proceed.
 */
static bool configureGpioInput(Zephyr::ZephyrGpioDriver& driver, const gpio_dt_spec& pin) {
    if (!gpio_is_ready_dt(&pin)) {
        return false;
    }

    return driver.open(pin, Zephyr::ZephyrGpioDriver::IN) == Os::File::Status::OP_OK;
}

// The reference topology divides the incoming clock signal (1Hz) into sub-signals: 1Hz, 1/2Hz, and 1/4Hz with 0 offset
Svc::RateGroupDriver::DividerSet rateGroupDivisorsSet{{{1, 0}, {2, 0}, {4, 0}}};

// Rate groups may supply a context token to each of the attached children whose purpose is set by the project. The
// reference topology sets each token to zero as these contexts are unused in this project.
U32 rateGroup1Context[Svc::ActiveRateGroup::CONNECTION_COUNT_MAX] = {};
U32 rateGroup2Context[Svc::ActiveRateGroup::CONNECTION_COUNT_MAX] = {};
U32 rateGroup3Context[Svc::ActiveRateGroup::CONNECTION_COUNT_MAX] = {};

/**
 * \brief configure/setup components in project-specific way
 *
 * This is a *helper* function which configures/sets up each component requiring project specific input. This includes
 * allocating resources, passing-in arguments, etc. This function may be inlined into the topology setup function if
 * desired, but is extracted here for clarity.
 */
void configureTopology() {
    // Rate group driver needs a divisor list
    rateGroupDriver.configure(rateGroupDivisorsSet);

    // Rate groups require context arrays.
    rateGroup1.configure(rateGroup1Context, FW_NUM_ARRAY_ELEMENTS(rateGroup1Context));
    rateGroup2.configure(rateGroup2Context, FW_NUM_ARRAY_ELEMENTS(rateGroup2Context));
    rateGroup3.configure(rateGroup3Context, FW_NUM_ARRAY_ELEMENTS(rateGroup3Context));

    // Command sequencer needs to allocate memory to hold contents of command sequences
    cmdSeq.allocateBuffer(0, mallocator, 5 * 1024);

    // Use the UART selected as Zephyr's console for F Prime communications.
    comDriver.configure(DEVICE_DT_GET(DT_CHOSEN(zephyr_console)), 115200);

    // Bring up the subsystem power-enable outputs, inactive/low at boot.
    configureGpioOutput(drive1EnableGpio, driveEnable1Pin);
    configureGpioOutput(drive2EnableGpio, driveEnable2Pin);
    configureGpioOutput(drive3EnableGpio, driveEnable3Pin);
    configureGpioOutput(drive4EnableGpio, driveEnable4Pin);
    configureGpioOutput(drive5EnableGpio, driveEnable5Pin);
    configureGpioOutput(drive6EnableGpio, driveEnable6Pin);
    configureGpioOutput(armEnableGpio, armEnablePin);
    configureGpioOutput(scienceEnableGpio, scienceEnablePin);
    configureGpioOutput(auxEnableGpio, auxEnablePin);

    // Bring up the E-STOP status input.
    configureGpioInput(eStopStatusGpio, eStopStatusPin);
}

void setupTopology(const TopologyState& state) {
    // Autocoded initialization. Function provided by autocoder.
    initComponents(state);
    // Autocoded id setup. Function provided by autocoder.
    setBaseIds();
    // Autocoded connection wiring. Function provided by autocoder.
    connectComponents();
    // Autocoded command registration. Function provided by autocoder.
    regCommands();
    // Autocoded configuration. Function provided by autocoder.
    configComponents(state);
    // Project-specific component configuration. Function provided above. May be inlined, if desired.
    configureTopology();
    // Autocoded parameter loading. Function provided by autocoder.
    loadParameters();
    // Autocoded task kick-off (active components). Function provided by autocoder.
    startTasks(state);
}

void startRateGroups(const Fw::TimeInterval& interval) {
    // The timer component drives the fundamental tick rate of the system.
    // Svc::RateGroupDriver will divide this down to the slower rate groups.
    // This call will block until the stopRateGroups() call is made.
    // For this Linux demo, that call is made from a signal handler.
    const U32 intervalMs = static_cast<U32>(interval.getSeconds() * 1000U) +
                           static_cast<U32>(interval.getUSeconds() / 1000U);
    timer.configure(intervalMs);
    timer.start();
    while (true) {
        timer.cycle();
    }
}

void stopRateGroups() {
    timer.stop();
}

void teardownTopology(const TopologyState& state) {
    // Autocoded (active component) task clean-up. Functions provided by topology autocoder.
    stopTasks(state);
    freeThreads(state);

    // Resource deallocation
    cmdSeq.deallocateBuffer(mallocator);

    tearDownComponents(state);
    deinitComponents(state);
}
};  // namespace rp2350Deployment
