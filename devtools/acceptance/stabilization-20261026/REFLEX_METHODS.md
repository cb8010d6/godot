# Reflex report and marker audit, d37 (read-only)

Audit completed against engine `d37b63e72bd5b0b72c8d72adb7cceb1b20e1b1f8`. This work only reads existing native artifacts/source and runs a CPU-only JSON analysis. It does not change engine/fixture code, compile, launch Godot/GPU work, or alter driver settings. The analysis tool `analyze_reflex_readonly.py` and original detailed `reflex-report-summary.json` are retained in the private task evidence and are not distributed in this bundle. See the [sanitized Reflex summary](evidence/reflex-summary.json) for derived values and original-input SHA-256.

## Result: the reports are not all zero

Every d37 strict FG case has 261 samples, 261 native `slReflexGetState` result=0 values, 261 `report_available=true` values, and 261 `low_latency_available=true` values. The initial zero sample is a startup sample, not the result of the run. Each case consists of 249 samples requested as FG followed by 12 samples after the fixture switches to native mode for cleanup.

| d37 strict SDK2.14 FG case | All exported timestamps zero | Any nonzero timestamp | Positive frame ID plus all 8 exported timestamps positive | First such engine frame / SDK report ID | Same complete count while requested mode is FG |
| --- | ---: | ---: | ---: | --- | ---: |
| Vulkan, sharpness 0 | 12 | 249 | 249 | 12 / 3 | 237 / 249 |
| Vulkan, sharpness 0.2 | 12 | 249 | 249 | 12 / 3 | 237 / 249 |
| D3D12, sharpness 0 | 79 | 182 | 162 | 79 / 77 | 150 / 249 |

Input paths are `stabilization-20261026/gpu/final-d37b63e72b-strict-{backend}-sdk214-fg-Recommended-{sharpness}-motion/sdk-state.json`. Native getter success and `report_available` are not sufficient per-record completeness checks: the d37 D3D12 data contains 20 positive-frame-ID reports with `gpu_end=0`. No other exported timestamp is zero in those positive-ID partial reports.

Example first nonzero Vulkan report (sharpness 0, engine frame12, report3): sim `[1792956497399861,1792956497399984]`, render-submit `[1792956497399990,1792956497400973]`, present `[1792956497403048,1792956497403902]`, GPU `[1792956497476080,1792956497477812]`. This is real returned driver timing data, not an availability-only assertion.

All four exported start/end pairs in complete d37 reports are individually ordered. However, **all 162 complete D3D12 reports have GPU start earlier than that report's simulation start**. Example engine79/report77: GPU start `1792956821351800`, simulation start `1792956821379145`. Do not turn these values into a claimed canonical per-frame end-to-end latency. The precise reason for D3D CPU/GPU correlation is not established by this read-only audit; possible driver/FG correlation or marker-to-frame association must remain unresolved rather than being guessed away.

## Old same-fixture controls

| Binary checkout and case | Samples | All-zero startup samples | Any nonzero time | All8 positive with positive ID | First complete engine frame / report ID |
| --- | ---: | ---: | ---: | ---: | --- |
| `036c6c7023`, strict Vulkan FG sharp0 | 261 | 12 | 249 | 249 | 12 / 3 |
| `036c6c7023`, strict Vulkan FG sharp0.2 | 261 | 12 | 249 | 249 | 12 / 3 |
| `036c6c7023`, strict D3D12 FG sharp0 | 261 | 79 | 182 | 156 | 79 / 77 |
| `1000baebda`, `prod-pix1-debug-fg-sl214` D3D12 | 260 | 88 | 172 | 166 | 88 / 87 |

036c inputs are the `gpu/final-strict-.../sdk-state.json` cases and receipts confirm checkout036c; 1000 uses `gpu/prod-pix1-debug-fg-sl214/sdk-state.json` with its matching receipt. Both older D3D12 controls already show GPU-start-before-simulation reports. 036c also has one reversed render-submit pair among its 156 complete exported rows, which d37 does not reproduce in these rows. These old measurements are not evidence of a new shutdown-change regression or proof that cross-clock/frame correlation is sound.

The two d37 strict **Quality** controls deliberately request Reflex mode0/frame-limit0 in the same fixture yet still produce complete timestamp reports: Vulkan148/160, D3D12 80/160. Thus a nonzero report itself also does not prove low-latency mode is currently active. Timing collection and low-latency enablement are distinct.

## Probe/ABI check

`acceptance-20261025/rtx_probe.cpp:102` resolves the actual native `slReflexGetState` from the loaded `sl.interposer.dll` and calls its declared `PFun_slReflexGetState` signature with a genuine `sl::ReflexState`. It does not construct an alternative byte layout. `sl_reflex.h:97` defines version2; the `SL_STRUCT_BEGIN` constructor in `sl_struct.h` supplies the correct GUID/version and initializes nested report objects/zero-initialized timestamp members. The current header and cached214 API header differ only in line endings (`git diff --no-index --ignore-space-at-eol` reports no content difference).

The probe scans **all 64** `frameReport[]` slots and chooses the slot with maximum `frameID` (`rtx_probe.cpp:106-111`), not a hard-coded slot0. It exports eight named time members from that selected slot. Index0 is selected only when no greater frame ID was found. This is reasonable for latest-ID sampling, but it does not select the latest **complete** report. The 20 D3D12 partial newest reports are not proof all64 SDK slots are incomplete; older complete records in the same native state were not exported and cannot be recovered from the JSON. A future test-only probe could export index/all64/completeness and the most recent complete slot alongside the newest slot; no engine change is needed merely to make that distinction.

