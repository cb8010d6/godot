---
type: Finding
title: PT and RR storage-image formats must match their allocations
description: Real Vulkan validation found two inherited shader-image format mismatches despite apparently rendered screenshots.
tags: [pathtracing, streamline, vulkan, formats]
status: draft
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

Khronos validation layer 1.4.366, official nightly commit
`bc5da10620168c5370f82257528c08756e19a7b2`, reported two format mismatches
on RTX 4060 / driver 610.88 in the actual Vulkan PT+RR glass/emissive/custom
shader/light scene: binding 0 expected rgba32f but received RGBA16F; binding
11 expected rgba16f but received RGBA8_SNORM. Both allocation/declaration
pairs already existed at pre-upgrade `25f6a147e`.

Match the raygen output declaration to the existing RGBA16F RT output, and
allocate the RR world-normal/roughness guide as RGBA16F as declared by every
hit shader. Albedo, specular distance, velocity and depth formats are unchanged.
This is a local existing-defect correction, separate from the upgrade branches.
Affected builds and validation regression are pending. A plausible screenshot
alone did not establish a correct storage-image contract.
