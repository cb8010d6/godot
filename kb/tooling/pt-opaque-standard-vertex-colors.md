---
type: Finding
title: Opaque StandardMaterial vertex colors need their generated RT shader
description: Vulkan red/green regressions verify a narrow generated-hit-group correction for opaque vertex colors while preserving existing alpha and emissive paths.
tags: [pathtracing, shaders, materials, vertex-color, regression]
status: stable
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

# Cause and narrow correction

`process_material()` treats an `albedo` parameter of Color type as the HG0
Standard-material path. HG0 does not fetch/use COLOR, and merged MultiMesh
attribute replication does not apply per-instance colors.

The A738 correction records actual COLOR usage using ShaderCompiler usage pointers,
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
are not fixed or advertised as supported by this correction.

COLOR-dependent MultiMeshes use the existing expanded path. The new route
therefore expects three TLAS entries for three logical instances, rather than
one merged entry. This can increase TLAS/geometry-data work; no performance
improvement or cost bound is claimed. The merged attribute format is unchanged.

# Reproduction and measured A738 verification

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
exits 1 on failed checks. On RTX 4060 Laptop GPU, Vulkan 1.4.341 and Windows
driver 32.0.16.1088, native commit
`a73826e8c0fd90351a1bae5095ce87bc6210be7f` passes all four phases, exits 0 and
takes 27.000 seconds. The standard MSVC editor build passes in 145.687 seconds;
the subsequent standard/Mono six-target Windows build passes in 454.266 seconds.

The baseline and repaired fixture use identical pixel assertions and the same
script hash above. Their explicit route expectations differ: baseline TLAS
counts are 1/1/2/2; the repaired generated-shader route observes the expected
1/3/4/4. This is the new expanded-route red/green regression, not a rewritten
pass for the old lifecycle phase 07, whose expected merged count remains one
and whose original white-pixel failure is retained. A028's four failures and
earlier partial owner-cache successes also remain separate records.

A738 is independently rechecked with the two-phase shared-owner fixture and
the six-phase owner lifetime extension, both passing actual pixel/TLAS checks.
SDK-enabled real-game PLAY captures also pass six PT-without/with-RR cases,
four split-screen PT/RR cases and two separate DDGI cases, including the
previously white awnings. These use bounded controlled first-player camera
sweeps at 1600x900 with normal asynchronous shader compilation, not a complete
gameplay, image-quality or performance acceptance.

Standard/Mono repository smoke tests separately pass in 31.031/27.078 seconds.
Four matching installed-template physics fixtures (standard/Mono x
debug/release) export and run through D3D12, without Streamline DLLs in their
game directories. They remain separate from the actual application-game export.
That release EXE/PCK now passes two bounded production-entry runs: D3D12 with
a raster request and Vulkan with a PT/RR request, each saving three real
1600x900 PNGs before natural RSExit, with native exit 0 and no errors. Commands
supply no `--path`, external `--script` or `--quit-after`; owned descendants are
closed after each run. PCK inspection verifies that the 1654-byte RT include
payload matches its source bytes, directory MD5 and frozen-input SHA-256.
These are startup/capture/natural-exit and packaging checks, not full gameplay,
production PT/RR state readback, independent AI model or comprehensive image
quality acceptance. The original preparation-time runtime-pending record is
retained alongside the completed later receipts.
Mono removes SDK discovery only from the runtime process; the host still has
an SDK installed, so this is not a clean-computer redistribution result.

The [public A738 game validation summary](https://github.com/cb8010d6/sport-games/blob/migration/4.8-beta1-sl214-209897f/docs/validation/rtx-a73826e8c0.json)
records original receipt, input and image hashes. Its recorded SHA-256 is
`033d3164b30552d60c72437cbb62414b7e35a90300d44963f7906f82a25b27b7`.
The game shader inputs are frozen separately from subsequent pin/doc-only
changes; no whole-game byte identity is claimed after those metadata updates.
The actual game test HEAD remains `979778df7b2d89b9ebce7abc8737bd3389c4bb6e`
with frozen dirty inputs. Later code-only commit
`ab46ff811e7b9c2f9f8fa46144f0be5f4dd2de76` contains the same four shader files,
verified by matching each committed-file hash; it is not a GPU rerun at that
later commit.

Cold asynchronous compilation can still display pending grey hit groups.
Existing `PRESENT_AFTER_WRITE` and Streamline Vulkan 09600/03868/FG diagnostics
remain independent strict-validation failures. Active DLSS model identity,
presented generated frames, latency and long-running stability are not
established by these material results; this remains an experimental build.
