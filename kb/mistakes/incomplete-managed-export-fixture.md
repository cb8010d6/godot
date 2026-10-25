---
type: Mistake
title: An editor fixture also needs a solution before managed export
description: Create a complete managed project and inspect export errors before trusting a successful process exit.
tags: [testing, mono, export]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# What happened

The C# editor smoke built its project file directly. Reusing that fixture
for game export omitted the solution that Godot's export workflow expects.
The editor returned zero but logged managed-export errors. The log check
rejected the result before any success claim.

# Rule

Create the real solution and export presets before moving a fixture across
the editor/export boundary. Require clean export logs, expected PCK and
managed outputs, and successful execution of the exported game. Both Linux
managed exports passed after fixing the fixture, without an engine change.
