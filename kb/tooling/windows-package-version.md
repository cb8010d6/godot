---
type: Finding
title: Read the release status from the packaged editor
description: The beta1 build override must survive editor packaging without modifying upstream version.py.
tags: [windows, packaging, version, testing]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

The pinned upstream `version.py` says `beta`, while the actual release build
uses `GODOT_VERSION_STATUS=beta1`. Reading the source file for the package's
release tag therefore lost the numeric status suffix. Parse the status from
the built editor's `--version`, as the template packager already does.

Actual standard and Mono editor packages built from engine `1381c32593`
reported `godot4.8-beta1-nvidia-rt-dlss-physx-v0.7.3`. Both template archives
installed as `4.8.beta1` and `4.8.beta1.mono`. All four installed-template
Debug/Release games exported and ran on D3D12 / RTX 4060 / driver 610.88.
The Mono games were self-contained and ran without SDK discovery. Public
ZIP/TPZ scans excluded NVIDIA Streamline runtime binaries. Nothing was published.
