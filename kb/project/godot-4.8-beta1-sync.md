---
type: Finding
title: Pinned Godot 4.8 beta 1 integration
description: Source audit, preservation rules and validation boundaries for the beta 1 sync.
tags: [project, upgrade, rendering, validation]
status: draft
generated: { by: codex, at: 2026-10-24T00:00:00Z }
sources:
  - id: godot-beta
    url: https://github.com/godotengine/godot/commit/4d10419cacd6d3009976e8f9fd3abd970fd58018
    title: Official Godot 4.8 beta version commit
  - id: runbook
    resource: ../../CUSTOM_BUILD.md
    title: Source synchronization runbook
---

# Source and preservation

Start from Diginaat `dev` at `25f6a147ed8ca36d521638ba2b5fe1715a3cbdaa`.
The default branch is two README-only commits ahead, not a second functional
baseline. Merge exactly `4d10419cacd6d3009976e8f9fd3abd970fd58018`, rather
than a moving upstream master. Its version source says `beta`; the numbered
build uses `GODOT_VERSION_STATUS=beta1` without editing `version.py`.[^godot-beta]

The merge had one textual conflict in `CODEOWNERS`. Automatic shader and
renderer merges also need review: retain shader container version 5,
unbounded/physical-address reflection, all five RT stages, custom PT/DDGI
render paths, native-runtime export hooks, and matched Mono native/managed
ABI changes. The new host `container_header` member does not change the
serialized reflection layout. Keep the upstream Vulkan descriptor indexing
fix. PhysX is still vendored; do not merge its older engine branch or replace
its local adaptations.[^runbook]

# Verification boundary

The integration's standard Linux editor compiled and passed 1465 native
test cases and 442079 assertions (three inherited default skips), plus 79
headless fork-compatibility checks. The combined worktree also contains the
following Streamline SDK upgrade; Windows Streamline is disabled in this
Linux build. Thus native tests establish engine/headless compatibility, not
DLSS, RR, FG, Reflex, D3D12, GPU PhysX or rendered PT/DDGI correctness.

The PhysX CPU, Blast and Flow SDKs were built at the existing pin and tested
with real CPU simulation, fracture/serialization, and Flow CPU loader/device
operations. The Mono editor and all four templates also built with those
SDKs. Both standard templates passed 87 checks in real exported PCKs; both
Mono templates passed 88. Managed Debug/Release assemblies and tooling built
on .NET 10, 43 source-generator tests passed, and an actual C# scene verified
dictionary and typed PhysX ray queries against known ground geometry.
All six binaries were rebuilt and rechecked at integration code commit
`0af58f0a62f05a901e99dde96f1654c35a6bdbc1`.

Real C# Debug and Release exports also passed self-contained publication
and normal exported startup without SDK discovery. Their native Linux SDK
shared libraries were supplied explicitly by the fixture. Windows runtime
redistribution and embedded-PCK exports remain separate checks.

These are CPU/headless checks with Vulkan compiled in, not rendered GPU
tests. Full procedures, flags and remaining platform checks are maintained
in [the upgrade guide](../../devtools/UPGRADE_4_8_BETA1.md).

[^godot-beta]: Official source version commit.
[^runbook]: Source synchronization and conflict rules.
