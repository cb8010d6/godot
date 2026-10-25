---
type: Finding
title: Reconcile DLSS input rounding against runtime bounds before allocation
description: Ultra Performance can expose a fixed integer input that differs by one pixel from viewport ceil rounding.
tags: [dlss, streamline, rendering, testing]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
sources:
  - id: sdk
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/include/sl_dlss.h
    title: Pinned Streamline DLSS optimal-settings interface
  - id: implementation
    resource: ../../servers/rendering/renderer_viewport.cpp
    title: Viewport internal size and jitter configuration
  - id: policy-test
    resource: ../../devtools/test/test_streamline_dlss_sizing.cpp
    title: Standalone CPU sizing-policy regression checks
---

# Measured mismatch

On an RTX 4060 Laptop GPU at fullscreen 2560 x 1440, Streamline 2.14.16 and
NGX 310.9.16 returned Ultra Performance optimal=min=max=853 x 480. The
viewport's single-precision 1/3 scaling followed by ceil produced 854 x 480,
so no mode accepted that input. Vulkan and D3D12 control runs queried all
seven SDK mode enum values; SR default/K/L/M and RR default getters returned
identical results across both backends. This is a runtime observation,
not a universal rounding rule for other SDK versions or output sizes.

# Correction boundary

The DLSS-only sizing policy keeps any size accepted by any successful,
well-formed SDK result. If none accepts it, the policy permits clamping to an
SDK range only when each axis changes by at most one pixel. Failed queries,
zero or inverted bounds, and an optimal size outside its bounds cannot
justify adjustment. Larger unsupported gaps retain the existing failure
path. The strict DLSS mode selector remains unchanged.[^sdk]

Apply the selected dimensions before calculating jitter count and assigning
both viewport internal size and render-buffer configuration. Resizing only
the allocated textures would leave the camera jitter divisor and render
buffers inconsistent.[^implementation]

The independent CPU test passed 35 checks with Windows MSVC `/W4 /WX`. It
consumes captured sizes and synthetic boundary cases; it does not load SDK
libraries or verify a GPU feature. Patched-engine
Ultra Performance rendering and the active model still require separate
Windows GPU validation.[^policy-test]

[^sdk]: The SDK defines optimal, minimum, and maximum render dimensions.
[^implementation]: `_configure_3d_render_buffers` computes jitter and passes internal dimensions to rendering.
[^policy-test]: Valid inputs, cross-mode precedence, independent axes, one-pixel limits, malformed results, and unsigned distances.
