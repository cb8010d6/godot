---
type: Finding
title: Vulkan surfaces need the module instance of their actual Win32 window
description: Recover a missing entry-point HINSTANCE from GWLP_HINSTANCE instead of passing null to Vulkan.
tags: [windows, vulkan, validation, surface]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The no-Streamline real-GPU control reports surface hinstance VUID 01307.
`widechar_main` constructs OS_Windows with null; that value reaches
VkWin32SurfaceCreateInfoKHR even though the native window has a valid owner.
This is inherited behavior, independent of NIS and the Streamline upgrade.

The candidate preserves an explicitly supplied instance and otherwise reads
GWLP_HINSTANCE from the actual HWND. It reports missing ownership instead
of passing an invalid Vulkan parameter. Build and actual no-SL/SL plus console
launcher checks are required before declaring this fixed. The existing
promoted-feature chain is unchanged.
