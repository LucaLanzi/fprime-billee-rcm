# F Prime 4.2.2 and fprime-zephyr Compatibility Guide

## Summary

F Prime 4.2.2 and the current `fprime-zephyr` integration are close to
compatible, but they come from different points in the development of F Prime.
The project therefore needed a small compatibility layer and several changes
from Linux-oriented defaults to Zephyr-oriented behavior.

The required changes were:

1. **Load Zephyr before F Prime.** The top-level CMake file now initializes
   Zephyr before declaring the project. This gives Zephyr an opportunity to
   select the RP2350 board, SDK, compiler, device tree, and application target
   before F Prime configures the deployment.

2. **Make the RP2350 deployment part of the main build.** The deployment was
   added to the top-level CMake tree. Without this, Zephyr created its
   application target but never received `Main.cpp` or the F Prime topology.

3. **Use a project-local deployment helper for F Prime 4.2.2.** Newer
   `fprime-zephyr` expects an installation helper and a counting-semaphore
   target that do not exist in F Prime 4.2.2. The project now supplies the
   minimal compatibility behavior from its own `cmake` directory. Neither the
   F Prime nor `fprime-zephyr` submodule is modified.

4. **Replace Linux components with Zephyr components.** The generated
   deployment originally used a Linux timer, Linux UART driver, desktop clock,
   command-line arguments, and operating-system signals. These were replaced
   with the Zephyr rate driver, Zephyr UART driver, Zephyr time provider, and an
   embedded `main()` function that runs continuously.

5. **Connect and configure the Zephyr UART.** The UART now uses the console
   device selected by Zephyr's device tree at 115200 baud. Its receive polling
   port is connected to a rate group because the Zephyr driver does not use the
   Linux UART driver's background receive thread.

6. **Adjust F Prime's task storage for Zephyr 4.3.** Zephyr's task object is
   larger than the storage reserved by F Prime 4.2.2. A project configuration
   override increases the task-handle storage so the Zephyr task implementation
   fits safely.

7. **Size the complete topology for embedded RAM.** No F Prime subtopology is
   removed. The desktop queue, buffer, catalog, sequence, parameter, telemetry,
   and 64 KiB task-stack capacities are replaced with RP2350 capacities. All 16
   active components use the configured Zephyr task pool.

8. **Route the console through USB CDC ACM.** A Pico 2 board overlay creates a
   CDC ACM UART below the USB device controller and selects it as
   `zephyr,console`. The F Prime UART driver uses that chosen device.

9. **Use Zephyr's expected configuration filename and build environment.** The
   Kconfig file is named `prj.conf`, and the Python virtual environment must be
   activated so that `fprime-util` finds the correct CMake, Python, West, and
   FPP tools.

With these changes, the project generates and builds successfully for
`rpi_pico2/rp2350a/m33`, produces a UF2 image and F Prime dictionary, and uses
approximately 9.64% of flash and 73.51% of statically linked RAM. This leaves
about 138 KiB for queues, communication buffers, catalogs, and other runtime
heap allocations. Physical-board behavior still requires hardware validation.

This project uses F Prime `v4.2.2`, Zephyr `v4.3.0`, and a newer revision of
`fprime-community/fprime-zephyr`. These versions do not work together without
several project integrations and compatibility adjustments. This document
records the changes required to generate and build the RP2350 firmware.

## Tested environment

- F Prime: `v4.2.2`
- fprime-zephyr: commit `8ef1f4e62c6ee4f04598fdb25ceb82b645687af5`
- Zephyr: `v4.3.0`
- Zephyr SDK: `0.17.4`
- West: `1.5.0`
- Board: `rpi_pico2/rp2350a/m33`
- Host: WSL2/Linux

Always activate the project virtual environment before generating or building:

```bash
source fprime-venv/bin/activate
```

Calling `fprime-venv/bin/fprime-util` without activating the environment is not
equivalent. Programs launched by `fprime-util`, including CMake and Python,
must also resolve from `fprime-venv/bin`. Without activation, WSL may select the
system CMake 3.22 instead of the required CMake 3.24.2 or newer.

## Required project structure

The integration expects the following important paths:

