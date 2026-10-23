# Godot PR 17 / 18: measured Windows / RTX results

Date: 2026-10-23, Australia/Sydney.

The targeted camera-metadata runtime checks passed for both PRs on an NVIDIA
GeForce RTX 4060 Laptop GPU (8 GB), driver 610.88, Windows 10 build 19045,
Vulkan 1.4.341, Forward+ with Streamline. The real SDK calls were recorded;
no SDK mocks or headless rendering were used.

- [PR 17](https://github.com/NVIDIA-RTX/godot/pull/17): all 8 FOV cases passed in
  each of DLAA, SR, RR, and SR+FG (32 target cases).
- [PR 18](https://github.com/NVIDIA-RTX/godot/pull/18): all 5 basis/position cases
  passed in each of the four modes (20 target cases).
- The combined build passed all 13 camera cases in all four modes.
- The base reproduced the six non-square FOV failures and four rotated-camera
  basis failures in every mode. Single-PR builds retain the other known defect,
  as expected. Square and identity controls pass.

These results verify the specific camera corrections. They do not establish a
ghosting, image-quality, or performance improvement, or certify the whole fork.

## Provenance and procedure

Base: `135dff3887a3d2ccf45cafbd9bdffa7b718e1e76`.
PR 17: `2ccecd2d10d2304e442dc8fb94a6878cd61d08be`.
PR 18: `0b50d914deb01928f4985b555e4765f8fa16b43b`.

Four Windows x86-64 template_debug executables were built using MSVC and the same
local logging instrumentation. The two changed source files are read directly
from the exact commits. Other production files remain at the base. The engine's
version string therefore reports the base SHA for all variants; source manifests
and executable SHA-256 values identify the tested variants. No resource-layout
or other production fix was included.

The installed SDK distribution is Streamline 2.10.0, matching the repository's
headers. NVIDIA signatures were verified. The fork's default OTA behavior was
retained; runtime logs include SDK signature/load messages. Per-run manifests
record observed loaded SDK module hashes. See `logs/*-manifest.json`,
`logs/*-source.patch`, `captures/*/*/run.json`, and [README.md](README.md).

The fixture uses 720x720, 1440x810, 1680x720, and 810x1440. Their scaled input
sizes retain exact aspect ratios at 2/3 scale. This avoids conflating integer
render-size rounding with the FOV regression. KEEP_WIDTH/KEEP_HEIGHT both use
90 degrees. Rotation cases include identity, the three positive 90-degree axis
rotations, and a 0.73-radian (1,2,3) rotation, at position (3,-7,11).

Eight settled frames are checked per static case, using camera projection plus
analytical FOV references and independent Rodrigues rotation references. Each
sample records the actual `slSetConstants` values and SDK return code, followed
by the actual `slEvaluateFeature` return code. RR was active in every RR case.
All runs exited normally and reported zero SDK errors and zero engine errors.

Measured coverage: **16 runs, 208 static cases,
1664 settled samples, 15504
captured real constants calls**, plus short camera/object motion sequences.

## Results

The expected remaining failures in single-PR builds demonstrate isolation.
The SDK column counts cases with successful constants and feature evaluation.
FG extra-present counts cases that observed more than one presented frame per
application iteration, not merely a successful enable call.

| Variant | Mode | FOV correct | Basis correct | SDK cases | FG extra-present |
| --- | --- | --- | --- | --- | --- |
| baseline | DLAA | 2/8 | 1/5 | 13/13 | - |
| baseline | SR | 2/8 | 1/5 | 13/13 | - |
| baseline | RR | 2/8 | 1/5 | 13/13 | - |
| baseline | FG | 2/8 | 1/5 | 13/13 | 13/13 |
| pr17 | DLAA | 8/8 | 1/5 | 13/13 | - |
| pr17 | SR | 8/8 | 1/5 | 13/13 | - |
| pr17 | RR | 8/8 | 1/5 | 13/13 | - |
| pr17 | FG | 8/8 | 1/5 | 13/13 | 13/13 |
| pr18 | DLAA | 2/8 | 5/5 | 13/13 | - |
| pr18 | SR | 2/8 | 5/5 | 13/13 | - |
| pr18 | RR | 2/8 | 5/5 | 13/13 | - |
| pr18 | FG | 2/8 | 5/5 | 13/13 | 13/13 |
| both | DLAA | 8/8 | 5/5 | 13/13 | - |
| both | SR | 8/8 | 5/5 | 13/13 | - |
| both | RR | 8/8 | 5/5 | 13/13 | - |
| both | FG | 8/8 | 5/5 | 13/13 | 13/13 |

Example real SR capture for horizontal FOV 90 degrees at 16:9:

| | cameraFOV radians | degrees |
| --- | ---: | ---: |
| Base | 2.116813660 | 121.284489 |
| PR 17 | 1.024778962 | 58.715509 |
| Reference | 1.024778921 | 58.715507 |

For Y +90 degrees, real SR forward changed from
`[1.0, 0.0, 4.37113882867379e-08]` to `[-1.0, 0.0, 4.37113882867379e-08]`,
matching `(-1,0,0)` within floating-point tolerance. Position, aspect ratio,
unit axes, and the other expected directions were also checked.

## Visual evidence and limits

- [Mode comparison](runtime-contact-sheet.png): base/combined rotated camera.
- [Aspect comparison](aspect-contact-sheet.png): base/combined RR at all ratios.
- [Motion samples](motion-contact-sheet.png): base/combined RR at seven times
  after the camera transition. The initial frame-0 capture retains the preceding
  settled pose due to render-queue latency; it remains with the original PNGs
  and is excluded from this comparison sheet.
- Original PNGs and case references remain under `captures/`; their hashes and
  dimensions are listed in `logs/image-inventory.json`.

The images show a rendered scene, including RR shadows and rotated/portrait
views. The game captures contain application-rendered frames; intermediate FG
frames are established by SDK presentation counters, not captured as PNGs.
No quantitative ghosting or performance benchmark was performed.

FG was also repeated with 120 settling frames per case, a 60 FPS limit through
the Streamline Reflex API, and focus requested for its own test window. Initial
uncapped runs had intermittent one-frame presentation counts despite status
eOk; those records remain in `captures-initial-fg/`. An Engine.max_fps=60
experiment also reported only single frames and is retained under
`captures-engine-cap-fg/`. The SDK's bundled programming guide, section 14,
states that interpolated frames may be dropped due to presentation timing. The
final FG counts in the table are the Reflex-limit runs. This comparison does
not isolate window focus from the choice of limiter, and does not establish a
general frame-pacing repair or benchmark.

RR emits existing verbose diagnostics in the base and PR builds:

```text
Image (binding: 0, index 0) needs to have the same texture format as the uniform (expected: R32G32B32A32_Sfloat, actual: R16G16B16A16_Sfloat).
Image (binding: 11, index 0) needs to have the same texture format as the uniform (expected: R16G16B16A16_Sfloat, actual: R8G8B8A8_Snorm).
OpTypeForwardPointer is not supported yet.
```

The texture-format messages are `print_verbose` diagnostics at
`servers/rendering/rendering_device.cpp:4627`; they are not suppressed or fixed
by these camera PRs. RR still rendered and SDK evaluation returned eOk. A clean
Vulkan validation-layer run remains outside this evidence: the machine's loader
reported missing layer manifests. These results must not be described as a
warning-free graphics validation or a general RR integration certification.

Other limits: centered perspective cameras, float precision, Vulkan, normal
orthonormal camera transforms, one laptop/driver. Orthographic, asymmetric,
double-precision, Direct3D 12, other GPUs/drivers, and longer content-specific
visual acceptance remain separate coverage.

## Retained failed setup attempts

The initial launch used unsupported template `--path` overrides. The fixture was
changed to an ordinary main scene beside the executable. An absent empty global
script-class cache was then supplied. Setup logs remain under `logs/`; final
evidence contains neither error. One long command session ended during a PR 18
RR launch without a run manifest or observed exit status; its incomplete log is
`logs/pr18-rr-interrupted-runtime.log`. A fresh, individually bounded RR run
completed normally. The incomplete attempt is not counted as a pass or assigned
an engine-crash diagnosis.

This evidence is published separately from the production PR diffs.
Local English comment drafts: [PR 17](pr17-validation-comment.md) and
[PR 18](pr18-validation-comment.md).
