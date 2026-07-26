// ======================================================================
// \title  Main.cpp
// \brief Zephyr entry point for the RP2350 F Prime application
// ======================================================================

#include <rp2350Deployment/Top/rp2350DeploymentTopology.hpp>

#include <Os/Os.hpp>
#include <zephyr/kernel.h>

int main() {
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
    rp2350Deployment::startRateGroups(Fw::TimeInterval(1, 0));

    return 0;
}
