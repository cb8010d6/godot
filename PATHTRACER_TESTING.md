# Path tracer test and fix plan

The 2026-10-25 real Vulkan validation also found inherited RGBA32F/RGBA16F
RT-output and RGBA16F/RGBA8_SNORM RR-guide mismatches. The declarations and
allocations are corrected on a separate regression branch; validation is pending.
See [format finding](kb/tooling/pt-storage-image-formats.md).

Windows acceptance (2026-10-25): a glass-view exit at `b0d582c9f9` logged a
stale RID when abandoning an asynchronous build. The inherited cleanup freed
hit-group shaders before their dependent pipeline. An independent local fix
reverses that order; rebuild and repeated-exit verification are pending.
See [ownership finding](kb/tooling/pt-abandoned-pipeline-cleanup.md).

Working notes for making the NVIDIA path tracer (`RenderForwardClusteredPT`)
handle PBR materials, lights, emission, custom shaders and fog natively. This
file is the shared memory for humans and agents working on it: read it before
starting, and update the step table and the findings log as you go.

Work happens on the `dev-pt` branch. A finished step (build, smoke tests,
screenshots) is merged into `dev`; see [CUSTOM_BUILD.md](CUSTOM_BUILD.md).

## How to run the test scene

The test project is [`misc/pathtracer_test_project/`](misc/pathtracer_test_project/).
It builds every test area from code (`main.gd`), so there is no scene file to
keep in sync. The path tracer needs Forward+ and the Vulkan driver; the
project sets both.

Interactive:

```
bin\godot.windows.editor.x86_64.exe --path misc\pathtracer_test_project
```

Keys: `1`-`7` switch views, `P` toggles path tracing, `D` cycles the debug
mode, `R` toggles DLSS Ray Reconstruction, `F` toggles volumetric fog.

Screenshots (for comparing path traced against raster, or before against
after a fix):

```
bin\godot.windows.editor.x86_64.console.exe --path misc\pathtracer_test_project -- --view=pbr --pt=1 --shot=C:\tmp\pbr_pt.png
bin\godot.windows.editor.x86_64.console.exe --path misc\pathtracer_test_project -- --view=pbr --pt=0 --shot=C:\tmp\pbr_raster.png
```

All user arguments (after `--`):

| Argument | Default | Meaning |
| --- | --- | --- |
| `--view=` | `overview` | `overview`, `pbr`, `lighting`, `emissive`, `shaders`, `glass`, `fog` |
| `--pt=` | `1` | `1` path traced, `0` raster |
| `--spp=` | `4` | Path tracer samples per pixel (1-16) |
| `--bounces=` | `3` | Path tracer max bounces (1-8) |
| `--debug=` | `0` | `Environment.pathtracing_debug_mode` (see the enum in `scene/resources/environment.h`) |
| `--denoiser=` | `0` | `0` none, `1` DLSS Ray Reconstruction (needs the Streamline DLLs) |
| `--volfog=` | view default | `1` forces volumetric fog on, `0` off |
| `--frames=` | `90` | Frames to render before the screenshot. Use 300-400 after changing RT shader code: custom hit groups recompile asynchronously and are skipped until ready |
| `--sun_only` | off | Remove every light except the sun (isolates light selection) |
| `--panel_only` | off | Only the emissive room's ceiling panel emits |
| `--linear` | off | Linear tonemap with `--exposure=` (default 0.25), for brightness measurements |
| `--shot=` | none | Save a PNG and quit |

### Shared MultiMesh displacement regression

The isolated project
[`misc/pathtracer_test_project/shared_owner_regression/`](misc/pathtracer_test_project/shared_owner_regression/)
tests two geometry owners sharing one MultiMesh. Run a tools/editor binary as
a game in a visible Vulkan window, with a new writable evidence directory:

```powershell
& $Engine --rendering-driver vulkan --rendering-method forward_plus `
  --path misc/pathtracer_test_project/shared_owner_regression `
  --script res://shared_owner.gd -- --output=$EvidenceDirectory
```

