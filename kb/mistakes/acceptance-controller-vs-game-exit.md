---
type: Mistake
title: Process exit alone does not pass an acceptance controller
description: Preserve failed controller assertions and rerun with production entry points and immutable inputs.
tags: [testing, windows, provenance]
status: stable
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The production release template did not execute an external script supplied by
the first game-export controller. The game exited zero, but the expected capture
marker was absent. A later controller incorrectly included SDK startup in a
wall-clock criterion for natural exit. Both failed records are retained in the
[acceptance report](../../devtools/acceptance/stabilization-20261026/REPORT.md).

Rerun the exported EXE and adjacent PCK through the production screenshot and
exit path, without `--path`, `--script` or a frame-count exit guard. Require the
actual captures, backend/version evidence, exit code and owned-child cleanup.
A timeout remains a failure guard, not a success condition.

Freeze and hash the controller, fixture, game adapter and engine before a GPU
matrix. If any input changes during execution, preserve the overall failure
even when individual cases pass, then repeat with fixed inputs. Do not rewrite
the original verdict from later observations.