```text
.
├── .west/config
├── CMakeLists.txt
├── prj.conf
├── settings.ini
├── west.yml
├── FprimeBilleeRcm/Config/
├── lib/fprime/
├── lib/fprime-zephyr/
├── lib/zephyr-workspace/
└── rp2350Deployment/
```

The Zephyr Kconfig file must be named `prj.conf`. Zephyr automatically selects
that filename; `proj.conf` is not the conventional auto-detected name.

## Top-level CMake integration

Zephyr must be loaded before the top-level `project()` call:

```cmake
cmake_minimum_required(VERSION 3.24.2)

if (NOT BUILD_TESTING)
    find_package(Zephyr HINTS "${CMAKE_CURRENT_LIST_DIR}/lib/zephyr-workspace")
endif()

project(FprimeBilleeRcm C CXX)
```

This ordering allows Zephyr to create its `app` target and configure the board,
SDK, compiler, Kconfig, and device tree before F Prime initializes.

The deployment must also be added to the top-level build:

```cmake
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/FprimeBilleeRcm")
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/rp2350Deployment")
```

Without the second call, `rp2350Deployment/Main.cpp` is never attached to
Zephyr's `app` target, and configuration fails with:

```text
No SOURCES given to target: app
```

## F Prime library registration

`settings.ini` must expose `fprime-zephyr` as an F Prime library:

```ini
[fprime]
project_root: .
framework_path: ./lib/fprime
library_locations: ./lib/fprime-zephyr
```

The Python environment must contain `west`. This project installs it through
`requirements-zephyr.txt` and the `zephyr-setup` Make target.

## Zephyr deployment registration

The deployment uses the project-local
`register_fprime_zephyr_4_2_2_deployment` compatibility helper instead of the
normal `register_fprime_deployment`:

```cmake
include("${FPRIME_PROJECT_ROOT}/cmake/register_fprime_zephyr_4_2_2_deployment.cmake")

register_fprime_zephyr_4_2_2_deployment(
        ${FPRIME_CURRENT_MODULE}
    SOURCES
        "${CMAKE_CURRENT_LIST_DIR}/Main.cpp"
    DEPENDS
        ${FPRIME_CURRENT_MODULE}_Top
)
```

This helper mirrors `fprime-zephyr`'s registration behavior: it adds `Main.cpp`
to Zephyr's `app` target, links the topology, and creates the F Prime dictionary
and artifact installation targets.

## Counting-semaphore compatibility target

The tested `fprime-zephyr` revision selects an implementation named
`Os_CountingSemaphore_Stub`. That target belongs to a newer F Prime interface
and does not exist in F Prime 4.2.2.

The project provides an empty interface target after F Prime and its libraries
have been loaded:

```cmake
if (NOT TARGET Os_CountingSemaphore_Stub)
    add_library(Os_CountingSemaphore_Stub INTERFACE)
endif()
```

This is safe for this deployment because it does not use the newer counting
semaphore interface. If counting semaphores are introduced later, replace this
shim with a real implementation or update the pinned F Prime version.

## Project-local artifact installation helper

The tested `fprime-zephyr` revision normally invokes:

```text
lib/fprime/cmake/target/fprime_install.cmake
```

That helper was introduced after F Prime 4.2.2. No file is added to the F Prime
submodule. Instead,
`cmake/register_fprime_zephyr_4_2_2_deployment.cmake` registers the deployment
and runs the generated installer directly:

```cmake
COMMAND "${CMAKE_COMMAND}" -E env
    "DESTDIR=${FPRIME_INSTALL_DEST}"
    "${CMAKE_COMMAND}"
    -DCMAKE_INSTALL_PREFIX=/
    -DCMAKE_INSTALL_COMPONENT=fprime-zephyr-binaries
    -P "${CMAKE_BINARY_DIR}/cmake_install.cmake"
```

It places the Zephyr binaries in `build-artifacts` without modifying either the
F Prime or `fprime-zephyr` submodule. The helper also uses a project-local
`cmake/zephyr_empty.cpp` placeholder for the deployment library.

Long term, prefer pinning compatible F Prime and `fprime-zephyr` revisions so
this backported helper is unnecessary.

