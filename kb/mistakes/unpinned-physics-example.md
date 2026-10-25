---
type: Mistake
title: An unpinned example and its import cache are not a stable smoke fixture
description: A newer external example required APIs outside the vendored module and a warm cache hid its first-import errors.
tags: [testing, windows, physx, fixtures]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# What happened

The first Windows smoke used the external example's current HEAD. Its first
game launch lacked imported global script classes, and its full editor scan
also referenced newer PhysX APIs absent from the vendored module. A second
editor run reused the cache and did not repeat those unrelated scan errors.
It was therefore not evidence that the entire external example was compatible.

# Rule

Use a small repository-owned physical fall-and-settle scene for the default
engine smoke. External projects remain optional and need an explicit compatible
revision and a clean import. Keep their original failures in the evidence;
do not change the engine API or report the external HEAD as passing to satisfy
the fixture. Treat SCRIPT ERROR as a failure, and keep single-error results
as arrays so the complete diagnostic survives PowerShell pipeline unwrapping.

The first new scene run also exposed a GDScript inference error from a Variant
project setting; the boolean assertion now has an explicit type. Both Windows
editor variants then passed all four smoke groups, including the actual
fall-and-settle marker. Ignore the scene's local import cache and keep its UID.
