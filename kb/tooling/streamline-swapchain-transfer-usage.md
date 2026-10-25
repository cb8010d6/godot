---
type: Finding
title: Streamline pacer copies require transfer usage on real Vulkan swapchains
description: Full copy diagnostics expose an application swapchain usage omission, separately from SDK fake-layout and FG internal hazards.
tags: [vulkan, streamline, swapchain, validation]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The real swapchain requested only COLOR_ATTACHMENT. SL2.10/2.14 pacer command
buffers copy into it, including interpolation-off runs, producing 01213/06663
messages explicitly requiring TRANSFER_DST. Another diagnostic identifies
the fake source image's PRESENT_SRC/TRANSFER_SRC mismatch. SDK FG evaluation
also reports hazards on its own internal clear resources.

The candidate requests supported TRANSFER_SRC/DST with the active SL loader,
reports unsupported surfaces explicitly, and preserves normal no-SL usage and
the host's valid presentation layout. It does not guess a private fake-image
layout or patch proprietary libraries. Actual GPU comparison must distinguish
the fixed usage obligation from remaining layout/present/internal hazards.

At 6e157d1131 the standard editor build passed (39.828 s); all nine actual
backend/scene/probe cases completed. Requested usage 0x13 is supported by
surface flags 0x9f. VUID 01213/06663 disappear. SL2.14 retains fake-layout
09600 (absent with SL2.10), and both retain some present/semaphore/teardown
diagnostics. FG still reports SDK-owned clear/dispatch WAW/RAW and threading
diagnostics. This is a verified usage fix, not strict Vulkan acceptance.
