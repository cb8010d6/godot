---
type: Finding
title: Viewport RT startup readiness uses live shaders and recorded trace commands
description: Bounded editor and real-GPU checks cover a loading gate; release and full integration validation remain pending.
tags: [pathtracing, shaders, startup, testing]
status: draft
generated: { by: codex, at: 2026-10-26T17:06:08Z }
---

# RT startup readiness

The loading gate requires the actual selected viewport/camera/environment and
current RT pipeline variant to render. Resource preloading alone does not
register all required hit groups. Global compile queues or a fixed delay do not
prove a scene is ready.

Four `ViewportRenderInfo` values are appended after the unchanged values 0..7:

| Value | Name suffix | Meaning |
| --- | --- | --- |
| 8 | RT_SHADER_PENDING | Encountered required surfaces with an HG absent from the live variant |
| 9 | RT_SHADER_FAILED | Encountered preprocessing/HG/displacement/pipeline publication failures |
| 10 | RT_DISPATCHES | Trace commands recorded with valid pipeline/bindings and nonempty TLAS |
| 11 | RT_FRAME_SERIAL | Positive, per-viewport recorded trace serial; wraps to 1 |

These cheap statistics and TLAS count are available in release templates.
RendererViewport already supplies RenderInfo in every build and clears its full
array at the beginning of each drawn viewport. A viewport not drawn retains old
values: never interpret old zero pending as ready. Read serial before/after the
other counters, discard mixed snapshots, and require fresh serials for every
active viewport after `frame_post_draw`. Two fresh ready snapshots are a render
loading criterion, not a GPU-completion fence or physical presentation check.
The public script `raytracing_list_trace_rays()` signature remains void. A native
checked helper returns true only after adding the actual trace command to the
draw graph; every rejection returns false and prevents serial advancement. PT
records a failure instead of reporting an attempted/rejected dispatch as ready.

Pending uses `is_hg_ready_in_bundle()` / `live_ready_mask`, not the worker's
HGState::Ready before pipeline/SBT publication. Counts only cover encountered
materials in this viewport's rt_flags variant. Procedural early skips are
included. Failed source/preprocessing gets a failed slot (including zero RT
source hashes) rather than returning default HG0. Source hashes remain distinct
on reload, so an old live shader cannot certify a new pending/failed source.
Publication errors are latched for required non-live slots. Nothing waits on
unrelated variants or synchronously drains the global shader lane.
Required-slot failures are re-read after displacement preparation, so a newly
failed compute shader is included in the same frame. Pending preserves whether
the recorded TLAS/material buffers used a fallback before late publication.

Unsupported drivers or absent API must be distinguished by capability checks;
no active PT camera/environment is not applicable. A supported PT viewport with
no fresh recorded command/nonempty TLAS is not rendered, not ready. Shader
failure and timeout must retain an explicit failed state and a recovery action.

Native fixture: `misc/pathtracer_test_project/readiness_regression/readiness.gd`.
Run it with a new output directory on editor AND installed release template.
It covers a disabled second viewport, both real views becoming live-ready,
new source after a previous live shader and a new samples-per-pixel variant.
Real center pixels must remain green or change to blue as specified. Finally
an RT-only invalid identifier must report a failure instead of two ready frames;
its compiler error is intentional and must remain in the native log. Do not
apply a whole-run zero-error rule to this explicit negative case.
`pending_observed=false` on a warm run
must not be described as a reproduced cold transition. Inspect real PNGs too.

Further fault/interaction coverage to track separately:

- Inject the previous `INV_VIEW_MATRIX` helper-front-end error and a pipeline
  publication failure: each must fail, never become HG0
  ready or timeout-success. Keep intentional shader-error logs.
- Disable one viewport after an earlier ready frame; stale serial must block.
- Empty/no-camera/non-PT/official-engine cases are explicit not-applicable.
- Cancel, map/scene replacement, window close and timeout restore viewport
  update modes, and never run a late completion into the next scene.
- Under the cover record physical bodies, shot clock and phase_time unchanged;
  actual RT serials must still advance. Exercise 1/2/4 players and production
  PCK entry, standard/Mono and official 4.7.2 compatibility.

## First bounded measurements

Native commit `5470fe8dde76c43c16f67db64020319ea82ce788` builds the Windows
standard editor in 1178.422 seconds with Jobs 2. Its independent visible Vulkan
fixture passes in 19.406 seconds on RTX 4060 Laptop GPU. A real pending
transition is observed; both views have fresh live-ready serials, green/blue
pixels pass after source and variant changes, and the intentional RT-only
invalid identifier reports failed=1 instead of ready. Its expected compiler
errors remain in the log. This is not a whole-run zero-error test.

Game commit `3d51851c6eec09ff4cb8a2b0f818e837d06ca4e8` passes seven sequential
CPU checks, official 4.7.2 import and candidate import. The first private real
skating observation passes: two actual gates complete before PLAY, independent
viewport readbacks confirm readiness, clocks and physics have no observed
pause violation, and the first near PNG restores the building/ground/awning
details. This observer selects the real catalog scene and demo roster before
ready; it is not the production CLI/export entry test.

Cancellation, timeout, bad-shader recovery, more layouts/scenes, standard/Mono
smoke and installed release-template checks remain separate pending work at
this checkpoint. Existing A738 evidence stays frozen. No new model, FG,
latency, strict-clean or long-term performance result is claimed.
