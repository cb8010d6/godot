Windows/RTX runtime follow-up (2026-10-23), testing `0b50d914deb01928f4985b555e4765f8fa16b43b` against base `135dff3887a3d2ccf45cafbd9bdffa7b718e1e76`.

Built instrumented Windows x86-64 template_debug variants using MSVC and ran the real Forward+/Vulkan/Streamline path on an RTX 4060 Laptop GPU (8 GB), driver 610.88, Windows 10 build 19045. Streamline headers/distribution are 2.10.0; the fork's default OTA behavior was retained.

The camera basis/position checks passed **5/5 in each of DLAA, DLSS SR, DLSS RR, and SR+FG**. The unpatched base reproduces the expected non-square/rotated failures. Logs capture actual `slSetConstants` arguments and return values, plus successful real `slEvaluateFeature` calls; no SDK mocks were used. For Y +90 degrees, the real forward vector changed from approximately (1,0,0) to (-1,0,0), matching the Camera3D transform and an independent Rodrigues reference.

FG runtime status was eOk and additional presented frames were observed in all 13 camera cases using the same fixture with Reflex's 60 FPS limiter, 120 settling frames per case, and the test window focused. Initial uncapped/Engine-limiter presentation experiments are retained separately. This does not establish a frame-pacing or performance improvement.

Original scene and motion PNGs, exact source patches, executable/SDK hashes, and raw logs are retained in the local validation bundle. RR emits existing verbose texture-format/reflection diagnostics in the base and PR builds. Vulkan validation layers were unavailable, so this is targeted camera-metadata runtime evidence, not warning-free graphics certification. No ghosting improvement is claimed. Coverage is centered perspective cameras, normal orthonormal transforms, float precision, and Vulkan.

*AI disclosure*: Codex prepared the instrumented builds, ran the checks, and assembled this evidence on behalf of @cb8010d6.
