// ======================================================================
// \title  rp2040DeploymentTopology.cpp
// \brief cpp file containing the topology instantiation code
// ======================================================================
#include <rp2040Deployment/Top/rp2040DeploymentTopologyAc.hpp>

#include <zephyr/device.h>
#include <zephyr/devicetree.h>

namespace rp2040Deployment {

U32 rateGroup1Context[Svc::ActiveRateGroup::CONNECTION_COUNT_MAX] = {};

void configureTopology() {
    rateGroup1.configure(rateGroup1Context, FW_NUM_ARRAY_ELEMENTS(rateGroup1Context));
    comDriver.configure(DEVICE_DT_GET(DT_CHOSEN(zephyr_console)), 115200);
}

void setupTopology(const TopologyState& state) {
    initComponents(state);
    setBaseIds();
    connectComponents();
    regCommands();
    configComponents(state);
    configureTopology();
    loadParameters();
    startTasks(state);
}

void startRateGroups(const Fw::TimeInterval& interval) {
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
    stopTasks(state);
    freeThreads(state);
    tearDownComponents(state);
    deinitComponents(state);
}

}  // namespace rp2040Deployment
