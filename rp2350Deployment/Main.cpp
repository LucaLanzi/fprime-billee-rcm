// ======================================================================
// \title  Main.cpp
// \brief Zephyr entry point for the RP2350 F Prime application
// ======================================================================

#include <rp2350Deployment/Top/rp2350DeploymentTopology.hpp>

#include <Os/Os.hpp>

int main() {
    Os::init();

    rp2350Deployment::TopologyState inputs{};
    inputs.uartDevice = nullptr;
    inputs.baudRate = 115200;

    rp2350Deployment::setupTopology(inputs);
    rp2350Deployment::startRateGroups(Fw::TimeInterval(1, 0));

    return 0;
}
