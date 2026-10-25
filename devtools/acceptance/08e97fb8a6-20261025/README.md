# Fixed 08e acceptance evidence archive

This is the 2026-10-25/26 measured Windows/RTX experiment at production
`08e97fb8a6871cfe39f83a24e2a5813936efd208`, **not a full acceptance pass**.
Start with [REPORT.md](REPORT.md). It includes failed and unperformed checks.
Diagnostic devices used `a182f0c9f24411242f18b68aa5d91ece9acb983e`;
the pre-beta control reused `25f6a147ed8ca36d521638ba2b5fe1715a3cbdaa`.
Do not transfer these results to a newer integration head.

## Evidence provenance and scope

- Root receipts preserve real commands, environment flags, input executable
  hashes, source checkout, timestamps, exit status and duration. An exit of
  zero can still mean a Vulkan fallback, validation failure or cache error.
- `logs/` contains complete captured command logs, including failed attempts.
  D3D12 `.debug.log` files contain early native debug output and module loads.
- `gpu/` and `prebeta-20261026/` retain original application-rendered PNGs
  and measured JSON/CSV data. PNG bytes are unchanged. They do not contain
  the NVIDIA presentation overlay or intermediate generated frames.
- `publication-manifest.json` maps raw and public file hashes. Text only
  replaces machine paths with placeholders and normalizes LF line endings;
  JSON is also reserialized.
  Invalid UTF-8 log bytes are preserved as explicit hex escapes, not dropped.
  No counters, timings, failure messages or pass results are synthesized.
- No SDK headers, SDK/runtime DLLs, engine executables, build caches,
  credentials, whole-desktop images or unrelated process snapshots are included.
  Local binary paths in receipts describe measured inputs, not bundled files.
  Application/system Core and SDKLayers provenance stays distinguishable.
- The driver had global SR/RR/FG overrides enabled. Requested K/M/L,
  SL/NGX versions and model-set identifiers do not prove the active DLSS model.
  **DLSS 4.5 active-model identity remains unconfirmed on both backends.**

## Reproduction inputs

Build the pinned production commit with the repo's Windows build/smoke/package
scripts in REPORT.md. Obtain NVIDIA runtimes under their applicable license;
no redistributable permission is implied by this evidence archive. Keep SDKs,
temporary data, NuGet caches and outputs on a drive with adequate free space.
Set `<SOURCE_ROOT>`, `<ACCEPTANCE_ROOT>`, `<PREVIOUS_ACCEPTANCE_ROOT>`,
`<WORKSPACE_ROOT>`, `<TOOLCHAIN_ROOT>` and `<SDK_ROOT>` in archived commands
to your own directories. `%SYSTEMROOT%` and `%USERPROFILE%` are logical
Windows locations. Published text is evidence, not a ready-to-run shell file.

`*-fixture/` preserves the tested GDScript scenes. `tools/rtx_probe.cpp` is
the read-only native probe source; build it against the matching source/API
headers and put the resulting `rtx_probe.dll` beside fixtures that request it.
`tools/debug_capture.cpp` is the native early-debug launcher source; build
it from a VS x64 developer prompt with `cl /std:c++17 /EHsc /W4 /WX debug_capture.cpp`.
It debugs only its own child and confines descendants in a kill-on-close job.
Do not attach to or terminate unrelated applications. Probe binaries and
SDK dependencies must be rebuilt/supplied locally; this archive is not a
self-contained binary test kit. Repository-owned SR policy tests remain in
the pinned candidate's `devtools/` tree.

For the eight D3D12 startup controls, build the separate diagnostic branch.
`GODOT_ACCEPTANCE_FORCE_D3D12_LEGACY=1` deliberately bypasses the Agility
factory only after required library loads. Compare no-SL factory/legacy,
SL2.10 legacy and SL2.14 legacy, each with and without `--gpu-validation`.
Use the logged parameters and binary inventories; verify the **actual**
backend rather than accepting a zero exit after fallback. Do not remove or
replace Agility DLLs to make a failing control appear to pass.

The pre-beta control reused a saved real old engine and identical Agility
Core/layer bytes, not a fresh historical build. Its SDK cannot honor the newer
OTA opt-out and logged downloaded plugin loads. It isolates startup behavior
in the current dependency environment; it is not pure-old-model certification.

AI assistance covered test/diagnostic code and reporting. Builds, SDK calls,
GPU output and measurements came from actual execution. No image was generated
or edited to manufacture GPU/model evidence. The separate diagnostic branch
is an investigative artifact, not a production compatibility fix.