## F Prime configuration overrides

Project-specific overrides are registered from
`FprimeBilleeRcm/Config/CMakeLists.txt`:

```cmake
register_fprime_config(
    INTERFACE
    CONFIGURATION_OVERRIDES
        "${CMAKE_CURRENT_LIST_DIR}/PlatformCfg.fpp"
        "${CMAKE_CURRENT_LIST_DIR}/TlmChanImplCfg.hpp"
)
```

The configuration directory must be added before ordinary project components:

```cmake
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/Config")
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/Components")
```

### Zephyr task-handle size

F Prime 4.2.2 defaults `FW_TASK_HANDLE_MAX_SIZE` to 40 bytes. With Zephyr 4.3,
the `Os::Zephyr::Task::ZephyrTask` implementation is 168 bytes. The default
therefore causes this compile-time failure:

```text
static assertion failed: Handle size not large enough
note: the comparison reduces to '(168 <= 40)'
```

`FprimeBilleeRcm/Config/PlatformCfg.fpp` overrides the platform configuration
and sets:

```fpp
constant FW_TASK_HANDLE_MAX_SIZE = 192
```

The extra space allows for alignment and modest implementation changes. The
remaining platform constants currently match the F Prime 4.2.2 defaults.

### Telemetry database size

F Prime's default `TlmChanImplCfg.hpp` reserves 500 telemetry hash buckets.
Each bucket contains storage for a full telemetry value, causing `Svc::TlmChan`
to consume roughly 590 KiB in this configuration. The RP2350 has 520 KiB of
RAM, so the default cannot link.

`FprimeBilleeRcm/Config/TlmChanImplCfg.hpp` reduces the database to:

```cpp
TLMCHAN_NUM_TLM_HASH_SLOTS = 15
TLMCHAN_HASH_MOD_VALUE = 99
TLMCHAN_HASH_BUCKETS = 96
```

The bucket count must remain greater than or equal to the number of telemetry
channels used by the deployment. Revisit this setting whenever components or
telemetry channels are added.

## Replacing Linux-only components

The generated deployment initially used components intended for desktop Linux.
Those components are excluded by the Zephyr platform and cause undefined FPP
symbols or link failures.

The deployment instance replacements are:

| Linux component | Zephyr component |
| --- | --- |
| `Svc.LinuxTimer` | `Zephyr.ZephyrRateDriver` |
| `Drv.LinuxUartDriver` | `Zephyr.ZephyrUartDriver` |
| `Svc.ChronoTime` | `Zephyr.ZephyrTime` |

`Svc.ChronoTime` must not be used here because its standard-library clock path
requires `gettimeofday`, which is not supplied by this Zephyr configuration.

## Zephyr UART setup

The UART driver is configured using Zephyr's chosen console device:

```cpp
#include <zephyr/device.h>
#include <zephyr/devicetree.h>

comDriver.configure(
    DEVICE_DT_GET(DT_CHOSEN(zephyr_console)),
    115200
);
```

Unlike `Drv::LinuxUartDriver`, `Zephyr::ZephyrUartDriver` does not start a
dedicated POSIX receive thread. Its `schedIn` port must be driven periodically:

```fpp
rateGroup1.RateGroupMemberOut[5] -> comDriver.schedIn
```

The deployment already connects the UART's allocation and deallocation ports
to the communications buffer manager.

## Zephyr rate driver

`Zephyr::ZephyrRateDriver` uses a Zephyr kernel timer. It is configured in
milliseconds, started once, and then cycled continuously:

```cpp
const U32 intervalMs = static_cast<U32>(interval.getSeconds() * 1000U) +
                       static_cast<U32>(interval.getUSeconds() / 1000U);
timer.configure(intervalMs);
timer.start();

while (true) {
    timer.cycle();
}
```

The stop helper maps to `timer.stop()`. On the embedded target, the main loop
normally runs for the lifetime of the firmware.

## Zephyr entry point

The deployment `Main.cpp` must not depend on desktop process facilities. The
Zephyr entry point removes:

- `argc` and `argv`
- `getopt`
- POSIX signals
- `SIGINT` and `SIGTERM`
- Linux UART device paths
- desktop teardown after Ctrl-C

