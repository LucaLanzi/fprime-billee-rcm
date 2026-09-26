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

**Power-ON is refused** (`VALIDATION_ERROR` plus a `PowerOnRejected` event
giving the reason) when:

- the E-STOP is engaged (`E_STOP_ENGAGED`),
- the E-STOP line can't be read (`E_STOP_UNKNOWN`, treated as engaged), or
- `fpManager` has latched a fault on that subsystem (`FAULT_LATCHED`). Send
  `fpManager.CLEAR_FAULT` first.

`OFF` is always accepted.

**A subsystem can also turn off without an operator command**, for two
reasons: the E-STOP was pressed (`EStopForcedOff`), or fpManager latched a
fault (`FaultInhibitSet` / `SubsystemFaultShutdown`). See
[Fault protection (`fpManager`)](#fault-protection-fpmanager).

### E-STOP behavior

There is no command to set or clear E-STOP — it's a physical safety input.
The hardware AND gates cut all 8 channels the instant it's pressed. The
firmware adds these rules:

- It polls the E-STOP line at 10 Hz. On the first poll that sees it engaged,
  every subsystem that was ON is forced OFF in software too
  (`EStopForcedOff`).
- **Releasing the E-STOP turns nothing back on.** Each subsystem has to be
  commanded ON again.
- While the E-STOP is engaged (or unreadable), every power-ON command is
  rejected.

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
| `SubsystemPowerModeEvent(subsystemName, powerState)` | Logged whenever a subsystem's state actually changes, whether from a command, an E-STOP force-off or a fault inhibit (not re-logged for a repeated state). |
| `EStopEngaged` | Logged once, on the transition to engaged. |
| `EStopReleased` | Logged once, on the transition to released. Nothing is re-enabled. |
| `EStopReadFailure` | The E-STOP line couldn't be read; it's treated as engaged. Logged once per failure episode. |
| `EStopForcedOff` | The E-STOP engaged while subsystems were ON; all were forced OFF. |
| `PowerOnRejected(subsystemName, reason)` | A power-ON command was refused: `E_STOP_ENGAGED`, `E_STOP_UNKNOWN` or `FAULT_LATCHED`. |
| `FaultInhibitSet(subsystemName)` / `FaultInhibitCleared(subsystemName)` | fpManager latched a fault inhibit (forced OFF, ON blocked), or released it after `CLEAR_FAULT`. Releasing never turns anything on. |
| `PowerWriteFailed(subsystemName)` | A GPIO write failed while switching a subsystem; all of its enables were driven OFF. |

The E-STOP events are edge-triggered — they fire once per transition, not
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
`power`, `sourceId`, `timestamp`, `valid`). Polled at 10 Hz.

| Channel | `sourceId` |
|---|---|
| `DRIVE1_POWER` … `DRIVE6_POWER` | `DRIVE1` … `DRIVE6` |
| `ARM_POWER` | `ARM` |
| `SCIENCE_POWER` | `SCIENCE` |
| `LOGIC_POWER` | `LOGIC` |

All nine channels update every poll cycle regardless of read success. A
failed read reports its last-known values (or zero, if never successful) with
**`valid = false`**, and fpManager ignores it: a failed read never looks like
a real 0 V reading.

**Note:** the DRIVE, ARM and SCIENCE sensors measure voltage on the switched
side, so `voltage` reads about 0 V whenever that channel is off. That's
normal. LOGIC measures the logic battery directly.

### Events

| Event | When it fires |
|---|---|
| `InaReadFailure` | Logged once, on the transition into "at least one sensor failing." Does not repeat every cycle while the failure persists. |
| `InaReadRecovered` | Logged once, when all sensors return to reading successfully after a prior failure. |
| `InaSensorLost(sensorId)` | One sensor has failed 10 consecutive reads (about 1 s). **Alert only:** that channel keeps running, but it has no current monitoring until the sensor recovers. |
| `InaSensorRecovered(sensorId)` | That sensor is reading again. |

## Fault protection (`fpManager`)

Software fault protection layered on the sensors above. Full source:
`lib/fprime-billee/Components/FPManager/`.

**How it works:**

- **Evaluated per sensor:** each INA780 reading is checked against its
  subsystem's bounds. A condition has to hold for several consecutive
  samples before it counts (debounce).
- **Overcurrent** (`|current|` above the limit) and **overvoltage** are
  checked all the time.
- **Undervoltage** is only checked while the subsystem is commanded ON *and*
  at least `UV_SETTLE_S` after it turned on. An OFF channel reads about 0 V,
  and that's normal. LOGIC is always checked.
- **Over-temperature:** an MCP9808 reporting `FAULT` for `DEBOUNCE_THERMAL`
  consecutive samples trips.
- **A fault latches.** DRIVETRAIN, ARM or SCIENCE is forced OFF and power-ON
  commands are rejected until you send `CLEAR_FAULT`. **One wheel faulting
  shuts off the whole drivetrain.** LOGIC can't be powered off (it's the
  computer running fpManager), so a LOGIC fault is alert-only.
- **Sensor loss is alert-only:** an unreadable INA780 or MCP9808 raises an
  event but never trips anything.

**With 30 A current limits, the drivetrain temperature sensor is the main
protection for the drive power copper.** The limits are set high on purpose
for initial testing. The drive pour heats up long before 30 A per wheel, so
watch `DRIVE_TEMP`.

### Commands