Use an external 180-second process-tree timeout and preserve the full native
log and exit code. The project disables async shader compilation at startup;
RR, DDGI and DLSS are off. It captures real PNG/JSON after 300 post-draws with
distinct material overrides, then 120 post-draws with the same material and
owner-dependent `MODEL_MATRIX` displacement. Both phases require actual colored
centers/displaced edges, empty opposite-displacement locations and two TLAS
instances. Any failed assertion or evidence write exits 1. The tested script
SHA-256 is `99852e80503094ad2e2da136ea3a536b42e7735b048d40801bf0eeb6332d5037`.
After a repair, also test geometry owner deletion/recreation and instance-count
shrink/grow; compile success alone does not verify cache lifetime.
At A738 the unchanged public two-phase test and separate six-phase lifetime
extension both pass actual pixel/TLAS checks; the earlier BCC failures remain.

### Opaque StandardMaterial vertex-color regression

The independent
[`opaque_color_regression`](misc/pathtracer_test_project/opaque_color_regression/)
project checks ordinary ArrayMesh stripes and MultiMesh tint/sRGB behavior:

```powershell
& $Engine --rendering-driver vulkan --rendering-method forward_plus `
  --path misc/pathtracer_test_project/opaque_color_regression `
  --script res://standard_color.gd -- --mm-path=expanded --output=$EvidenceDirectory
```

Use `--mm-path=merged` for the baseline. The pixel assertions stay identical;
the candidate explicitly expects expanded TLAS entries (3 rather than 1 for
the RGB MultiMesh). The constant-color phases add an independent non-vertex-color
reference and check both linear/sRGB input semantics. Use a new output directory
and an external 170-second process-tree timeout. The project fixes synchronous
compilation, 640x360, 4 spp, 2 bounces and no RR/DDGI/DLSS. Preserve full native
logs, actual exit codes, screenshots and JSON; failed checks exit 1.
Its SHA-256 is `32c50befae8d888884607f3e52064192f74e7004b4be26f9b63863fc359cd28d`.
At A028 the baseline exits 1 with zero of four pixel phases passing. At A738
the same four pixel assertions pass and the process exits 0 in 27.000 seconds.
Explicit TLAS counts are baseline 1/1/2/2 and repaired route 1/3/4/4. The original
nine-phase lifecycle and phase 07 merged-color failure remain unchanged; no
old one-entry merged test is relabeled as a pass for the new expanded route.

### A738 measured acceptance snapshot

Native source commit `a73826e8c0fd90351a1bae5095ce87bc6210be7f` is tested on
RTX 4060 Laptop GPU / Windows driver 32.0.16.1088 / Vulkan 1.4.341.
The color and owner fixtures above use 640x360, synchronous compilation and
RR/DDGI/DLSS off. The independent SDK-enabled game matrices use normal
asynchronous compilation, bounded first-player camera sweeps during real PLAY
and 1600x900 captures, rather than full gameplay or performance measurement.

| Check | Measured result and boundary |
| --- | --- |
| Standard MSVC editor; six Windows standard/Mono editor/template targets | PASS, exit 0: 145.687 seconds / 454.266 seconds |
| Opaque-color native red/green | A028 FAIL 0/4; A738 PASS 4/4, identical pixel assertions with explicit merged/expanded TLAS expectations above |
| Shared-owner native / extended lifetime | A738 PASS 2/2 and 6/6, exit 0 in 11.547 / 14.860 seconds; BCC red and A028 partial records retained |
| Actual game PT without/with RR | PASS 6/6, including no-RR controls; PT0 uses a snapshot-only Environment override because the normal UI gates that combination |
| Actual split-screen PT/RR | PASS 4/4, two/four players; short controlled-camera runs |
| Actual DDGI | PASS 2/2, independent runs rather than relabeled PT results |
| Standard / Mono repository smoke | PASS, exit 0 in 31.031 / 27.078 seconds |
| Four installed-template physics fixtures | PASS: standard/Mono x debug/release exports and actual D3D12 startup; no Streamline DLLs in game directories |
| Application-game export / packed RT include / runtime | PASS 2/2: actual EXE/PCK D3D12 raster request and Vulkan PT/RR request, three 1600x900 PNGs each, natural RSExit/exit 0; packed include payload/source/MD5/SHA match; bounded startup checks only |
| Strict Vulkan validation | NOT CLEAN: original lifecycle presentation and Streamline diagnostics remain separate failures |

