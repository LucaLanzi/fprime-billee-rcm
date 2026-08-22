# Debugging This Project: A Practical Guide

This board's failure modes are almost never visible in the build log. The
firmware links cleanly, flashes, enumerates as a USB serial device, and can
still hang silently partway through boot, or crash after producing output
that looks completely normal. Every real bug found on this project so far
(USB enumeration timing, heap exhaustion — twice, a zombie GDS process) was
invisible until it was directly instrumented and captured on real hardware.
This document is the toolkit for doing that quickly instead of guessing.

For the specific, recurring heap-exhaustion failure mode, see ../README.md
Section 14.4 — this document covers the general workflow; that section
covers the heap-specific checklist and probe technique in detail.

## Before anything else: rule out the host side

A large fraction of "the firmware is broken" reports on this project have
turned out to be a stale process on the Mac/PC, not the board:

- **A zombie `fprime-gds` process** left over from a session killed by PID
  rather than by its whole process group. `uart_gds.sh` now self-heals this
  automatically on every `make gds`/`gds mac`/`gds wsl` (kills anything still
  bound to the dashboard port, plus stray `comm`/`CustomDataHandlers`
  processes, before starting). If GDS still looks wrong, check for other
  leftovers manually:
  ```
  ps -eo pid,ppid,command | grep -iE "flask|fprime"
  lsof -nP -iTCP:5000 -sTCP:LISTEN
  ```
- **A dictionary mismatch.** If GDS's `/dictionary/channels` metadata
  (`projectVersion`) doesn't match what the firmware itself reports in its
  `version` events, GDS is talking to a stale build or a stale process — not
  a firmware bug.

Only move on to instrumenting firmware once these are ruled out.

## The core tool: a reconnect-safe raw serial probe

`cat`/`stty` on macOS are not reliable for this board (see README Section
5.7) — they can silently show zero bytes even while the firmware is actively
transmitting. Use a small Python script instead:

```python
import os, sys, time, serial

device = os.environ.get("DEVICE", "/dev/cu.usbmodem2101")
end_time = time.time() + 60

while time.time() < end_time:
    try:
        port = serial.Serial(port=device, baudrate=115200, timeout=0.1,
                              rtscts=False, dsrdtr=False)
        port.dtr = True  # required -- without this, reads silently return nothing
        while time.time() < end_time:
            data = port.read(1024)
            if data:
                sys.stdout.buffer.write(data)
                sys.stdout.flush()
    except (serial.SerialException, OSError) as e:
        sys.stderr.write(f"reconnecting after: {e}\n")
        time.sleep(0.2)
```

Run it with the venv's Python (`fprime-venv/bin/python3 -u probe.py > capture.bin
2>capture.log &`), redirecting stdout to a file so binary CCSDS traffic
doesn't corrupt your terminal.

### Timing matters more than you'd expect

The board's actual boot delay (`k_sleep` in `Main.cpp`, currently 3000ms) is
short, and the burst of diagnostic text at the start of `setupTopology()`
often completes in under a second. A probe started *after* triggering a
reflash or reboot will frequently miss the whole thing, or catch only a
random tail fragment — this looks exactly like a firmware hang even when the
firmware is fine. **Always start the probe first, in the background, then
trigger the reboot/reflash — never the other way around:**

```
fprime-venv/bin/python3 -u probe.py > capture.bin 2>capture.log &
disown
# THEN put the board in BOOTSEL / power-cycle it
```

### Don't just capture-then-kill — poll for growth

A single "capture for N seconds, then read the file" pass can't tell you
whether a system that stopped producing bytes at second 3 is hung, or just
finished a burst and the next telemetry tick hasn't arrived yet by the time
you looked. Poll the file size at intervals instead, so you can see the
difference between "still growing" and "flatlined":

```
for i in $(seq 1 12); do
  echo "t=$((i*5))s: $(wc -c < capture.bin) bytes"
  sleep 5
