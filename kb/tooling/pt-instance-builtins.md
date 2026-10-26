---
type: Finding
title: Path-traced custom materials need real MultiMesh shader inputs
description: Actual Vulkan pixel and lifetime regressions verify real MultiMesh inputs and geometry-owner isolation; original failures and strict-validation limits remain retained.
tags: [pathtracing, shaders, multimesh, regression]
status: stable
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

# Reproduction and cause

An actual Windows Vulkan game on RTX 4060 / driver 610.88 at native revision
`c1fc0252a9` saved failed closest-hit GLSL for crowd and foliage materials.
The crowd vertex code referenced `instance_custom`; foliage referenced
`rt_instance_id`. The PT compiler renamed the valid spatial shader built-ins
but its shared hit-stage globals did not declare or populate either value.
Replaying the exact dumps confirmed both undeclared-identifier failures.
This path already existed before the 4.8 beta 1 integration.

Compiling a declaration with a constant zero would not restore the shader's
meaning. MultiMesh shaders use their logical instance index, custom RGBA and
instance color. The merged-BLAS optimization also bakes instance transforms
into positions, losing the mesh-local `VERTEX` used by custom vertex code.

# Scoped correction

The internal geometry layout now carries logical instance ID, custom RGBA and
color. Host size and field-offset assertions match the GLSL std430 layout.
Custom shaders that read these inputs or run vertex code use the existing
expanded-TLAS path, preserving each logical instance's transform. Its values
come from the current MultiMesh data, using the same optional color/custom
offsets as raster rendering. Ordinary mesh inputs retain their actual defaults.

Custom vertex displacement uses a separate deformed-pool handle for each
geometry owner, MultiMesh surface and logical instance. Both compute displacement
and hit-stage vertex replay receive the same real inputs. Shrinking the visible instance
count releases unused tail slots; RID recycling and mesh changes release old
slots. Unused entries still have the existing TTL and shutdown cleanup.
The merged compute list ends before per-instance displacement starts, avoiding
nested compute lists. This trades merged-BLAS performance for correct material
semantics on affected custom shaders; no performance improvement is claimed.

Failed closest-hit, any-hit and intersection compiles now report their actual
compiler error as well as preserving the generated source dump.

# Displacement code generation regression

The first rebuilt candidate, `21bc08eaa`, rendered all three expected instance
colors in the native Vulkan minimal regression, but failed its displaced-edge
pixel assertions. The preserved compute shader failed on `m_v_tint` being
undeclared. This is a separate pre-existing code generation defect exposed by
the stricter displacement check, not evidence that matching colors prove correct
geometry.

With `suppress_varying_io`, ShaderCompiler places varying globals and vertex
helper dependencies in its fragment-stage globals for hit-stage vertex replay.
The displacement compiler incorrectly read its vertex-stage globals instead.
For custom shaders that write `VERTEX`, a second preprocessing pass now uses
only `vertex()` as an entry point and takes that pass's fragment globals.
This retains the real varying assignments and vertex helpers without importing
helpers used only by `fragment()`, which can depend on unavailable fragment
built-ins. The vertex code itself and the actual instance data are unchanged.
At `bcc08cc81cc71e3c02b800b055f21fd11634d448`, the rebuilt native Vulkan
regression on RTX 4060 / driver 610.88 renders the three expected colors and
their displaced edges. This verifies the varying-dependency correction within
that fixture; it does not establish full game material compatibility.

# Shared-owner displacement cache

A second real Vulkan regression at the same BCC revision shares one MultiMesh
between two MultiMeshInstance3D nodes. Distinct material overrides request
opposite Y displacements. A second phase shares the same material RID and uses
each owner's `MODEL_MATRIX.x` to request opposite displacements. Both phases
observe two TLAS instances and the required configuration, but fail their pixel
assertions: the left object's expected center is empty and its red pixels appear
at the other owner's displacement. The native process exits 1 in 10.891 seconds.

The cache was keyed by MultiMesh RID, surface and logical instance alone.
The `displaced_frame` guard then let the first processed owner supply the second
owner's vertex buffer. Sharing a mesh or material does not make these results
interchangeable. Keying only by material RID would still fail the second phase.

The owner-isolation correction gives each native geometry instance a validated
owner RID. Its RID_Owner entry retains the full MultiMesh/mesh RIDs and this
owner's per-surface/per-instance deformed handles. Shrink, material changes and
mesh replacement resolve the same owner record. The PT renderer releases the
record before freeing the geometry instance, and renderer shutdown drains any
remaining records. Existing deformed-pool TTL and stale-RID checks remain.
At `a0286a13517761b058cbf53286ad0c723d414fc2`, the unchanged two-phase
shared-owner regression exits 0 in 11.469 seconds. The separate extended
six-phase owner deletion/recreation and count shrink/grow test exits 0 in
14.859 seconds. These verify the tested owner-cache behavior on the actual GPU;
they do not establish complete material compatibility or clean strict validation.

The first owner-isolation build at `858908f21c` fails MSVC C2664: phase-one
geometry traversal kept a const pointer but the owner-cache preparation takes
the renderer-owned RID token by reference. The instance array contains mutable
geometry pointers; traversal now retains that type while maintaining its cache,
without casting away const. The failed build remains retained alongside the
subsequent A028 native regression results above.

