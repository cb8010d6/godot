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

The first implementation at b8d791fa87 failed actual Vulkan startup: the
registered window class also retained a null instance. The engine fell back
to D3D12 with exit zero. Those rows are failed Vulkan controls, not successes.
The revised fallback uses the current application module when both the
optional supplied instance and GWLP_HINSTANCE are null. Rebuild and repeat
the requested backend checks; preserve the first failure logs.

At 92dd424cf0 the corrected standard editor build passed (79.422 s), all
nine short runs used their requested Vulkan/D3D12 backends, and the no-SL
Vulkan run had no VUID or sync messages. Native-probe state samples are now
required. Other SDK/FG diagnostics remain; this result covers the surface
parameter fix rather than full Vulkan acceptance. Console/export/lifecycle
coverage remains part of the final regression.