done
```

A healthy, running system keeps growing indefinitely (periodic telemetry
never stops). A system that hit a fatal assert or a true hang plateaus at a
fixed byte count and never grows again, no matter how long you wait.

## Flashing (BOOTSEL) quirks

`make cpfirm mac` copies the UF2 while the board is mounted as a mass-storage
volume. Two things that look like failures usually aren't:

- **`cp: ... could not copy extended attributes ... Device not
  configured/Operation not permitted`** — this is almost always benign. The
  RP2350 bootloader resets the instant it receives the UF2's final block,
  often before macOS's `cp` finishes its own post-write metadata step. Check
  `/dev/cu.usbmodem*` immediately after — if the board re-enumerated as a
  serial device, the firmware write completed.
- **The BOOTSEL volume takes a few seconds to mount, and the serial device
  takes a few seconds to reappear after flashing.** Poll rather than assume
  either happened instantly:
  ```
  for i in 1 2 3 4 5 6 7 8; do
    if [ -d /Volumes/RP2350 ]; then echo "mounted"; break; fi
    sleep 3
  done
  ```

## Bisecting "did my change cause this?"

When a regression shows up after several changes accumulated in one session,
don't trust an inconclusive "it still fails after I revert X" result in
isolation — capture-timing noise (above) can make a perfectly fine build look
broken. The reliable way to settle it:

1. `git stash` every uncommitted change and rebuild+flash the exact
   last-committed state — the one you can point to a specific prior verified
   session for.
2. Test *that* build with the polling method above, for at least 30–60
   seconds of real wall-clock time.
3. Only if the true last-known-good state also fails are you looking at
   something outside your recent code changes (or, as happened once on this
   project, evidence you need to look harder rather than conclude
   "hardware" — see README Section 5.5's second incident for how that played
   out).
4. `git stash pop` to restore your work once the control test is done.

## Instrumenting project code: printk checkpoints

For project-owned files (`Main.cpp`, `rp2350Deployment/Top/
rp2350DeploymentTopology.cpp`) add `printk()` calls directly and rebuild
normally:

```cpp
#include <zephyr/sys/printk.h>
...
initComponents(state);
printk("CHECKPOINT: initComponents done\n");
```

**Always remove these before committing.** `printk` shares the same UART as
the F´ CCSDS binary downlink — leaving diagnostic prints in means every
future GDS session sees corrupted framing, which is its own confusing
failure mode (this happened during this project's own debugging more than
once).

## Instrumenting autocoded files (finer granularity)

Sometimes the checkpoints you need are *inside* a function F´'s autocoder
generates — `regCommands()` and `configComponents()` in
`build-fprime-automatic-zephyr/rp2350Deployment/Top/
rp2350DeploymentTopologyAc.cpp`, for instance, which lists every component's
individual `.regCommands()`/`.configure()`/`.setup()` call in sequence. You
can hand-patch this generated file directly to add a `printk()` between each
line — but:

- **Rebuild incrementally**, not with the full `make build-rp2350`:
  ```
  export FPRIME_FRAMEWORK_PATH="$(pwd)/lib/fprime"
  export PATH="$(pwd)/fprime-venv/bin:$PATH"
  fprime-venv/bin/fprime-util build zephyr
  ```
  The full `make build-rp2350` target runs `fprime-util generate ... -f`,
  which regenerates this file from scratch and silently discards your patch.
- Any change to instances.fpp/topology.fpp/config overrides forces a full
  regenerate anyway, which wipes autocoded-file patches — re-apply them
  after, or finish that instrumentation pass first.
- Remove the hand-patch (or just let the next full regenerate wipe it) once
  you're done — it's not meant to survive a commit.

## Quick decision guide

| Symptom | Likely cause | Where to look |
|---|---|---|
| GDS shows red/no traffic, but raw serial capture shows real data | Stale GDS/flask process on the host | "Before anything else" above |
| Boot produces some plausible output, then goes permanently silent | Heap exhaustion during `configComponents()`/`configureTopology()` | README 14.4 |
| `FW_ASSERT` naming a `BufferManager`/`Serializable`/similar file:line | Heap exhaustion — the named component is the victim, not necessarily the cause | README 14.4.2 (measure backward through the table) |
| Build fails after adding an active component | `CONFIG_DYNAMIC_THREAD_POOL_SIZE` not incremented, or a stack-size mismatch | README 14.1/14.2 |
| Identical symptom persists after reverting every recent change | Look harder before concluding "hardware" — re-verify with the polling method, not a single capture | "Bisecting" above |
