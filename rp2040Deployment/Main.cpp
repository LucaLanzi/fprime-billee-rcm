// ======================================================================
// \title  Main.cpp
// \brief Zephyr entry point for the RP2040 F Prime application
// ======================================================================

#include <rp2040Deployment/Top/rp2040DeploymentTopology.hpp>

#include <Os/Os.hpp>

int main() {
    Os::init();

    rp2040Deployment::TopologyState inputs{};
    inputs.uartDevice = nullptr;
    inputs.baudRate = 115200;

    rp2040Deployment::setupTopology(inputs);
    rp2040Deployment::startRateGroups(Fw::TimeInterval(1, 0));

    return 0;
}
