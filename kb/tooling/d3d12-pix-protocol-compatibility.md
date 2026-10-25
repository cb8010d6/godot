---
type: Finding
title: Keep GPU PIX markers compatible with system debug layers
description: Distinguish marker protocol rejection from native callback resource and binding errors.
tags: [d3d12, pix, validation, compatibility]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

At eb9cd21be9 the paired D3D12 debug SR/NIS/FG controls no longer report
the original resource state (#527/#538) and descriptor heap (#708) errors.
The remaining messages are CORRUPTED_PARAMETER1 (#3) from BeginEvent, seen
with SL2.10 and SL2.14. They must not be silently filtered or assumed to be
SDK resource failures. One SR run times out and the final SDK2.10 NIS run
was interrupted for the user's fullscreen HUD observation; neither passes.

The inherited engine marker encoder unconditionally emits PIX3BLOB_V2
metadata 6345127. Microsoft's installed WinPixEventRuntime headers deliberately
use compatible metadata 2 for GPU calls, preserving older tool/runtime support:
[official protocol explanation](https://github.com/microsoft/PixEvents).

Use that compatible GPU packet, including event type, color and ANSI string
descriptor, with context implicit in the command-list call. Names and colors
remain recorded; debug validation and markers stay enabled. No runtime DLL or
new dependency is introduced. Actual legacy/factory debug comparison remains
required before attributing or declaring the marker diagnostics fixed.
