---
type: Finding
title: Opaque StandardMaterial vertex colors need their generated RT shader
description: HG0 drops vertex-color stripes and MultiMesh instance tints; a narrowly scoped custom-hit-group candidate preserves their shader semantics.
tags: [pathtracing, shaders, materials, vertex-color, regression]
status: draft
generated: { by: codex, at: 2026-10-26T13:03:53Z }
---

# Observed failure

At `a0286a13517761b058cbf53286ad0c723d414fc2`, actual Vulkan PT/RR game
captures retain white shop awnings where raster/DDGI captures show colored and
off-white stripes. Source inspection confirms an ordinary ArrayMesh: each strip
receives a vertex color, and its opaque StandardMaterial3D enables
`vertex_color_use_as_albedo`. No albedo texture is responsible for the stripes.
This is a remaining material-color failure, rather than a successful complete
visual acceptance merely because building and terrain shaders now render.

A separate native run with the frozen `a0286a1351` editor also fails all four
color-fixture phases (exit 1, 19.422 seconds). Configuration and TLAS checks
match the old merged route, but green strips, RGB instance tints and both
constant-color/reference comparisons fail their actual pixel assertions. No
shader or script error occurs, and Job cleanup leaves no NGX updater.

The separate earlier lifecycle phase 07 already reproduces the underlying
StandardMaterial3D color gap without RR: three instance colors render white while
the merged MultiMesh correctly reports one TLAS instance. That original failed
input, route expectation and result are retained.

# Cause and narrow candidate

`process_material()` treats an `albedo` parameter of Color type as the HG0
Standard-material path. HG0 does not fetch/use COLOR, and merged MultiMesh
attribute replication does not apply per-instance colors.

The candidate records actual COLOR usage using ShaderCompiler usage pointers,
including the RTClassification pass. Ordinary opaque, non-emissive color
materials use their complete generated shader through the existing custom hit
group. This retains material/texture multiplication, source-color uniforms and
the optional vertex sRGB conversion. Shared RT custom globals declare
`SHADER_IS_SRGB=false`, matching their actual linear material-evaluation contract.

Materials that use alpha, clipping or the alpha pass retain their old path.
Emission-feature and refraction materials are also excluded: routing an existing
Standard emitter custom would remove its `!is_custom_shader` mesh-light sampling
and change NEE. Matrix/position overrides, particle trails, point size and
height-map/parallax materials are excluded as well. Their existing limitations
are not fixed or advertised as supported by this candidate.

COLOR-dependent MultiMeshes use the existing expanded path. The new route
therefore expects three TLAS entries for three logical instances, rather than
one merged entry. This can increase TLAS/geometry-data work; no performance
improvement or cost bound is claimed. The merged attribute format is unchanged.

# Reproduction and current verification boundary

The independent repository project is
`misc/pathtracer_test_project/opaque_color_regression/`. It records actual
pixels, image files, TLAS counts, configuration and engine/GPU/fixture identity
in four phases: ordinary green/white ArrayMesh strips, MultiMesh RGB, constant
linear input and constant sRGB input. The constant cases compare against an
independent HG0 material with vertex colors disabled, within 0.045 per channel.
They do not merely accept any grey result.

The script SHA-256 is
`32c50befae8d888884607f3e52064192f74e7004b4be26f9b63863fc359cd28d`.
Run the baseline with `--mm-path=merged` and the candidate with
`--mm-path=expanded`. All pixel assertions are identical; only the explicit
route/TLAS expectation changes. The old phase 07 is not rewritten to pass.

The project uses synchronous shader compilation, a visible 640x360 Vulkan PT
window, 4 spp and 2 bounces, with RR/DDGI/DLSS off. It preserves native errors and
exits 1 on failed checks. The baseline has been GPU-tested as described above;
the guarded code candidate has not yet been rebuilt or GPU-tested. Required follow-up is the baseline/candidate
fixture pair, the same actual awning views, related owner/built-in regressions
and separate strict diagnostics. Existing presentation/Streamline validation
failures are not resolved by color restoration.
