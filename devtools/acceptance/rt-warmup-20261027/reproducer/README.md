# Minimal Windows Vulkan RR reproduction

This source-only project creates a lit primitive scene and captures one static plus 48 moving-object frames. It contains no private game assets, SDK runtime binaries, exported packs or generated screenshots. The project and probe sources are the exact inputs of the recorded diagnostic run. Review the original result, full log, module samples and SDK state in this bundle before drawing conclusions.

The bounded recorded run used diagnostic engine commit `8b1055662793954959fe5ce8b11843437af0adc3`, Windows 10 build 19045, RTX 4060 Laptop GPU / driver 610.88, Streamline 2.14.16, NGX 310.9.16 and explicit Vulkan validation layer 1.4.366. It completed 49 captures and 160 probe samples with native exit 0, but failed strict validation: two WAW MessageIds and two 09600 MessageIds. All-text VUID tokens repeat the specification references; they are a separate count.

The two temporary trace blocks in that diagnostic commit record supplied Vulkan images and the first actual native RR evaluation return. These are evidence instrumentation, not a production synchronization fix. The later final source removes them. This reproduction does not need the private game, FG plugin or NIS; it does not establish actual model weights, full image quality, timing, or an exclusive SDK root cause.

## Build the read-only probe

Use the fork's matching source checkout with generated `core/extension/gdextension_interface.gen.h` and public Streamline headers already available. Set `GODOT_SOURCE_ROOT` to that checkout and open an x64 Visual Studio Developer PowerShell. From `probe/`, run:

```powershell
cl /nologo /std:c++17 /Zc:__cplusplus /EHsc /W4 /WX /MD /LD `
  "/I$env:GODOT_SOURCE_ROOT" /Fe:rtx_probe.dll rtx_probe.cpp `
  /link Psapi.lib User32.lib /IMPLIB:rtx_probe.lib
Copy-Item -LiteralPath ./rtx_probe.dll -Destination ../project/rtx_probe.dll
```

The probe reads loaded modules and feature getters on the render thread. It never enables or evaluates a feature. When `sl.dlss_g.dll` is absent it explicitly skips the FG getter/version queries without fabricating a success result. The separate `nvngx_dlssg.dll` library can still be mapped; this is not a loaded FG plugin or FG functional validation. Obtain all required runtime dependencies through their normal licensed installation; no DLLs or SDK headers are distributed here.

## Run the native fixture

Set `GODOT_RR_ENGINE` to the standard editor executable, `VVL_DIRECTORY` to the explicit layer directory, and choose a writable evidence directory. Match the loaded layer manifest/version, not the folder's name. Use fresh per-run APPDATA/LOCALAPPDATA/TEMP/TMP directories when collecting comparison evidence, and record their values privately. Example from this reproduction's root:

```powershell
$env:VK_LOADER_LAYERS_DISABLE = '~implicit~'
$env:VK_LOADER_DEBUG = 'error,warn,layer'
$env:VK_INSTANCE_LAYERS = 'VK_LAYER_KHRONOS_validation'
$env:VK_LAYER_PATH = $env:VVL_DIRECTORY
$env:VK_LAYER_SETTINGS_PATH = (Resolve-Path ./settings).Path
$env:GODOT_STREAMLINE_DISABLE_OTA = '1'
$env:GODOT_STREAMLINE_DISABLE_DLSS_G = '1'
$env:GODOT_STREAMLINE_TRACE_RR_RESOURCES = '1' # Only the recorded diagnostic engine emits these markers.
$project = (Resolve-Path ./project).Path
$output = Join-Path $env:EVIDENCE_ROOT ('rr-' + [guid]::NewGuid().ToString('N'))
& $env:GODOT_RR_ENGINE --verbose --max-fps 60 --rendering-driver vulkan `
  --path $project --gpu-validation -- --mode=rr --preset=Recommended `
  --sharpness=0 --suite=motion --warmup=100 "--output=$output"
```

`Recommended` here is retained SR-preset metadata from the original quality control. RR keeps its original `?` preset. The actual test variable is `--mode=rr`; that selects PT and the RR denoiser. Frame Generation stays off and NIS sharpness is zero. Save stdout/stderr and the exit code with a bounded owned-process recorder. The private original controller additionally samples the exact child process's loaded modules and verifies VVL synchronization readback; setting the environment alone is not isolation proof. Close RTSS through its normal UI before a controlled run, verify actual module absence, and do not infer it from an implicit-layer filter alone.

Preserve every error. SDK eOk and native exit 0 do not override VUID/SYNC diagnostics. The recorded diagnostic first call had non-Off mode 3 and result 0, with all eight RR tags. A later SDK2.10 comparison was clean for one bounded run, but a separate old-runtime run lost the device before any RR tags. This bundle does not recommend a production downgrade.