The repository reproduction is
`misc/pathtracer_test_project/shared_owner_regression/`. Its shader script SHA-256
is `99852e80503094ad2e2da136ea3a536b42e7735b048d40801bf0eeb6332d5037`.
It requires a visible native Vulkan run, captures both phases' actual pixels and
node/MM/material RIDs, and exits 1 on failed pixel, configuration, TLAS or write
checks. Async shader compilation is explicitly disabled from project startup,
isolating geometry sharing from pending hit-group placeholders.

# Lifecycle controls and remaining boundaries

The original BCC lifecycle run passed seven of nine rendered phases. Its newly
selected non-displacing custom material was grey after 180 post-draws (about
three seconds): TLAS presence alone did not prove that the new hit group was
ready. Separate controls with
`rendering/pathtracing/async_shader_compilation=false` passed this phase and
eight of nine phases overall. The attempted process-only overlay-disable control
still loaded RTSS; it did not isolate the overlay's contribution.
The original failed evidence is retained, rather than relabeled as passed.

The remaining phase uses StandardMaterial3D with
`vertex_color_use_as_albedo=true` on a merged MultiMesh. It observes the expected
single TLAS instance but white pixels instead of the three instance colors.
HG0 does not fetch/use COLOR, and the merge compute copies mesh attributes
without applying MultiMesh colors. This inherited color support gap is separate
from custom shader instance built-ins and the new owner-isolation correction.
Actual A028 awning captures now show that the same color omission also affects
ordinary Standard-material ArrayMeshes. The separately scoped correction is
tracked in [opaque Standard vertex colors](pt-opaque-standard-vertex-colors.md).

Both strict synchronous controls still report `vkQueuePresentKHR`
`PRESENT_AFTER_WRITE` hazards, including the attempted overlay-disable control
that still loaded RTSS.
Eight successful pixel phases are not a clean Vulkan validation result. RR is
off in these controls, and no RR/DLSS/FG acceptance is inferred.

# Measured A738 follow-up

At `a73826e8c0fd90351a1bae5095ce87bc6210be7f`, the unchanged public owner fixture
passes both phases (native exit 0, 11.547 seconds). The independent extended
lifetime fixture passes all six phases (exit 0, 14.860 seconds): distinct
materials, shared material with world-transform-dependent displacement, delete
one owner, recreate it, shared visible count zero and grow to one. These actual
colored-center, displaced-edge, empty-opposite-location and TLAS checks run on
RTX 4060 Laptop GPU / Vulkan 1.4.341 / Windows driver 32.0.16.1088. The owner
fixtures disable asynchronous compilation, RR, DDGI and DLSS to isolate the
cache behavior. Their baseline BCC failures and A028 partial successes remain
retained independently.

The A738 standard editor build passes in 145.687 seconds; all six Windows
editor/template targets pass in 454.266 seconds. Standard/Mono repository
smoke tests pass separately in 31.031/27.078 seconds. Four matching installed
template physics fixtures export/run through D3D12. Separately, the actual
application release EXE/PCK passes D3D12 raster-request and Vulkan PT/RR-request
production runs, each with three real 1600x900 PNGs, native exit 0 and natural
RSExit. No `--path`, external script or engine frame guard is supplied. The
packed RT include is byte-identical to its source, with matching directory MD5
and SHA-256. These bounded startup/capture/exit and packaging checks do not
establish production PT/RR state readback, active model identity or full
gameplay/material quality. Preparation-time runtime-pending evidence remains
unchanged, distinct from the later completed receipts.

Separate SDK-enabled real-game PLAY matrices pass six PT-without/with-RR,
four split-screen PT/RR and two DDGI cases on A738. Their shader inputs and
native receipts are distinct from the no-RR cache fixtures and from later
metadata-only edits. These bounded controlled-camera runs do not establish
complete gameplay, actual DLSS model identity, FG presentation or performance.
The [A738 validation summary](https://github.com/cb8010d6/sport-games/blob/migration/4.8-beta1-sl214-209897f/docs/validation/rtx-a73826e8c0.json)
retains original receipt, image and input hashes.

The separate opaque-color fixture now passes four identical pixel assertions
on the expanded generated-shader route. Its explicit TLAS expectations change
from baseline 1/1/2/2 to repaired 1/3/4/4; this does not relabel old lifecycle
phase 07, which still requires the original merged count of one and remains a
preserved failure. Alpha, emissive and advanced-material exclusions, increased
expanded-TLAS work, cold asynchronous grey placeholders and non-clean strict
Vulkan diagnostics all remain documented in the color finding.

# Regression boundary

For further changes, rebuild and rerun rendered regression: use multiple instances of one
mesh with distinct nonzero ID/custom/color inputs, a custom-alpha-dependent
vertex displacement, count shrink/grow, mesh/material replacement and exit.
Compare a normal MeshInstance default-input control. A successful compile alone
does not prove the instance shader data or deformed geometry are correct.

This correction does not implement screen-space derivatives in hit shaders.
The same game also exposed `fwidth`/`dFdx`/`dFdy` in opaque custom materials;
those require a separately validated RT material path. Vertex texture sampling
and camera-dependent deformation keep their pre-existing limitations. Do not
silently replace unsupported inputs or derivatives with zero and call it fixed.
