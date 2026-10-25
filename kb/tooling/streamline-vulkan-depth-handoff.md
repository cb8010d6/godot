---
type: Finding
title: Rejected depth interpretation of swapchain copy diagnostics
description: The R32F candidate did not change the VUIDs; complete messages identify pacer transfer usage and fake swapchain layout instead.
tags: [streamline, vulkan, depth, synchronization, testing]
status: deprecated
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The c76e671d0d depth experiment built and ran nine actual cases without
changing 01213/06663/09600. The VUID names were over-interpreted as depth
issues. Full messages instead show the SL pacer's copy destination lacks
TRANSFER_DST usage and a fake swapchain buffer has a layout mismatch.

The ineffective conversion is removed precisely, retaining all earlier
NIS/depth/camera integrations and the experiment's logs. Use the complete
message, resource identity, usage, command region and chronology before
choosing a fix. Do not describe this as a resolved depth bug.
