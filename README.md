# FprimeBilleeRcm F´ on RP2350

This deployment runs the complete F´ CDH, CCSDS communications, data-product,
file-handling, sequencing, health, telemetry, and rate-group topology on a
stock Raspberry Pi Pico 2 (`rpi_pico2/rp2350a/m33`). Communications use USB
CDC ACM, so the same USB connector used for BOOTSEL becomes a serial device
after the firmware starts.

## Build

From the project root in WSL/Linux:

```bash
make zephyr-rp2350
```

The flashable image is `build-artifacts/zephyr.uf2`. Run `make help` to see all
project commands.

## Flash

1. Unplug the Pico 2.
2. Hold BOOTSEL while plugging it into Windows.
3. Copy `build-artifacts/zephyr.uf2` to the `RP2350` mass-storage drive.
4. Wait for the drive to eject itself and the board to reboot.

BOOTSEL mode is only the bootloader and will not expose the F´ serial
connection. After reboot, Windows should show a new **USB Serial Device
(COMx)**. The development firmware identifies as USB `2FE3:0004`; `2E8A:000F`
is the separate RP2350 BOOTSEL device.

Check Windows PowerShell with:

```powershell
[System.IO.Ports.SerialPort]::GetPortNames()
Get-PnpDevice -Class Ports | Format-Table Status,FriendlyName,InstanceId
```

## Run GDS from WSL2

Windows owns USB devices by default. Install `usbipd-win`, then, after the
flashed board has rebooted, identify and attach the **USB Serial Device**:

```powershell
usbipd list
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

`bind` requires an Administrator PowerShell; `attach` does not. Keep WSL open
while attaching. In WSL, verify the result and start GDS:

```bash
ls -l /dev/ttyACM*
make gds-rp2350
```

If the device is not `/dev/ttyACM0`, select it explicitly:

```bash
UART_DEVICE=/dev/ttyACM1 make gds-rp2350
```

While attached to WSL, the device is unavailable to Windows applications. To
return it to Windows:

```powershell
usbipd detach --busid <BUSID>
```

See the end-user
[RP2350 F´/Zephyr Software Design Description](docs/RP2350_FPRIME_ZEPHYR_SDD.md)
for the complete fresh-machine procedure, architecture, verification gates,
and troubleshooting guide. See
[FPRIME_ZEPHYR_4_2_2.md](FPRIME_ZEPHYR_4_2_2.md) for compatibility-layer
details.
