// ======================================================================
// \title  Main.cpp
// \brief Zephyr entry point for the RP2350 F Prime application
// ======================================================================

#include <rp2350Deployment/Top/rp2350DeploymentTopology.hpp>

#include <Os/Os.hpp>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/init.h>
#include <zephyr/kernel.h>

namespace {

// Subsystem power-enable outputs (billee-gpio-outputs in the board overlay), all active-high.
const gpio_dt_spec kSafeOutputs[] = {
    GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_1), gpios), GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_2), gpios),
    GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_3), gpios), GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_4), gpios),
    GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_5), gpios), GPIO_DT_SPEC_GET(DT_NODELABEL(drive_enable_6), gpios),
    GPIO_DT_SPEC_GET(DT_NODELABEL(arm_enable), gpios),     GPIO_DT_SPEC_GET(DT_NODELABEL(science_enable), gpios),
};

bool g_safeOutputsDone = false;

// Drive every power-enable output LOW as early as the GPIO driver allows, instead of leaving the
// pins in their reset state through Zephyr boot and the 3 s USB delay in main(). Idempotent:
// configureTopology() configures the same pins again later.
int billeeSafeOutputs() {
    for (const gpio_dt_spec& pin : kSafeOutputs) {
        if (gpio_is_ready_dt(&pin)) {
            (void)gpio_pin_configure_dt(&pin, GPIO_OUTPUT_INACTIVE);
        }
    }
    g_safeOutputsDone = true;
    return 0;
}

// POST_KERNEL runs after the GPIO driver (PRE_KERNEL_1) and before USB/application init.
int billeeSafeOutputsInit() {
    return billeeSafeOutputs();
}

}  // namespace

SYS_INIT(billeeSafeOutputsInit, POST_KERNEL, 0);

int main() {
    // Backstop in case the SYS_INIT entry was ever dropped at link time.
    if (!g_safeOutputsDone) {
        (void)billeeSafeOutputs();
    }

    // Give the USB CDC-ACM interface time to enumerate before the application
    // starts writing to it -- writes attempted too early are silently dropped,
    // not queued. A flat delay (rather than polling for host DTR) is what's
    // proven to work across hosts, since not every OS's CDC-ACM driver relays
    // DTR reliably.
    k_sleep(K_MSEC(3000));

    Os::init();

    rp2350Deployment::TopologyState inputs{};
    inputs.uartDevice = nullptr;
    inputs.baudRate = 115200;

    rp2350Deployment::setupTopology(inputs);
    // 10 Hz base tick; divided into 10 Hz / 1 Hz / 0.25 Hz rate groups (rp2350DeploymentTopology.cpp).
    rp2350Deployment::startRateGroups(Fw::TimeInterval(0, 100000));

    return 0;
}