The embedded entry point initializes the F Prime OS layer, constructs topology
state, sets up the topology, and enters the rate-driver loop:

```cpp
int main() {
    Os::init();

    rp2350Deployment::TopologyState inputs{};
    inputs.uartDevice = nullptr;
    inputs.baudRate = 115200;

    rp2350Deployment::setupTopology(inputs);
    rp2350Deployment::startRateGroups(Fw::TimeInterval(1, 0));
    return 0;
}
```

The `uartDevice` field remains in `TopologyState` for compatibility with the
generated deployment structure, but it is not used by the Zephyr UART setup.

## Embedded capacity overrides

`prj.conf` configures Zephyr's dynamic thread stack size as 8 KiB. F Prime
active-component stack sizes must match that value when using the current
Zephyr task implementation:

```fpp
constant STACK_SIZE = 8 * 1024
```

The original generated deployment requested 64 KiB per active component,
which was unsuitable for RP2350 RAM and inconsistent with the configured
Zephyr dynamic thread pool. The pool contains 16 stacks because the complete
topology starts 16 active components. The upstream `fprime-zephyr` sample uses
8 KiB as its proven default; the smaller 4 KiB experimental size did not leave
enough margin for this complete topology.

The RP2350 override also retains each service while reducing desktop-scale
capacity:

- bounded CDH, CCSDS, data-product, and file-handling message queues;
- six normal and two file communications buffers;
- two data-product buffers and a 16-file data-product catalog;
- a 128-statement Fpy sequence dictionary and 2 KiB sequence stack;
- eight parameter-database entries (the current dictionary has no parameters).

These limits control how much work may be buffered simultaneously; they do not
remove components or ports.

## USB CDC ACM console

`boards/rpi_pico2_rp2350a_m33.overlay` creates a `zephyr,cdc-acm-uart` device
under the RP2350 USB device controller and selects it as `zephyr,console`.
`prj.conf` enables the new Zephyr USB device stack and initializes CDC ACM at
boot. Consequently, runtime firmware enumerates as a serial device instead of
using UART0 on GPIO 0 and GPIO 1.

The RP2350 entry point waits for the host to assert the CDC DTR signal before
constructing and starting the F Prime topology. This prevents startup events
and the communications-ready signal from being emitted before the USB class
can transmit. GDS or another serial client must open the CDC port before F
Prime begins running.

## Generate and build

From the project root:

```bash
make zephyr-rp2350
```

The verified build produced:

```text
FLASH: 404192 B / 4 MB      9.64%
RAM:   391448 B / 520 KB   73.51%
```

Important output files are:

```text
build-artifacts/zephyr.uf2
build-artifacts/zephyr.elf
build-artifacts/zephyr.map
build-artifacts/zephyr/fprime-zephyr-deployment/dict/
    rp2350DeploymentTopologyDictionary.json
```

## WSL2 USB setup and GDS

WSL2 cannot access the RP2350 USB device directly until Windows shares it
through USB/IP. Installing `usbipd-win` and binding the device are one-time
host setup steps. Attaching the device must be repeated after Windows or WSL
restarts, the board is unplugged, or the board changes between BOOTSEL and
runtime mode.

### Install usbipd-win

Open Windows PowerShell as Administrator and install `usbipd-win` if it is not
already installed:

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

Restart WSL after installation:

```powershell
wsl --shutdown
```

### Identify and bind the runtime device

Flash `build-artifacts/zephyr.uf2`, allow the BOOTSEL drive to eject, and
reconnect the board normally. In Windows PowerShell, list the USB devices:

```powershell
usbipd list
```

Select the runtime device with VID:PID `2fe3:0004`, shown as `USB Serial Device`
or `F Prime UART Communication`. Do not select the `RP2 Boot` mass-storage
device. Its BUSID may differ from this example:

```text
BUSID  VID:PID    DEVICE                    STATE
2-4    2fe3:0004  USB Serial Device (COM4)  Not shared
```

In Windows PowerShell as Administrator, bind that BUSID:

```powershell
usbipd bind --busid 2-4
```

