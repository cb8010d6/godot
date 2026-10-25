---
type: Mistake
title: Repeated GPU tests accumulated delayed NVIDIA updater children
description: Distinguish driver update process accumulation from engine heap leaks and contain test descendants.
tags: [windows, streamline, testing, memory, processes]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# Measured failure

Repeated Windows 10 / RTX 4060 / driver 610.88 / Streamline 2.14.16
launches left a peak of 386 NGX updater processes. They consumed roughly
9–10 GiB of private resident RAM, plus about 2 GiB in console hosts. Build
workers accounted for about 1.7 GiB. Original engine parents had exited.
Three samples without new GPU launches showed updater counts decreasing
361 → 354 → 347, with stable kernel pools. This is evidence of delayed
background process exit, not proof of a Godot heap or kernel driver leak.

# Correction and verification

Correlate each candidate's parent PID and creation interval with the test
receipt, recheck its exact image, command and creation time, and terminate
only confirmed test orphans. Never kill all processes by image name or
delete system caches. Cleanup ended 322 remaining confirmed updaters; their
consoles exited automatically. Available RAM recovered to about 16.4 GiB.

The smoke wrapper now owns directly launched native tests in a Windows job
with KILL_ON_JOB_CLOSE and checks updater counts before and after a run.
A real native child test and a complete SDK game both confirmed descendant
cleanup; the latter exited normally with 49 actual viewport captures and
zero updater residue. A Store/venv Python launcher did not inherit the job
in a control test, so arbitrary launchers are not claimed to be protected.
Assignment follows process creation; retain the census as a backstop.

Streamline OTA preferences do not disable the driver's separate NGX updater
or NVIDIA App overrides. Limit build concurrency and stop adding GPU
launches when investigating pressure. Keep original failures in the evidence.