The fixture schedules the native call on `RenderingServer.call_on_render_thread` after `frame_post_draw` (`gpu-fixture/main.gd:56-66`) and flushes probe tasks through a render-thread barrier before saving (`:264`). The fixture DLL matches the original acceptance DLL exactly: SHA256 `8CAF2ABF4E854615EFA0D89E6E0F881F256BFE43BC78E74124DF6D67A4B801AF`. The probe omits input-sample, driver, OS queue and Report2 fields; it records no mode-active getter or per-call sleep effectiveness. Exported timestamps here are below 2^53, so Godot's JSON double representation preserves their integer values; there is no observed float precision explanation for zero/misaligned times.

## Marker/token order and evidence limit

The fixture sets Reflex mode1 and frameLimitUs16666 for FG, then mode0/limit0 when switching to native (`gpu-fixture/main.gd:103-104`). On active FG frames the host path is:

1. At the preceding iteration's end, BEFORE_MESSAGE_LOOP applies dirty options, obtains the next token, and calls sleep (`main/main.cpp:5303`, `drivers/streamline/streamline.cpp:153-169`).
2. Windows processes its loop/messages, then the next `Main::iteration` emits simulation-start and simulation-end (`main.cpp:5012,5168`).
3. RendererCompositorRD emits render-submit start/end (`renderer_compositor_rd.cpp:136,140`).
4. Vulkan or D3D12 wraps actual present with present start/end (`rendering_device_driver_vulkan.cpp:3545,3563`; D3D12`:2658,2671`).
5. The next iteration token is obtained at the next BEFORE_MESSAGE_LOOP. All these marker calls use the shared `last_token`; an absent first token skips markers during startup. `get_new_frame_token()` invokes the real SDK entry with auto ID (`streamline_context.cpp:269`).

The fixture does not override thread_model; current engine default is Safe (`main.cpp:2824`), so the renderer executes synchronously for this configuration. A separate-render-thread integration would need its own token lifetime/order review; it is not validated by these data. The active-frame sequencing has not changed between1000 and d37; the relevant diff adds lifecycle guards/terminal cleanup, not a new marker schedule.

The pinned guide says PCL markers and sleep should continue even when Reflex is Off. Current host only sleeps when mode!=Off or frameLimitUs>0, and its PCL emission is gated on Reflex availability. Those are bounded integration differences for Off/unsupported paths, not an explanation for absent FG timestamps: the FG mode1/limit16666 branch does call sleep, and its timing path produces data. Do not expand this note into an unmeasured engine refactor. Current marker surface also does not provide an explicit input-sample marker here, and the probe does not export inputSampleTime.

The pinned SDK's [Reflex get-state implementation](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/plugins/sl.reflex/reflexEntry.cpp#L496) sets availability flags from getSleepStatus/getLatencyReport call success. [D3D Generic::getSleepStatus](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/platforms/sl.chi/generic.cpp#L1277) checks API success without publishing an active-mode boolean; getLatencyReport copies real `NvAPI_D3D_GetLatency` report fields. [Vulkan LL2 getReport](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/platforms/sl.chi/vknvll2.cpp#L242) copies `vkGetLatencyTimingsNV` data and can return eOk with empty/unpopulated data during startup. This explains why an available flag is not a completeness or active-state proof.

**Supported claim:** the configured FG path requests Reflex low-latency mode, calls the sleep/marker integration, and successfully receives advancing native driver timestamps on both backends. Vulkan also reports real latency API calls in validation messages. **Unsupported claims:** low_latency_available means active, all returned rows are complete, Reflex reduced latency by a stated amount, validated physical input-to-display latency, complete Reflex QA/certification, or validation-clean Vulkan Reflex/FG. The existing SDK-side Vulkan latency-marker/sleep versus pacer threading messages remain visible and unresolved. A/B Off/On timing, an active-mode observation, input/PCL Test Utility evidence or external physical measurement are separate evidence layers.

Pinned primary documentation: [ProgrammingGuideReflex](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideReflex.md), especially its distinct support/mode controls, always-call guidance and QA checklist.

## Narrow follow-up: core/KHR synchronization2 hypothesis

The specific claim that d37's Vk1.4 host uses core `vkCmdPipelineBarrier2` while SL only intercepts `vkCmdPipelineBarrier2KHR` is **excluded for the current host path**. `rg` over `drivers/vulkan` finds no `CmdPipelineBarrier2`, `VkDependencyInfo`, `VkImageMemoryBarrier2`, or synchronization2 use. The general command barrier (`rendering_device_driver_vulkan.cpp:3242,3252`), explicit swapchain barrier (`:5902`) and optional breadcrumb barrier (`:7294`) all call legacy `vkCmdPipelineBarrier`.

Godot initializes Volk with SL gIPA and loads the instance through it (`rendering_context_driver_vulkan.cpp:924-928,770`). The [public SL214 wrapper](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/core/sl.interposer/vulkan/wrapper.cpp#L2334) explicitly maps **legacy** `vkCmdPipelineBarrier` in both GDPA and GIPA. In that public source, core2 is a forwarding wrapper and there is no `vkCmdPipelineBarrier2KHR` name/map. This is not a finding that both synchronization2 aliases are hooked; the narrower reason for exclusion is that this Godot driver invokes neither alias. It does not justify switching all host calls or patching core/KHR routing.

The public wrapper does not expose the private DLSS-G fake-swapchain layout rewrite implementation. Therefore this source inspection excludes the proposed host alias miss, while not proving every private SDK layout transition correct. Existing09600/03868 and SDK pacer resources still need their original raw evidence/ownership classification; no additional host dispatch change is justified by this alias hypothesis.
