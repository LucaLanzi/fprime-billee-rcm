// ======================================================================
// \title  Main.cpp
// \brief Zephyr entry point for the RP2350 F Prime application
// ======================================================================

#include <rp2350Deployment/Top/rp2350DeploymentTopology.hpp>

#include <Os/Os.hpp>
#include <Fw/Types/Assert.hpp>

#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/kernel.h>

namespace {

void waitForGdsConnection() {
    const struct device* const uart = DEVICE_DT_GET(DT_CHOSEN(zephyr_console));
    FW_ASSERT(device_is_ready(uart));

    U32 dtr = 0;
    while ((uart_line_ctrl_get(uart, UART_LINE_CTRL_DTR, &dtr) != 0) || (dtr == 0)) {
        k_sleep(K_MSEC(100));
    }
}

}  // namespace

int main() {
    Os::init();

    // Do not start F Prime until the host has opened the USB CDC port. This
    // prevents startup events and the initial communications-ready signal from
    // being emitted before the USB class can transmit.
    waitForGdsConnection();

    rp2350Deployment::TopologyState inputs{};
    inputs.uartDevice = nullptr;
    inputs.baudRate = 115200;

    rp2350Deployment::setupTopology(inputs);
    rp2350Deployment::startRateGroups(Fw::TimeInterval(1, 0));

    return 0;
}
