---
type: Mistake
title: A fresh fixture copy silently skipped its optional native probe
description: Require explicit GDExtension loading and state evidence before accepting runtime or FG activation checks.
tags: [testing, gdextension, streamline, provenance]
status: stable
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

A fresh rendered acceptance fixture retained its .gdextension and DLL but
omitted generated editor state. It only instantiated the probe if ClassDB
already contained its class, so a successful run could have no SDK-state file.
The direct NIS callback logs and Vulkan diagnostics remained actual evidence,
but they did not prove FG activation or loaded module provenance.

Explicitly load the extension at runtime if needed, require its expected
class, and fail dependent checks when state samples are empty. Do not call
an absent probe an engine defect, or claim earlier FG-requested runs establish
presented-two/foreground behavior. Retain the initial logs and rerun only the
checks whose evidence was missing.