Binding authorizes the device for USB/IP and normally only needs to be done
once. Run `usbipd list` again and confirm the state is `Shared`.

### Attach the device to WSL

Keep a WSL terminal open. In a separate, ordinary Windows PowerShell window,
attach the bound device to the active WSL2 distribution:

```powershell
usbipd attach --wsl --busid 2-4
usbipd list
```

The Windows-side state should now be `Attached`. Verify the Linux device from
the WSL terminal:

```bash
lsusb
ls -l /dev/ttyACM*
```

A working attachment resembles:

```text
2-4    2fe3:0004  USB Serial Device (COM4)  Attached
Bus 001 Device 002: ID 2fe3:0004 NordicSemiconductor F Prime UART Communication
crw-rw---- 1 root dialout ... /dev/ttyACM0
```

The BUSID, USB bus/device numbers, COM port, and `/dev/ttyACM` number can change.
Use the values reported on the current machine.

### Grant serial-port permission

The CDC ACM device is normally accessible only to `root` and members of the
`dialout` group. Add the current WSL user to that group:

```bash
sudo usermod -aG dialout "$USER"
```

Close all WSL terminals, then run the following from Windows PowerShell:

```powershell
wsl --shutdown
```

Reopen WSL and keep its terminal open. In Windows PowerShell, attach the USB
device again:

```powershell
usbipd attach --wsl --busid 2-4
```

Then verify from WSL that `dialout` appears in the current user's groups and
that the serial device exists:

```bash
id
ls -l /dev/ttyACM*
```

If invoking `powershell.exe` from WSL reports `Exec format error`, WSL's
Windows-executable interoperability handler is unavailable in that session.
Run `wsl --shutdown` from a real Windows PowerShell window, reopen WSL, and run
the `usbipd` commands directly in Windows PowerShell as shown above. USB
attachment does not require launching PowerShell from inside WSL.

### Start GDS

With the RP2350 attached and `/dev/ttyACM0` available:

```bash
make gds-rp2350
```

If Linux assigned another device number, select it explicitly:

```bash
UART_DEVICE=/dev/ttyACM1 make gds-rp2350
```

Open the URL printed by GDS, normally `http://127.0.0.1:5000`. The message
`gio: http://127.0.0.1:5000/: Operation not supported` only means WSL could not
open the browser automatically; it does not indicate a GDS failure.

USB enumeration alone does not make the GDS connection indicator green. The
indicator turns green after GDS receives valid framed F Prime traffic. If it
remains red, first confirm that the user belongs to `dialout`, no serial
terminal has `/dev/ttyACM0` open, and the board was flashed from the same build
that produced the GDS dictionary. Then run GDS with detailed logging:

```bash
./uart_gds.sh --log-to-stdout --log-level-gds DEBUG
```

The launcher uses UART at the API value 115200 and
`space-packet-space-data-link` CCSDS framing. If `/dev/ttyACM*` disappears,
repeat the `usbipd attach` command. To detach the device deliberately:

```powershell
usbipd detach --busid 2-4
```

## Remaining considerations

### RAM headroom

The linker reports only static RAM. F Prime allocates component queues,
communications buffers, the sequencer buffer, and catalog storage at runtime
from the remaining heap. Recheck both the map and on-hardware startup whenever
queue depths, buffer counts, telemetry channels, or active components grow.

### Hardware validation

Successful compilation and generated-output inspection verify CMake, FPP
autocoding, all 16 matching task stacks, CDC ACM device-tree selection, UF2
family metadata, dictionary generation, and artifact installation. They do not
replace a physical-board test of USB enumeration, runtime stack margins,
filesystem behavior, or GDS traffic.

### Version upgrades

The counting-semaphore target and install helper are compatibility shims caused
by mixing F Prime 4.2.2 with a newer `fprime-zephyr`. When upgrading either
submodule:

1. Check whether `Os_CountingSemaphore_Stub` exists in F Prime.
2. Check whether the project-local deployment registration helper is still needed.
3. Re-evaluate `FW_TASK_HANDLE_MAX_SIZE` against the compiler's reported size.
4. Re-check telemetry bucket count and total RAM usage.
5. Perform a clean generate and build.
