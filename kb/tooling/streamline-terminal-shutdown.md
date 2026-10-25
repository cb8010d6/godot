---
type: Finding
title: Keep Streamline owned by the main device and shut it down before native teardown
description: Local RenderingDevice creation rewrote SDK registration, local destruction closed the global SDK, and final shutdown happened after main swapchain release.
tags: [streamline, rendering, lifetime, vulkan, d3d12, testing]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
sources:
  - id: sdk-lifecycle
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideDLSS_G.md
    title: DLSS-G programming guide initialization and shutdown
  - id: global-finalize
    resource: ../../main/main.cpp
    title: Global display finalization
  - id: rd-finalize
    resource: ../../servers/rendering/rendering_device.cpp
    title: RenderingDevice finalization and main-device ownership
  - id: driver-owner
    resource: ../../servers/rendering/rendering_device_driver.h
    title: Explicit main-device ownership passed to native drivers
  - id: vulkan-interposer
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/core/sl.interposer/vulkan/wrapper.cpp
    title: Pinned Streamline Vulkan device creation hook
---

# Two distinct lifetime problems

At `036c6c7023`, actual Windows RTX 4060 Laptop controls on Vulkan and D3D12
created and destroyed a local RenderingDevice while the main renderer was
still active. Both then changed main SDK availability from true to false,
reported `eErrorNotInitialized`, and exited with `0xC0000005`. D3D12 also
reported `eErrorInvalidIntegration`. The archived
`local-rd-before-matrix.json` and original logs retain those failed runs.
Both backend destructors emitted a process-wide Streamline shutdown marker,
so a local device could terminate the SDK used by the main renderer.

The D3D12 `eErrorInvalidIntegration` was a separate creation-time error in
`StreamlineContext::init_device_d3d12`, before `LOCAL_RD_CREATED`. Every D3D12
driver initialized the global SDK device again; both backends also rewrote
global capabilities and post-init state for local devices. Avoiding shutdown
alone would leave that registration error uncorrected.

Normal Windows exit had a separate ordering gap: DisplayServer released the
main swapchain before deleting RenderingDevice, and SDK shutdown happened
even later in the backend destructor. Host frame-fence waits alone do not
establish completion of the SDK pacer's separate queue. The pinned SDK guide
requires shutdown before native graphics components are destroyed.[^sdk-lifecycle]

# Candidate correction

RenderingDevice passes its existing `is_main_instance` value to the driver
before driver initialization. The driver flag defaults to false. Only the
main Vulkan driver publishes global physical-device capabilities and performs
SDK post-init. Only the main D3D12 driver uses the Streamline device-creation
entry point, registers adapter and device information, and performs SDK
post-init; local D3D12 devices use native creation. This is explicit host-side
SDK ownership, not an inference from frame count; real SDK registration
failures remain errors.[^driver-owner]

Vulkan still uses the process-wide SL instance dispatch for local device
creation. The interposer can inject SDK-required device extensions into every
`vkCreateDevice`, so all such devices must receive the supported private-data
and present-id prerequisites while the SDK is initialized. This requirement
does not authorize a local RD to change global SDK capabilities, options,
device registration, or post-init state. It also does not claim complete
native Vulkan dispatch isolation.

After the global RenderingServer has finished and released its DLSS/NIS
contexts, final display cleanup takes ownership of the main RD on the main
thread, flushes and waits for host frame work, then calls Streamline shutdown
before DisplayServer destroys the main swapchain. This also preserves the
context destructor's guarded `slFreeResources` call before plugin unload.
An additional main-device-only RD finalization call covers failed graphics
setup; repeated terminal calls are harmless. Local-device destruction never
closes the global SDK.[^global-finalize][^rd-finalize]

A successful SDK initialization flag is separate from merely loading
`slInit`/`slShutdown` entry points. Failed initialization does not authorize
calling SDK shutdown. The shutdown path consumes its function pointer once,
retains any returned SDK error, clears callable plugin pointers, the current
frame token, capabilities and FG status, and guards later host markers.
The interposer module remains loaded so previously obtained native API
function tables stay valid. The existing non-null `slInit` sentinel is kept;
this change does not introduce SDK reinitialization within one process.

# Terminal Vulkan queue wait candidate

Waiting for Godot frame fences does not wait for every queue owned by the
Vulkan device. In the `d040fbbe7d` validated local-device control, pacer
semaphores and the real swapchain still reported `05149`/`01282` in the
terminal path before the SDK shutdown completion message. That message alone
does not establish which earlier cleanup call issued each native destruction.

The main Vulkan driver now registers a terminal wait callback immediately
after successful device creation, before subsequent allocator or pipeline
initialization can fail. Local devices do not register or replace it. SDK
shutdown consumes the callback and userdata once, invokes it only if SDK
initialization succeeded, then shuts down the SDK. The callback keeps Vulkan
types in the Vulkan driver; no RDD virtual interface is added.

The wait resolves `vkDeviceWaitIdle` through the active SL-interposed GDPA,
preserving `eVulkan_DeviceWaitIdle` before-hooks that can coordinate the
pacer before the underlying device wait. Bypassing directly to the system
loader would omit those hooks.[^vulkan-interposer] Missing device or function
pointers and non-success results, including `VK_ERROR_DEVICE_LOST`, remain
explicit errors. SDK cleanup still runs after a wait failure, but its `eOk`
does not produce the ordinary successful-shutdown message or establish idle.
Verbose start/completion markers distinguish the wait from SDK shutdown.

The pinned DLSS-G guide's section 18 places `waitForIdle()` before releasing
backbuffers and the swapchain; it does not state that every `slShutdown()`
must call this exact Vulkan API. The SDK's private pacer wait implementation
is not established by the public wrapper, so real strict-validation shutdown
and local-device controls are still required before claiming those VUIDs are
resolved.[^sdk-lifecycle]

# Verification boundary

At `d040fbbe7d`, the Vulkan local-device after-control completed with exit
code 0 and preserved main SDK availability across local creation/destruction.
Strict validation exposed one new `01387` during local `vkCreateDevice`:
the final extension list contained `VK_NV_low_latency2` without
`VK_KHR_present_id` or `VK_KHR_present_id2`. The main device had enabled those
prerequisites, but the local-device owner guard had incorrectly omitted them.
The original after-control logs retain this regression and the independent
SDK fake-layout, semaphore and teardown diagnostics. The requirements-only
follow-up still needs a real validated local-device run.

The original local-device crashes remain measured before-fix results. The
Vulkan after-control provides partial runtime evidence for the ownership and
shutdown correction; the requirements follow-up has source review and diff
validation only. Its build and real post-fix Vulkan/D3D12 local-device,
no-runtime, NIS, FG, shutdown and resize checks remain separate requirements.
In particular, moving shutdown is not proof that all pacer
teardown VUIDs are resolved. The independent SDK fake-swapchain layout,
present-semaphore reuse, NGX-internal clear/copy and marker-threading
diagnostics retain their original logs and acceptance status.

[^sdk-lifecycle]: The pinned guide's initialization section calls for `slShutdown` before destroying native graphics components.
[^global-finalize]: `finalize_display` joins renderer teardown before native display deletion.
[^rd-finalize]: `is_main_instance` excludes local devices from global SDK finalization.
[^driver-owner]: `set_is_main_device` copies the established RD owner flag before native driver initialization.
[^vulkan-interposer]: The device creation hook merges loaded plugin extension requirements before calling the system loader.
