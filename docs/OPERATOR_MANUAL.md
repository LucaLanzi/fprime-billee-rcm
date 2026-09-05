# RP2350 Operator Manual

This is a quick-reference guide for operating the rover through the F´ Ground
Data System (GDS) web UI. It assumes the board is already flashed and
connected — see `../README.md` for build/flash/connect instructions. If you just
need to get GDS running, jump to [Connecting](#connecting) below; otherwise
skip to [Sending a Command](#sending-a-command) or the component references.

**Components covered:** `subsystemManager` (power control + E-STOP),
`mcpManager` (thermal sensing), `inaManager` (power/current sensing),
`fpManager` (fault protection).

## Connecting

1. Plug the board in over USB and start GDS:
   ```
   make gds mac   # macOS
   make gds wsl   # WSL2/Windows
   make gds       # Linux
   ```
2. Open the printed URL, normally `http://127.0.0.1:5000`, in a browser.
3. Click the **Commanding** tab in the left-hand nav to send commands; use
   **Channels** for telemetry and **Events** for the event log.

If the page loads but nothing updates, see ../README.md's Troubleshooting
section — the most common causes are a stale serial device path or a zombie
`fprime-gds` process holding the port.

## Sending a Command

In the Commanding tab:

1. Use the mnemonic dropdown/search box to find the command by name (e.g.
   `subsystemManager.SET_DRIVETRAIN_POWER_STATE`).
2. Fill in each argument. Enum arguments (like `Fw.On`) show as a dropdown —
   pick the value by name, not by number.
3. Click **Send**.
4. Check the **Command History** panel (or the Events tab) for the command's
   response: `OK` means it was accepted and executed; anything else is
   described in [Command Responses](#command-responses) below.

Every command in this project is `async`, meaning the response comes back on
the next available cycle, not instantaneously — give it a moment before
assuming a command was dropped.

## Subsystem power control (`subsystemManager`)

Full source: `lib/fprime-billee/Components/SubsystemManager/SubsystemManager.fpp`.

### Commands

| Mnemonic | Opcode | Argument | Effect |
|---|---|---|---|
| `subsystemManager.SET_DRIVETRAIN_POWER_STATE` | 0 | `driveState: Fw.On` (`ON`/`OFF`) | Drives all six drivetrain motor enable pins together, as one unit. |
| `subsystemManager.SET_ARM_POWER_STATE` | 1 | `armState: Fw.On` (`ON`/`OFF`) | Drives the arm subsystem enable pin. |
| `subsystemManager.SET_SCIENCE_POWER_STATE` | 3 | `scienceState: Fw.On` (`ON`/`OFF`) | Drives the science subsystem enable pin. |

All three enable pins are active-high: `ON` drives the pin high, `OFF` drives
it low. All six drivetrain pins are only ever set together — there is no
per-motor command. There is no command for the logic/flight-computer board —
it can't be power-cycled by anything running on it.

**FPManager can also turn a subsystem off on its own, without an operator
command** — see [Fault protection (`fpManager`)](#fault-protection-fpmanager)
below. If a subsystem you didn't command turns off, check the Events tab for
a `SubsystemFaultShutdown` before assuming a wiring or command problem.

### E-STOP status is read-only

There is no command to set or clear E-STOP — it's a physical safety input,
not something software can override. Its state is exposed as telemetry and
events only (below). **The subsystem power commands above do not check
E-STOP state before acting** — the firmware will happily turn a subsystem on
even if E-STOP shows engaged. Always check `subsystemManager.E_STOP_Status`
in the Channels tab before sending a power-on command.

### Telemetry

| Channel | Meaning |
|---|---|
| `DrivetrainPowerState` | Current commanded state of the drivetrain enables (`ON`/`OFF`). |
| `ArmPowerState` | Current commanded state of the arm enable. |
| `SciencePowerState` | Current commanded state of the science enable. |
| `E_STOP_Status` | Live read of the E-STOP input: `ON` = engaged, `OFF` = released/normal. Updated every rate-group cycle regardless of commands. |

### Events

| Event | When it fires |
|---|---|
| `SubsystemPowerModeEvent(subsystemName, powerState)` | Logged whenever a `SET_*_POWER_STATE` command, or FPManager's own emergency shutdown, actually changes that subsystem's state (not re-logged for a repeated state). |
| `EStopEngaged` | Logged once, on the transition from released to engaged. |
| `EStopReleased` | Logged once, on the transition from engaged to released. |

Both E-STOP events are edge-triggered — they fire once per transition, not
continuously while E-STOP stays in one state. Use `E_STOP_Status` telemetry
to check the *current* state at any given moment; use the events to know
*when* it last changed. If you attach GDS after a transition already
happened, you'll only see it in telemetry, not in the event log — see
../README.md's host-tooling notes on catching boot/transition-time events live.

## Thermal sensing (`mcpManager`)

Three MCP9808 I2C temperature sensors. Full source:
`lib/fprime-billee/Components/McpManager/`.

### Telemetry

Each channel carries a `Billee.ThermalReading` struct
(`temperature`, `tempState`, `sensorId`, `location`, `timestamp`):

| Channel | Sensor | `sensorId` | `location` |
|---|---|---|---|
| `LOGIC_TEMP` | Logic board MCP9808 | `LOGIC_TEMP` | `"Logic"` |
| `DRIVE_TEMP` | Drivetrain MCP9808 | `DRIVE_TEMP` | `"Drivetrain"` |
| `ARM_SCI_TEMP` | Arm/science MCP9808 (shared) | `ARM_SCI_TEMP` | `"ArmScience"` |

All three channels update every poll cycle regardless of whether their
sensor is currently reading successfully — a disconnected/failed sensor
reports `tempState: FAILURE` with `temperature: 0.0` rather than going
silent, so the channel is always current.

`tempState` values: `IDLE` (nominal), `WARN`, `FAULT` (in-range read, but
outside safe temperature bounds), `FAILURE` (sensor read failed — not
connected/detected), `NOT_USED` (not applicable).

### Parameters (tunable thresholds)

Set via GDS's Commanding tab (each param has its own `set`/`save` opcode) —
find them by searching `mcpManager` in the mnemonic list:

| Parameter | Default | Meaning |
|---|---|---|
| `MCP_IDLE_LOW` / `MCP_IDLE_HIGH` | 10 / 60 °C | Bounds of the `IDLE` temperature state |
| `MCP_WARN_LOW` / `MCP_WARN_HIGH` | -20 / 80 °C | Bounds of the `WARN` temperature state |
| `MCP_FAULT_LOW` / `MCP_FAULT_HIGH` | -40 / 100 °C | Beyond these, `FAULT` |

Current values are also mirrored to telemetry channels of the same name
(`MCP_IDLE_LOW`, etc.).

### Events

| Event | When it fires |
|---|---|
| `McpReadFailure` | Logged once, on the transition into "at least one sensor failing." Does not repeat every cycle while the failure persists. |
| `McpReadRecovered` | Logged once, when all sensors return to reading successfully after a prior failure. |

## Power/current sensing (`inaManager`)

Nine INA780B I2C power monitors: six drivetrain motors, plus arm, science,
and logic. Full source: `lib/fprime-billee/Components/InaManager/`.

### Telemetry

Each channel carries a `Billee.PowerReading` struct (`voltage`, `current`,
`power`, `sourceId`, `timestamp`):

| Channel | `sourceId` |
|---|---|
| `DRIVE1_POWER` … `DRIVE6_POWER` | `DRIVE1` … `DRIVE6` |
| `ARM_POWER` | `ARM` |
| `SCIENCE_POWER` | `SCIENCE` |
| `LOGIC_POWER` | `LOGIC` |

All nine channels update every poll cycle regardless of read success — a
failed sensor reports `voltage`/`current`/`power` at their last-known (or
zero, if never successful) values rather than going silent.

### Events

| Event | When it fires |
|---|---|
| `InaReadFailure` | Logged once, on the transition into "at least one sensor failing." Does not repeat every cycle while the failure persists. |
| `InaReadRecovered` | Logged once, when all sensors return to reading successfully after a prior failure. |

## Fault protection (`fpManager`)

Layers software fault protection on top of the sensors above: 6S LiPo
bus-voltage protection (in addition to the existing hardware failsafe),
overcurrent protection, and thermal-fault protection. On a fault, it
autonomously commands the affected subsystem off through `subsystemManager`
— bypassing the normal command path — and logs why. Full source:
`lib/fprime-billee/Components/FPManager/`.

**FPManager tracks DRIVETRAIN, ARM, SCIENCE, and LOGIC independently.** It
can power off DRIVETRAIN/ARM/SCIENCE. It **cannot** power off LOGIC — that's
the flight computer FPManager itself runs on — so a LOGIC fault is
alert-only.

### Parameters (tunable thresholds)

Find them by searching `fpManager` in the mnemonic list:

| Parameter | Default | Meaning |
|---|---|---|
| `VBUS_FAULT_LOW` | 19.2 V | Undervoltage trip point (3.2 V/cell for a 6S pack) |
| `VBUS_FAULT_HIGH` | 25.5 V | Overvoltage trip point (4.25 V/cell for a 6S pack) |
| `CURRENT_FAULT_HIGH` | 15.0 A | Overcurrent trip point, applied uniformly to every monitored subsystem |

Mirrored to telemetry channels of the same name.

### Telemetry

| Channel | Meaning |
|---|---|
| `DRIVETRAIN_FAULT_STATE` / `ARM_FAULT_STATE` / `SCIENCE_FAULT_STATE` / `LOGIC_FAULT_STATE` | `NOMINAL` or `TRIPPED` for that subsystem. Latched: stays `TRIPPED` until the underlying reading(s) return to nominal, independent of whether the subsystem has been manually re-enabled. |

### Events

| Event | When it fires |
|---|---|
| `SubsystemFaultShutdown(subsystemName, reason)` | DRIVETRAIN/ARM/SCIENCE tripped a fault and was commanded off. `reason` is one of `UNDERVOLTAGE`, `OVERVOLTAGE`, `OVERCURRENT`, `OVERTEMP`, `SENSOR_FAILURE`. |
| `SubsystemFaultCleared(subsystemName)` | That subsystem's fault condition cleared (readings back within nominal range). This does **not** mean the subsystem was turned back on — only that FPManager would no longer trip it right now. |
| `LogicFaultDetected(reason)` | LOGIC tripped a fault. Alert-only — FPManager cannot power-cycle its own flight computer. |
| `LogicFaultCleared` | LOGIC's fault condition cleared. |

All four events are edge-triggered (fire once per transition, not
continuously) — same caveat as the E-STOP events above about attaching GDS
after the transition already happened.

`reason: SENSOR_FAILURE` specifically means the trip was caused by a thermal
sensor reporting `FAILURE` (not connected/detected) rather than a real
in-range-but-unsafe temperature — worth distinguishing from `OVERTEMP` when
deciding whether a subsystem is actually overheating or its sensor is just
disconnected.

## Useful non-project commands

| Mnemonic | Opcode | Argument | Effect |
|---|---|---|---|
| `cmdDisp.CMD_NO_OP` | 0 | none | No-op. Good first command to send after connecting — confirms the uplink and command dispatcher are alive (look for the `NoOpReceived` event). |
| `cmdDisp.CMD_NO_OP_STRING` | 1 | `arg1: string` | Same as above, but echoes your string back in the `NoOpStringReceived` event — useful for confirming argument encoding round-trips correctly. |

## Command Responses

If a command doesn't come back `OK`, the Command History / Events tab will
show one of:

- **`EXECUTION_ERROR`** — the GPIO write itself failed inside the driver
  (e.g. the pin never became ready). The command was received and
  attempted, but the hardware write did not succeed — do not assume the
  subsystem changed state.
- **`INVALID_OPCODE`** / command not found in the mnemonic list — you're
  likely running GDS against a stale dictionary from an older build. Rebuild
  (`make build-rp2350`) and restart GDS.
- No response at all — check the Events tab for `CommandDroppedQueueOverflow`
  or `TooManyCommands`; otherwise this usually indicates a serial/connection
  problem rather than a firmware one (see ../README.md's troubleshooting
  sections).

## Quick Checklist for a Power-On Sequence

1. Send `cmdDisp.CMD_NO_OP`, confirm `NoOpReceived` event — link is alive.
2. Check `subsystemManager.E_STOP_Status` in the Channels tab — confirm
   `OFF` before proceeding.
3. Check `*_FAULT_STATE` on `fpManager` for the subsystem you're about to
   power — if it's already `TRIPPED`, powering on will very likely trip
   `SubsystemFaultShutdown` again immediately (FPManager doesn't check
   "who asked" before re-evaluating a fresh reading).
4. Send the relevant `SET_*_POWER_STATE` command with `ON`.
5. Confirm the matching `SubsystemPowerModeEvent` fired and the matching
   `*PowerState` telemetry channel reads `ON`.
6. Watch the Events tab briefly for a `SubsystemFaultShutdown` on that
   subsystem — a fault-driven shutoff right after a manual power-on means
   the underlying voltage/current/thermal condition is still bad, not that
   the command failed.
7. To power down, repeat step 4 with `OFF`.
