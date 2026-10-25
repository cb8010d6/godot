---
type: Finding
title: Abandoned RT pipelines must be released before their owned shaders
description: A Windows glass scene exposed an inherited dependency-order error during asynchronous pipeline shutdown.
tags: [pathtracing, vulkan, lifetime, regression]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# Reproduction

Run the procedural glass view with Vulkan PT, no Streamline DLLs, 400 frames
and a screenshot, then exit. A Windows RTX 4060 run at `b0d582c9f9` saved
the image and exited zero but logged `Attempted to free invalid ID` during
shutdown. Repeats on the pre-upgrade and stage A builds did not reproduce
the timing-dependent diagnostic. This does not establish an upgrade regression.

# Cause and local correction

`_free_task_owned_outputs()` freed newly compiled hit-group shaders before
their pipeline. RenderingDevice records shader-to-pipeline dependencies and
recursively frees dependent pipelines when a shader is freed. The subsequent
explicit pipeline release therefore uses a stale RID if a completed worker
result is abandoned at shutdown. This ordering is identical before stage A.

Release the owned pipeline first, then owned shaders, preserving borrowed
shader ownership. No validity guard suppresses the underlying diagnostic.
Keep this existing defect correction separate from the two upgrade branches.
The affected targets rebuilt; six Vulkan exits at 1, 20, 60, 180, 400 and
400 frames with glass/custom-shader cases no longer logged invalid RIDs.
This verifies those cases, not an exhaustive proof of asynchronous lifetime.
