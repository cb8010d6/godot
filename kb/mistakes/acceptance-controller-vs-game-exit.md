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

## A custom MainLoop still needs the production main-scene guard

A later RT-readiness fixture exported a valid script/global-class cache, but
its release launch still failed: Main::setup checks a nonempty main_scene before
Main::start reads application/run/main_loop_type. Reviewing only the later
MainLoop-selection code missed this earlier guard. An import/export pass therefore
did not prove that the fixture actually started.

A separate private package with an empty bootstrap scene and the same custom
MainLoop passed the real release fixture. Preserve both original failures, retain
the template's disabled path overrides, and check the entire production entry
sequence. Public packaging edits need their own exact-tree runtime rerun. Keep
working checkout SHA, native version SHA and executable-byte hash separate.

Windows GUI executable launch through a bare PowerShell call can leave a stale
$LASTEXITCODE. Use the repository run_native.py console wrapper for import,
export and production launch: it waits, reports the actual exit and owns the
Windows Job/timeout/NGX cleanup instead of relying on a previous shell status.
