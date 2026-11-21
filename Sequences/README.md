# Sequences

Command sequences for the RCM (`rp2350Deployment`). Each `.seq` file is plain
text, one command per line. `cmdSeq` runs the commands one at a time and stops
at the first one that fails. Full syntax and workflow:
[`docs/OPERATOR_MANUAL.md` → Command sequences](../docs/OPERATOR_MANUAL.md#command-sequences-cmdseq).

Every command in these files is `R00:00:00`: it goes out as soon as the previous
one answers, so each sequence runs in milliseconds.

| Sequence | What it does |
|---|---|
| `Drivetrain-Teleop.seq` | Clears the DRIVETRAIN fault latch, then powers the drivetrain on. |
| `TestBoardDrivetrainTeleop.seq` | Clears the DRIVETRAIN and SCIENCE fault latches, exempts wheel 4 (`DRIVE4`) from fault protection, sets `SCIENCE_BOUNDS` to the drivetrain's 13.6 V / 35 V / 100 A, then powers on the drivetrain and science. The two parameter changes aren't saved, so a reboot reverts them. |

Neither sequence can get past an engaged E-STOP. The power-ON command is
refused (`PowerOnRejected`), and the sequence stops there. Release the button
and run the sequence again.

## Running them

1. Build the firmware so the dictionary exists (`make build-rp2350`). Then
   `make sequences` compiles every `.seq` here into
   `build-artifacts/sequences/<name>.bin`. A typo or a wrong argument fails
   at this step instead of on the board.
2. Upload: either paste or load the `.seq` in the GDS **Sequence** tab and press
   **Uplink** (it compiles and sends to `/lfs/seq/<name>.bin`), or upload the
   `.bin` to `/lfs/seq/` from the **Uplink** tab. Wait for `FileReceived`.
3. `cmdSeq.CS_VALIDATE /lfs/seq/<name>.bin`, then
   `cmdSeq.CS_RUN /lfs/seq/<name>.bin BLOCK`.

Uploaded sequences stay on the board across reboots and reflashes, so step 2
is only needed when a sequence changes. **Before uploading a changed version,
delete the old one:** `fileManager.RemoveFile /lfs/seq/<name>.bin false`.