The Mono export tests remove SDK discovery from the runtime process only; the
host still has an SDK installed, so no clean-computer claim is made. Actual
DLSS model identity, FG presentation, latency, long-session stability and HDR
are outside these material checks. Metadata-only engine-pin/document updates
follow the frozen game GPU input snapshots and do not imply whole-tree byte
identity afterward. The [A738 validation summary](https://github.com/cb8010d6/sport-games/blob/migration/4.8-beta1-sl214-209897f/docs/validation/rtx-a73826e8c0.json)
records original receipts, images and input hashes; it is not a publication of
SDK binaries or private raw evidence. This remains an experimental build.
The application production runs supply no `--path`, external script or
`--quit-after` and leave no new owned NGX updater after Job cleanup; they do
not add PT/RR effective-state readback or establish full gameplay acceptance.
The original export-preparation runtime-pending marker is retained unchanged;
later natural-exit receipts record completion separately.

## What the path tracer supports today

Audited on 2026-10-08 at commit `ca52415e30`. Shader sources are in
`servers/rendering/renderer_rd/shaders/raytracing/`, the host code in
`servers/rendering/renderer_rd/forward_clustered/render_raytracing.cpp` and
`scene_shader_raytracing.cpp`.

| Feature | Status | Where |
| --- | --- | --- |
| StandardMaterial3D albedo, roughness, metallic, specular, ORM texture | Supported | `scene_raytracing_raygen.glsl`, closest hit HG0 |
| StandardMaterial3D vertex colors | A738 ordinary opaque/non-emissive generated-HG route passes native 4/4 and short game captures; alpha/emissive/advanced exclusions and expanded-TLAS cost remain | `opaque_color_regression`, [finding](kb/tooling/pt-opaque-standard-vertex-colors.md) |
| Normal maps | Supported | `apply_normal_map()` |
| Emission (color, energy, texture) | Supported. StandardMaterial3D emitters are also sampled as mesh lights (NEE) on rough surfaces. Custom shader emission is counted on hit only | `lights_sample_emissive_mesh()` |
| Omni, spot, directional lights | Supported, with soft shadows from light size | `raytracing_lights_inc.glsl` |
| Area lights | Not available (Godot has none); emissive meshes are the substitute | |
| Sky | Supported through the radiance octmap | miss shader |
| Depth and height fog | Supported per ray segment | `apply_segment_fog()` |
| Volumetric fog, FogVolume | Supported on primary rays (Godot's froxel fog) | `sample_primary_volumetric_fog()` |
| Custom ShaderMaterial `fragment()` | Supported through custom hit groups | `scene_shader_raytracing.cpp`, `raytracing_custom_fragment_inc.glsl` |
| Custom `vertex()` displacement | Supported when `vertex()` writes `VERTEX` and samples no textures (compute pass, then deformed BLAS) | `raytracing_vertex_displace.glsl`, `process_displaced_surface()` |
| Alpha scissor | Supported (StandardMaterial uses a fixed 0.5 threshold) | any hit |
| Alpha blend (StandardMaterial3D) | Supported: stochastic opacity in any hit; shadows let (1 - alpha) through | `material_alpha_blend_hit()` |
| Refraction (StandardMaterial3D) | Supported: dielectric with Fresnel, IOR = 1 + 10 x `refraction_scale` (0.05 gives 1.5), albedo tints, roughness scatters. Casts opaque shadows (as raster) | `refract_and_bounce()` |
| Custom shader alpha blend, add/sub/mul blending, billboards, proximity fade | Raster overlay on top of the path traced image | `ShaderData::rt_traces_transparency()` |
| Debug views | 22 modes in `Environment.pathtracing_debug_mode` | `debug_visualize()` |

## Steps

Do one step at a time. Each step ends with screenshots compared against raster,
a build, the smoke tests from CUSTOM_BUILD.md, and an update to this file.

| # | Step | Status |
| --- | --- | --- |
| 1 | Audit what the path tracer supports (table above) | Done |
| 2 | Build the test project with all test areas and a screenshot harness | Done |
| 3 | Baseline: screenshots of every view, path traced and raster; list every visible difference in the findings log | Done |
| 4 | Quick bugs: StandardMaterial emission without a texture (B1), StandardMaterial alpha scissor threshold (B2) | Done |
| 5 | Black pixels in directly lit areas (B3): find the cause, fix it | Done |
| 6 | Emission as a light: light sampling toward emissive meshes so emitters light the scene without heavy noise | Done |
| 7 | Custom `vertex()` displacement in the path tracer (B4) | Done |
| 8 | Volumetric fog in the path tracer (B5): Environment volumetric fog first, then FogVolume, then light shafts | Done |
| 9 | Glass (B6): path traced alpha blend, refraction and transmission instead of the raster overlay | Done |
| 10 | Clean up, document, merge `dev` into `nvidia-pt-dlss` | Done (release 0.3.0) |
| Sync | Godot 4.8 beta 1 and Streamline 2.14.16 integration | Windows RTX Vulkan PT/RR scenes rendered on a separate regression build; strict validation still fails; see `devtools/WINDOWS_ACCEPTANCE_2026_10_25.md` |
| Regression | Shared MultiMesh vertex displacement | A738 real GPU owner 2/2 and extended lifetime 6/6 pass; A028 partial successes, BCC red and first MSVC failure remain retained |
| Regression | Opaque StandardMaterial vertex colors | A738 native 4/4 and independent actual game 6+4+2 pass within the scoped route; A028/merged-07 failures and strict-validation failures retained |
| Startup | Per-viewport live RT readiness | d29 public release PCK, six targets, standard/Mono smoke, installed templates and production game entry pass; bounded game fault/split checks pass at 8a. RR automatic/F strict failure remains separate; see `devtools/RT_WARMUP_ACCEPTANCE_2026_10_27.md` |

## Known bugs

2026-10-26 real-game follow-up: C1 closest-hit shader replays fail for
`INSTANCE_CUSTOM` / `INSTANCE_ID`, and for screen-space derivative functions.
The instance-data candidate and colored/deformed MultiMesh regression are
tracked in [instance built-ins](kb/tooling/pt-instance-builtins.md). BCC restores
real instance colors and displacement in the minimal Vulkan fixture, but a
separate shared-owner test reproduces aliased deformation buffers. A028 passes
the two-phase owner test and extended six-phase lifetime regression after its
owner-isolation correction.
A738 independently passes the same public two-phase owner regression and the
six-phase lifetime extension; these are cache/pixel checks rather than a clean
strict-validation result.
Derivative-dependent application materials
need a separate RT path; successful short opening captures did not establish
full material compatibility during gameplay. The retained C1 results are not
rewritten as comprehensive PT acceptance.

Separate BCC synchronous-compilation lifecycle controls pass eight of nine
pixel phases. The remaining StandardMaterial3D merged MultiMesh phase renders
white instead of instance colors despite `vertex_color_use_as_albedo=true`;
this inherited gap is outside the custom-shader owner-cache correction.
Actual A028 PT/RR captures also show white awnings where raster/DDGI preserve
the ordinary mesh's vertex-color stripes. The [measured narrow color correction](kb/tooling/pt-opaque-standard-vertex-colors.md)
routes ordinary opaque, non-emissive materials through their generated shader.
Transparent/clipped, emissive, matrix/position overrides, particle/point-size and
parallax materials retain existing paths and limitations. Expanded COLOR
MultiMeshes can cost more TLAS/geometry-data work; no performance claim is made.
At A738 the independent four-phase fixture passes its unchanged pixel checks
with explicit expanded-route expectations; short game captures also restore
the awning stripes. The old merged phase 07 remains a preserved failure.
Strict controls still log `PRESENT_AFTER_WRITE` at swapchain presentation. The
attempted process-only overlay-disable control still loaded the RTSS layer,
so it does not isolate the overlay's contribution. Pixel checks and native exit codes must remain
separate from clean Vulkan validation. These no-RR lifecycle controls do not
establish RR/FG acceptance; the separate short game RR matrix above does not
broaden them into clean strict validation or FG presentation evidence.

Found in the step 3 baseline (2026-10-08, commit `a6a531899a`, 4 spp, 3
bounces, no denoiser). Screenshots were taken with `--shot` for every view in
both modes.

| ID | View | Bug | Cause / lead |
| --- | --- | --- | --- |
| Startup | custom materials | A028/A738 cold asynchronous runs can display grey fallback material before the live hit group is published. Native editor and private packed-release readiness fixtures pass; complete game fault/split/strict coverage remains separate. | Preload/global pipeline counters/zero pending alone do not prove a rendered viewport is ready; require actual variant live-ready, nonempty TLAS and fresh recorded RT frames. |
| B1 | emissive | **Fixed in step 4.** StandardMaterial3D emission rendered **black**. Debug mode 21 (Emissive) is 0 on every emitter. Emission from a custom ShaderMaterial works (shaders view, orange stripes). | `scene_raytracing_raygen.glsl` closest hit HG0 only adds emission when `mat.flags & 2` (`RT_MAT_FLAG_HAS_EMISSION_TEX`) is set, which `render_raytracing.cpp` sets only when an emission texture exists. Color and energy alone are ignored. |
| B2 | glass, pbr | **Fixed in step 4.** Alpha scissor sphere with threshold 0.3 and alpha 0.4 is **missing** (no surface, no shadow). | Any-hit HG0 uses a hard-coded `alpha < 0.5`; the material's `alpha_scissor_threshold` isn't passed. |
| B3 | lighting, all | **Fixed in step 5.** Pure black pixels scattered over surfaces that the sun or a lamp lights directly. With light sampling, direct light on a flat diffuse floor should be nearly noise-free. | Unknown. Some paths return zero radiance. Debug mode 22 (BRDF rejection) shows rejection noise on every surface. Check NEE shadow rays, `offset_ray_origin`, and BRDF sample rejection. |
| B4 | shaders | **Fixed in step 7** (no textures in `vertex()` yet). `vertex()` displacement was ignored: the wave renders flat and casts a flat shadow. | The BLAS is built from the original mesh. Needs the vertex shader applied before the BLAS build (a compute pass or the raster pipeline's transform feedback). |
| B5 | fog | **Fixed in step 8.** Volumetric fog, FogVolume and the spot light shaft were **not rendered at all**. Only distance/height fog worked. | The path tracer did not update or sample Godot's integrated volumetric fog froxel map. |
| B6 | glass | **Fixed in step 9** (StandardMaterial3D only). Alpha blend and refraction materials were drawn by the raster transparent pass on top of the path traced image. No shadows or reflections, and refraction smears the noisy screen texture into horizontal streaks. | Transparent geometry is skipped by the path tracer (`transmissivness = 0.0`). |

Works as expected (path traced is equal to or better than raster): the PBR
sphere grid (reflections of the real scene instead of a darker sky probe),
normal and albedo textures, the Cornell box (mirror sphere, color bleeding, soft
shadows from omni and spot), custom shader albedo, roughness, emission, `TIME`,
`NORMAL_MAP` and `ALPHA_SCISSOR_THRESHOLD`.

Other notes:
- Noise at 4 spp without a denoiser is expected; use `--denoiser=1` with the
  Streamline DLLs for the final look.
- Glass needs more bounces than opaque scenes: each interface uses one. At
  the default 3, some paths inside a glass sphere end black.

## Findings log

Newest first. Note the date, the commit, the view and what you saw or changed.

- 2026-10-27: Final d29 six Windows targets, standard/Mono smoke, four installed
  template fixtures and exact public readiness release PCK pass. Actual game
  production Vulkan/D3D12 entries capture three frames each and exit naturally.
  Separate 8b SDK214 RR-D/FG-omitted single/four-player strict controls are CLEAN;
  automatic/F still has WAW/layout errors. No default preset change or neural
  weight readback follows. Exact identities/scope are recorded in
  `devtools/RT_WARMUP_ACCEPTANCE_2026_10_27.md`.

- 2026-10-27: Added release-capable per-viewport shader pending/failed, recorded
  RT dispatch and serial statistics (old enum values 0..7 unchanged). Invalid RT
  source and preprocessing failures retain explicit failed slots instead of
  first-call HG0 fallback. Startup readiness uses the actual live variant, not
  all global worker tasks. The new two-view/source-reload fixture and separate
  game loading cover are prepared; no native build or GPU test has run for this
  change. Prior A738 success and cold-grey/strict failures remain unchanged.

- 2026-10-27: Native A738 editor and six Windows targets build successfully
  (145.687 / 454.266 seconds). Native opaque-color 4/4, shared-owner 2/2 and
  extended lifetime 6/6 pass. Independent real-game PT-without/with-RR 6/6,
  split-screen PT/RR 4/4 and DDGI 2/2 pass bounded 1600x900 PLAY captures.
  Standard/Mono smoke pass in 31.031/27.078 seconds; four matching installed
  template physics fixtures export/run through D3D12. A separate actual
  application EXE/PCK passes two production-entry startup/capture/natural-exit
  runs, with D3D12 raster and Vulkan PT/RR requests; each has three original PNGs
  and native exit 0. The packed RT include payload matches source/MD5/SHA.
  Preparation-time pending evidence remains retained; no full-game, production
  PT/RR state-readback or independent model claim follows from these runs.
  Original A028 color red, BCC owner red and merged phase 07 failures remain;
  cold async grey placeholders, alpha/emissive/advanced exclusions and strict
  Vulkan diagnostics are not erased. See the scoped matrix above and
  [color finding](kb/tooling/pt-opaque-standard-vertex-colors.md).

- 2026-10-27: A028 manual PT/RR awning captures fail vertex-color compatibility;
  code inspection confirms an opaque Standard material on colored ArrayMesh
  strips. The ordinary opaque/non-emissive generated-shader candidate preserves
  transparency and NEE paths, excludes advanced geometry/parallax modes, and
  adds a separate linear/sRGB vertex-color regression. At this earlier
  checkpoint rebuild/GPU checks were pending; A738 follow-up is recorded above.
  A028 owner isolation separately passes its two-phase and extended
  six-phase native tests; see [color finding](kb/tooling/pt-opaque-standard-vertex-colors.md).

- 2026-10-26: At `bcc08cc81cc71e3c02b800b055f21fd11634d448`, a visible
  Vulkan run on RTX 4060 / driver 610.88 reproduces both shared-owner displacement
  failures (native exit 1, 10.891 seconds). Expected left-owner centers are empty;
  red pixels occupy the other owner's displacement. New validated owner-RID
  cache isolation includes node and renderer cleanup; candidate rebuild and GPU
  regression are pending. Separate synchronous lifecycle controls pass 8/9 pixel
  phases but retain the Standard merged-color gap and strict presentation
  synchronization errors. See [instance findings](kb/tooling/pt-instance-builtins.md).

- 2026-10-24: Pinned 4.8 beta 1 sync preserves the PT renderer, fog and
  lifetime fixes. Upstream compressed shader generation retains all five
  ray-tracing stages; `devtools/test/test_raytracing_builders.py` checks
  decompression, sizes and stage order. This is a CPU generator check, not
  a GLSL compiler or rendered image test. Streamline's real Windows loader,
  Vulkan and D3D12 adapter branches also cross-compile with the 2.14.16
  headers. The native Windows/RTX scene matrix, RR/FG and missing-DLL
  runtime checks were pending at that cloud stage; subsequent native results
  and separate-regression boundaries are in
  `devtools/WINDOWS_ACCEPTANCE_2026_10_25.md`.

- 2026-10-08: After syncing upstream `65e8d16951`, the fog path tracer smoke
  initially exited with `Attempted to free invalid ID` after saving the
  screenshot. Cause: several BLAS cleanup paths still freed stale acceleration
  structure RIDs directly; those BLAS objects may already be gone when their
  backing buffers are freed. Guarded the remaining BLAS frees with
  `RenderingDevice::acceleration_structure_is_valid()` in static, deformed,
  procedural and merged MultiMesh paths. Verified two fog PT screenshot runs
  exit with no `ERROR:`.

- 2026-10-08: Step 9 done. Alpha blended and refractive StandardMaterial3D
  surfaces are path traced instead of drawn by the raster overlay.
  `ShaderData::rt_traces_transparency()` picks them (BaseMaterial3D code,
  mix blending, depth test on, no billboard, proximity fade or stencil) and
  gives them opaque `rt_pass_flags`, so they enter the TLAS. Material flags:
  bit 3 alpha blend, bit 4 refraction, bits 24-31 the IOR. Alpha blend: the
  HG0 any hit (and `ray_query_alpha_test()`) keeps the hit with probability
  alpha, from a hash of the ray's random state and the triangle, so repeated
  any-hit calls agree and a pass-through costs no bounce. Shadow rays get the
  same test, seeded per light sample. Refraction: the closest hit shades the
  alpha part as usual and sends the rest to `refract_and_bounce()` (exact
  dielectric Fresnel, GGX microfacet for rough glass, albedo tint, total
  internal reflection). Refractive instances disable face culling, so rays
  leave through back faces. Verified: glass view shows the alpha sphere with a
  partial shadow and the refraction sphere with an inverted, bent view of the
  pillars. At 3 bounces some paths inside the glass end black; 6 bounces
  clean that up. All views render with no `ERROR:` or `WARNING:`.

- 2026-10-08: Fixed the dark specks on the emissive room's roof (step 7
  follow-up). Cause: `lights_mesh_selection_weight()` bounded each emitter
  with a sphere. The wide ceiling panel's sphere pokes through the roof
  plane, so roof points picked the panel and got a blocked shadow ray. Now
  `RT_EmissiveMeshData` also carries the world AABB half extents (96 bytes),
  and the weight is 0 when every box corner is behind the shading plane.
  That test is exact, so no bias. Verified: overview roof is clean, emissive
  view unchanged. All seven views render with no `ERROR:` or `WARNING:` in
  both modes.
- 2026-10-08: Follow-up for step 8: fixed volumetric fog `Sky Affect` in the
  path tracer. Cause: raster applies `Environment.volumetric_fog_sky_affect`
  in `sky.glsl`, but the PT miss shader composited the froxel fog over sky at
  full strength. RT params now carry `volumetric_fog_sky_affect` and the global
  fog legacy-blending flag; miss shader uses the same sky-compose formulas as
  raster. Test harness accepts `--vfog_sky_affect=`. Verified PT screenshots at
  `--vfog_sky_affect=0` and `1` (`fog_pt_sky_affect_0.png`,
  `fog_pt_sky_affect_1.png`) and raster counterparts show matching direction:
  sky unaffected at 0, fully affected at 1. Build passed.
- 2026-10-08: Follow-up for step 8: fixed the `4 RIDs of type "Shader" were
  leaked` warning on PT exit. Cause: async RT pipeline build tasks can finish
  during shutdown before `drain_completed_compiles()` installs them; the shutdown
  path freed the task's new pipeline but not task-owned per-hit-group shader
  RIDs. Added `_free_task_owned_outputs()` and use it for abandoned current /
  queued tasks. Verified `--view=fog --pt=1 --frames=180` exits with no shader
  RID leak warning.
- 2026-10-08: Step 8 done. Path traced fog view now renders volumetric fog,
  FogVolume and the spot light shaft. Forward+ path tracing now performs the
  normal voxel GI setup before volumetric fog so `rbgi->voxel_gi_textures[]`
  contains default textures even when the scene has no VoxelGI; without this,
  the volumetric fog process uniform set failed at binding 13. It updates
  `RB_SCOPE_FOG` before TLAS/uniform setup, sets `RT_FLAG_FOG_ENABLED` when a
  volumetric fog map exists, binds `VolumetricFog::fog_map` at RT binding 29,
  and passes inverse fog length/detail-spread plus a has-volumetric-fog flag in
  RT params 4-6. The RT shader samples the integrated froxel map on primary
  hits/misses and composites it as raster does (`rgb` in-scatter, `a`
  transmittance). Secondary rays keep the existing per-segment distance/height
  fog instead of sampling the camera-space froxel map. Verified with
  `--view=fog --pt=1 --frames=180` against raster (`fog_pt_b5_final.png`,
  `fog_raster_b5_fix.png`). Build passed. Smoke passed: PhysX GPU normal
  and editor runs printed `PhysX 5.10.0 initialized [GPU]` with no `ERROR:`;
  path traced fog screenshot exited cleanly with no `ERROR:`.
- 2026-10-08: Step 7 done. Custom `vertex()` displacement now shows in the
  path tracer. `_preprocess_shader()` marks shaders that write `VERTEX`
  (`write_flag_pointers`). `raytracing_vertex_displace.glsl` is a ShaderRD
  compute template whose expanded source gets the material's vertex code,
  uniform members and vertex-stage globals at runtime
  (`SceneShaderRaytracing::get_vertex_displace_pipeline()`, one program per hit
  group slot). `process_displaced_surface()` (TLAS loop, before
  `process_surface()`) fills the static `GeometryData`, dispatches the compute
  once per frame into a per-surface uncompressed vertex buffer, then hands it
  to `process_deformed_surface()` (BLAS refit, motion vectors). The geometry
  gets `FLAG_VERTEX_DISPLACED`, and the hit template restores
  `vertex`/`normal`/`tangent`/`binormal` after re-running `vertex()` so the
  hit isn't displaced twice. Limits: `vertex()` that samples a texture fails
  to compile in the pass (warning, traced undisplaced); 2D meshes skipped.
  Also fixed: exit errors `Attempted to free invalid ID` (a BLAS is freed with
  the mesh buffers it was built from; added
  `RenderingDevice::acceleration_structure_is_valid()` and use it in the
  cache cleanup) and the old `4 RIDs of type "Shader" were leaked` warning no
  longer shows. Verified: wave and its shadow match raster.
  Follow-up (fixed later): the emissive room's roof showed dark specks,
  because light selection didn't know the emitters inside are hidden from
  the roof.
- 2026-10-08: Step 6 done. Emissive StandardMaterial3D surfaces are mesh
  lights now. Host (`render_raytracing.cpp`, TLAS loop): each emissive HG0
  surface becomes an `RT_EmissiveMeshData` (transform incl. compression AABB,
  bounds, geometry index, triangle count, power), uploaded at binding 33, count
  in `RT_PARAM_EMISSIVE_MESH_COUNT` (13), up to 256; its geometry gets
  `FLAG_EMISSIVE_LIGHT`. Shader: mesh lights join the RIS candidates
  (`lights_mesh_selection_weight()`), sampling picks a uniform triangle and a
  uniform point (`lights_sample_emissive_mesh()`), emission read from the
  material incl. texture. Double counting is avoided without MIS: at a vertex
  with roughness >= 0.3 NEE samples mesh lights and sets payload bit 27
  (`EMISSIVE_SAMPLED_FLAG`); the next hit then skips emission from flagged
  geometry. Glossy vertices leave emitters to the BRDF ray (sharp reflections).
  Verified unbiased: `--panel_only --sun_only --linear --spp=16`, mean linear
  brightness vs a build with mesh NEE disabled matches within 1-2% in the room
  and 0.1% on the sunlit floor (`png_mean`-style sRGB-decoded means; compare
  in linear space, tonemapped means are skewed by noise and clipping).
- 2026-10-08: Step 5 done. B3 cause: `lights_evaluate_direct_lighting()`
  picked one light per hit **uniformly** among the lights in range, so a
  sunlit pixel sampled the sun only 1/3 to 1/4 of the time (the scene has a
  sun, an omni and two spots) and ~30% of pixels at 4 spp never saw it.
  Confirmed with `--sun_only` (sunlit floor became clean). Fix: resampled
  importance sampling with `lights_selection_weight()` (emission luminance x
  attenuation x conservative cosine, spot cone check with a small floor); with
  at most `RT_LIGHT_RESERVOIR_SIZE` (16) lights every light is a candidate.
  Weights are zero only where a light can't contribute, so it stays unbiased
  (brightness matches the old images). Remaining grain is indirect light.
- 2026-10-08: Step 4 done. B1: the closest hit now computes emission from
  color times energy and only multiplies by the texture when one is set. The
  host reads `emission`, `emission_energy` and `texture_emission` only when the
  material's shader declares `emission` (BaseMaterial3D stores every parameter
  but declares the uniform only with emission enabled), so a disabled emission
  never glows. B2: the host packs `alpha_scissor_threshold` into bits 16-23 of
  `MaterialData.flags` (`RT_MAT_ALPHA_THRESHOLD_SHIFT`, read in GLSL with
  `material_alpha_threshold()`); any hit and the ray query shadow test use it.
  Materials without alpha scissor keep the old 0.5 cutoff. Verified: emitters
  glow and light the emissive room (noisy, step 6), the 0.3 scissor sphere and
  its shadow appear. Smoke tests pass.
- 2026-10-08: Step 3 done. Six bugs found (table above). B1 has a confirmed
  root cause. Next is step 4 (B1 and B2).
- 2026-10-08: Steps 1 and 2 done. No fixes yet.