| Mnemonic | Argument | Effect |
|---|---|---|
| `fpManager.CLEAR_FAULT` | `subsystem: DRIVETRAIN / ARM / SCIENCE / LOGIC` | Clears a latched fault and releases the inhibit. **It does not turn anything on.** Rejected (`EXECUTION_ERROR`, `FaultClearRejected`) while that subsystem's temperature is still at `FAULT` level. If no fault is latched, it replies `OK` and logs `FaultClearNoop`. |

### Parameters (tunable thresholds)

Search `fpManager` in the mnemonic list. `*_BOUNDS` are structs with
`vbusFaultLow`, `vbusFaultHigh` and `currentFaultHigh`.

| Parameter | Default | Meaning |
|---|---|---|
| `DRIVETRAIN_BOUNDS` | 13.6 V / 17.2 V / 30 A | 4S pack. The current limit applies to **each wheel** sensor. |
| `ARM_BOUNDS` | 21.6 V / 25.5 V / 30 A | 6S pack |
| `SCIENCE_BOUNDS` | 21.6 V / 25.5 V / 30 A | 6S pack |
| `LOGIC_BOUNDS` | 21.6 V / 25.5 V / 30 A | 6S pack, alert-only |
| `UV_SETTLE_S` | 1.0 s | How long after power-ON before undervoltage is checked |
| `DEBOUNCE_OC` / `DEBOUNCE_OV` / `DEBOUNCE_UV` | 3 / 3 / 5 | Consecutive 10 Hz samples before a fault (about 0.3 / 0.3 / 0.5 s) |
| `DEBOUNCE_THERMAL` | 2 | Consecutive 1 Hz temperature samples before an over-temperature fault |

The bounds in effect are mirrored to `*_POWER_BOUNDS` telemetry. Parameters
may not persist across a reboot on this board, so the defaults above are what
runs unless you set them after boot.

### Telemetry

| Channel | Meaning |
|---|---|
| `DRIVETRAIN_FAULT_STATE` / `ARM_FAULT_STATE` / `SCIENCE_FAULT_STATE` / `LOGIC_FAULT_STATE` | `NOMINAL`, or `TRIPPED` (latched until `CLEAR_FAULT`). |
| `DRIVE1_POWER_STATE` … `LOGIC_POWER_STATE` | Evaluation of that sensor's latest reading: `NOMINAL`, `TRIPPED` (out of bounds this sample, before debounce), or `STALE` (read failed, not evaluated). |
| `*_POWER_BOUNDS` | Bounds in effect per subsystem |
| `FpReadingsDropped` | Readings lost to a full fpManager queue. Should stay 0. |

### Events

| Event | When it fires |
|---|---|
| `SubsystemFaultShutdown(subsystemName, reason)` | A fault latched and the subsystem was forced OFF. `reason`: `UNDERVOLTAGE`, `OVERVOLTAGE`, `OVERCURRENT`, `OVERTEMP`. |
| `PowerFaultDetail(sensorId, reason, voltage, current)` | Which sensor caused a power fault, and its reading. |
| `SubsystemFaultCleared(subsystemName)` | `CLEAR_FAULT` accepted. The subsystem is still OFF until commanded ON. |
| `LogicFaultDetected(reason)` / `LogicFaultCleared` | The LOGIC equivalents (alert-only). |
| `FaultClearRejected(subsystemName)` / `FaultClearNoop(subsystemName)` | `CLEAR_FAULT` was refused (still over-temperature), or there was nothing to clear. |
| `ThermalSensorLost(sensorId)` / `ThermalSensorRecovered(sensorId)` | An MCP9808 became unreadable or readable again. Alert only. |
| `FpReadingDropped` | The fpManager queue overflowed (once per boot). |

## Useful non-project commands

| Mnemonic | Opcode | Argument | Effect |
|---|---|---|---|
| `cmdDisp.CMD_NO_OP` | 0 | none | No-op. Good first command to send after connecting — confirms the uplink and command dispatcher are alive (look for the `NoOpReceived` event). |
| `cmdDisp.CMD_NO_OP_STRING` | 1 | `arg1: string` | Same as above, but echoes your string back in the `NoOpStringReceived` event — useful for confirming argument encoding round-trips correctly. |

## Command Responses

If a command doesn't come back `OK`, the Command History / Events tab will
show one of:

- **`VALIDATION_ERROR`** on a `SET_*_POWER_STATE ON`: the power-ON was
  refused on purpose. Check the `PowerOnRejected` event for the reason
  (E-STOP engaged or unreadable, or a latched fault).
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
2. Release the E-STOP. Confirm `subsystemManager.E_STOP_Status` reads `OFF`.
3. Check `fpManager.*_FAULT_STATE` for the subsystem. If it's `TRIPPED`, read
   the `SubsystemFaultShutdown` / `PowerFaultDetail` events, fix the cause,
   then send `fpManager.CLEAR_FAULT` for it.
4. Send the relevant `SET_*_POWER_STATE` command with `ON`.
   - `VALIDATION_ERROR` means it was refused: check `PowerOnRejected` for
     the reason.
5. Confirm the matching `SubsystemPowerModeEvent` fired and the `*PowerState`
   channel reads `ON`.
6. **After an E-STOP press or a fault trip, nothing comes back on by
   itself.** Repeat from step 2 or 3.
7. To power down, send `SET_*_POWER_STATE` with `OFF` (always accepted).
