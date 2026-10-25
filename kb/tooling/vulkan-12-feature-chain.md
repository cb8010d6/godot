---
type: Finding
title: Keep Vulkan 1.2 aggregate and promoted feature structs mutually exclusive
description: Device creation chained the Vulkan 1.2 aggregate together with three individual promoted feature structs.
tags: [vulkan, validation, device-creation, feature-chain]
status: draft
generated: { by: codex, at: 2026-10-25T00:00:00Z }
sources:
  - id: device-create-info
    url: https://docs.vulkan.org/refpages/latest/refpages/source/VkDeviceCreateInfo.html
    title: VkDeviceCreateInfo valid usage
---

# Source finding

`RenderingDeviceDriverVulkan::_initialize_device()` always appended the
individual shader float16/int8 structure, and conditionally appended the
buffer device address and Vulkan memory model structures. On Vulkan 1.2+
it also appended `VkPhysicalDeviceVulkan12Features`, which supplies those
same feature groups. This violates `VUID-VkDeviceCreateInfo-pNext-02830`:
an aggregate cannot coexist with the corresponding promoted structures in
the device creation chain.[^device-create-info]

The capability-query path already selected aggregate or individual structs
according to the API version. Device creation now makes the same selection.
The Vulkan 1.2 aggregate keeps its existing field values. Below Vulkan 1.2,
the original individual structs, feature conditions and field values remain.
All chained locals retain function scope through the device creation call.

# Verification boundary

The actual modified Vulkan driver translation unit compiled to an ELF object
with GCC 14.2 and C++17, using SCons-derived build flags, real vendored Vulkan
headers and generated engine headers. Compilation emitted no warnings.
Formatting and diff checks passed. This was an object compile, not a full
engine link or a Vulkan device creation test.

Windows/RTX acceptance must rebuild the exact candidate and retain the full
validation log. Compare no Streamline, Streamline 2.10 and 2.14.16 controls;
check this specific VUID and rerun PT/RR and dynamic DDGI to exercise the
enabled features. The older API branch has source review but no runtime
coverage in this change. The NIS, FG, surface and D3D12 diagnostics in
[the Windows report](../../devtools/WINDOWS_ACCEPTANCE_2026_10_25.md) remain
separate; no claim is made that this change clears the full validation run.

[^device-create-info]: Khronos normative valid usage for device creation.
