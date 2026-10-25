---
type: Mistake
title: A managed smoke needs the managed runtime environment
description: Preserve explicit SDK discovery when starting a Mono editor from a fresh command.
tags: [testing, mono, environment]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# What happened

A Mono debug-template PCK check started its export editor from a fresh shell
without the out-of-tree .NET SDK on PATH or DOTNET_ROOT. Export failed during
hostfxr discovery before the game test ran. The same command with the managed
build's SDK environment passed all 88 checks without an engine change.

# Rule

Treat SDK discovery and the runtime loader environment as test inputs. Verify
them before interpreting a managed startup failure. The portable smoke keeps
the caller's SDK selectors while isolating its project and user profile.
PowerShell 7 also needs writable XDG cache/config directories in a restricted
host; its startup failure before the fixture runs is not a script regression.
