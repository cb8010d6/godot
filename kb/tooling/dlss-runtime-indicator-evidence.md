---
type: Finding
title: Verify active presets through the runtime indicator, including overrides
description: An accepted application request does not identify the model selected by the driver.
tags: [dlss, streamline, nvidia, validation]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The NVIDIA App overlay reported N/A for FPS and every DLSS override field,
with FrameView already running and App 11.0.9.565 installed. Those fields did
not establish runtime identity. Official release notes document prior N/A
bugs; community reports are troubleshooting leads, not proof of this cause.

The user enabled NVIDIA's separate runtime indicator as documented in the
[DLSS programming guide, section 3.18](https://github.com/NVIDIA/DLSS/blob/main/doc/DLSS_Programming_Guide_Release.pdf).
The one diagnostic registry value was backed up for restoration; this does
not change the preset policy. No generated or edited image is evidence.

Actual unmodified GPU readbacks at 1000baebda show:

* Quality requesting M with the original Recommended override: Render Preset
  K, NGX 310.9.16 `(nvapp_override)`, Vulkan, 1707x960 to 2560x1440.
* Performance requesting M: Render Preset M on both Vulkan and D3D12,
  1280x720 to 2560x1440, NGX 310.9.16 `(nvapp_override)`.
* After the user selected the 3D application's settings, a read-only DRS audit
  reports global SR/RR/FG override/preset values zero. Quality requesting M
  now shows Render Preset M and NGX 310.9.16 `(default)` in actual readback.

This is resolved-preset evidence, independently from SDK options or model
cache filenames. The official SR policy identifies M as the second-generation
transformer; image quality/performance still need their own acceptance.
Ultra Performance at this output size reports a mode-boundary failure on both
backends and is not counted as successful L/model validation. Retain the failed
images and complete logs. OCR is optional derived text and was unreliable for
the tiny indicator font; review the raw pixels instead.
