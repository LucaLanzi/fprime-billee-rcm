# RP2350 Operator Manual: Sending Commands over F´ GDS

This is a quick-reference guide for operating the rover's subsystems through
the F´ Ground Data System (GDS) web UI. It assumes the board is already
flashed and connected -- see `README.md` for build/flash/connect
instructions. If you just need to get GDS running, jump to
[Connecting](#connecting) below; otherwise skip to
[Command Reference](#command-reference).

## Connecting

1. Plug the board in over USB and start GDS:
   ```
   make gds mac   # macOS
   make gds wsl   # WSL2/Windows
   make gds       # Linux
   ```
2. Open the printed URL, normally `http://127.0.0.1:5000`, in a browser.
3. Click the **Commanding** tab in the left-hand nav. This is where every
   command below is sent from.

If the page loads but nothing updates, see README.md Section 15
("Troubleshooting") -- the most common causes are a stale serial device path
or a zombie `fprime-gds` process holding the port.

## Sending a Command

In the Commanding tab:

1. Use the mnemonic dropdown/search box to find the command by name (e.g.
   `subsystemManager.SET_DRIVETRAIN_POWER_STATE`).
2. Fill in each argument. Enum arguments (like `Fw.On`) show as a dropdown --
   pick the value by name, not by number.
3. Click **Send**.
4. Check the **Command History** panel (or the Events tab) for the command's
   response: `OK` means it was accepted and executed; anything else is
   described in [Command Responses](#command-responses) below.

Every command in this project is `async`, meaning the response comes back on
the next available cycle, not instantaneously -- give it a moment before
assuming a command was dropped.

## Command Reference

All project-specific commands live on the `subsystemManager` component. Full
source: `lib/fprime-billee/Components/SubsystemManager/SubsystemManager.fpp`.

| Mnemonic | Opcode | Argument | Effect |
|---|---|---|---|
| `subsystemManager.SET_DRIVETRAIN_POWER_STATE` | 0 | `driveState: Fw.On` (`ON`/`OFF`) | Drives all six drivetrain motor enable pins (GPIO4-9) to the requested state together, as one unit. |
| `subsystemManager.SET_ARM_POWER_STATE` | 1 | `armState: Fw.On` (`ON`/`OFF`) | Drives the arm subsystem enable pin (GPIO10). |
| `subsystemManager.SET_AUX_POWER_STATE` | 2 | `auxState: Fw.On` (`ON`/`OFF`) | Drives the auxiliary subsystem enable pin (GPIO12). |
| `subsystemManager.SET_SCIENCE_POWER_STATE` | 3 | `scienceState: Fw.On` (`ON`/`OFF`) | Drives the science subsystem enable pin (GPIO11). |

All four enable pins are active-high: `ON` drives the pin high, `OFF` drives
it low. All six drivetrain pins are only ever set together -- there is no
per-motor command.

### E-STOP status is read-only

There is no command to set or clear E-STOP -- it's a physical safety input on
GPIO13, not something software can override. Its state is exposed as
telemetry/an event only (see below). **The subsystem power commands above do
not check E-STOP state before acting** -- the firmware will happily turn a
subsystem on even if E-STOP shows engaged. Always check
`subsystemManager.E_STOP_Status` in the Channels tab before sending a
power-on command.

### Useful non-project commands

| Mnemonic | Opcode | Argument | Effect |
|---|---|---|---|
| `cmdDisp.CMD_NO_OP` | 0 | none | No-op. Good first command to send after connecting -- confirms the uplink and command dispatcher are alive (look for the `NoOpReceived` event). |
| `cmdDisp.CMD_NO_OP_STRING` | 1 | `arg1: string` | Same as above, but echoes your string back in the `NoOpStringReceived` event -- useful for confirming argument encoding round-trips correctly. |

## What to Watch After Sending a Command

Switch to the **Channels** tab (telemetry) and/or **Events** tab to confirm
the command actually took effect -- a command `OK` response only means the
dispatcher accepted it, not that the underlying GPIO write succeeded.

### Telemetry (Channels tab, `subsystemManager` component)

| Channel | Meaning |
|---|---|
| `DrivetrainPowerState` | Current commanded state of the drivetrain enables (`ON`/`OFF`). |
| `ArmPowerState` | Current commanded state of the arm enable. |
| `SciencePowerState` | Current commanded state of the science enable. |
| `AuxPowerState` | Current commanded state of the auxiliary enable. |
| `E_STOP_Status` | Live read of the E-STOP input: `ON` = pulled LOW (E-STOP engaged), `OFF` = HIGH (released/normal). Updated every rate-group cycle regardless of commands. |

### Events (Events tab)

| Event | When it fires |
|---|---|
| `SubsystemPowerModeEvent(subsystemName, powerState)` | Logged whenever a `SET_*_POWER_STATE` command actually changes that subsystem's state (not re-logged if you send the same state twice in a row). |
| `EStopFirstHighEvent` | Logged exactly once, the first time E-STOP is read as HIGH (off) after boot. It will not fire again for the rest of that boot, even if E-STOP cycles LOW/HIGH afterward -- use `E_STOP_Status` telemetry to track ongoing state, not this event. |

## Command Responses

If a command doesn't come back `OK`, the Command History / Events tab will
show one of:

- **`EXECUTION_ERROR`** -- the GPIO write itself failed inside the driver
  (e.g. the pin never became ready). This means the command was received and
  attempted, but the hardware write did not succeed -- do not assume the
  subsystem changed state.
- **`INVALID_OPCODE`** / command not found in the mnemonic list -- you're
  likely running GDS against a stale dictionary from an older build. Rebuild
  (`make build-rp2350`) and restart GDS.
- No response at all -- check the Events tab for `CommandDroppedQueueOverflow`
  or `TooManyCommands`; otherwise this usually indicates a serial/connection
  problem rather than a firmware one (see README.md's macOS/WSL
  troubleshooting sections).

## Quick Checklist for a Power-On Sequence

1. Send `cmdDisp.CMD_NO_OP`, confirm `NoOpReceived` event -- link is alive.
2. Check `subsystemManager.E_STOP_Status` in the Channels tab -- confirm
   `OFF` before proceeding.
3. Send the relevant `SET_*_POWER_STATE` command with `ON`.
4. Confirm the matching `SubsystemPowerModeEvent` fired and the matching
   `*PowerState` telemetry channel reads `ON`.
5. To power down, repeat step 3 with `OFF`.
