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
main Vulkan driver enables the Streamline device requirements, publishes
physical-device capabilities and performs SDK post-init. Only the main D3D12
driver uses the Streamline device-creation entry point, registers adapter and
device information, and performs SDK post-init. Local devices use native
creation and never replace that process-wide state. This is explicit
ownership, not an inference from frame count; real SDK registration failures
remain errors.[^driver-owner]

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

# Verification boundary

The local-device crashes above are measured before-fix results. The candidate
has source review and diff validation only; its build and real post-fix
Vulkan/D3D12 local-device, no-runtime, NIS, FG, shutdown and resize checks are
still required. In particular, moving shutdown is not proof that all pacer
teardown VUIDs are resolved. The independent SDK fake-swapchain layout,
present-semaphore reuse, NGX-internal clear/copy and marker-threading
diagnostics retain their original logs and acceptance status.

[^sdk-lifecycle]: The pinned guide's initialization section calls for `slShutdown` before destroying native graphics components.
[^global-finalize]: `finalize_display` joins renderer teardown before native display deletion.
[^rd-finalize]: `is_main_instance` excludes local devices from global SDK finalization.
[^driver-owner]: `set_is_main_device` copies the established RD owner flag before native driver initialization.
