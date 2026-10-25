---
type: Playbook
title: Validate a Streamline SDK upgrade across its boundaries
description: Keep header, runtime, installer and export versions consistent without mistaking compilation for GPU validation.
tags: [streamline, sdk, packaging, validation]
status: stable
generated: { by: codex, at: 2026-10-24T00:00:00Z }
sources:
  - id: streamline
    url: https://github.com/NVIDIA-RTX/Streamline/releases/tag/v2.14.16
    title: Official Streamline 2.14.16 release
---

# Match the actual release

Verify the official ZIP's complete size and SHA-256, inspect its release
inventory, and vendor the full public header set with its license and source
revision. Do not update only `sl_version.h` or infer DLL names from the source
repository. The 2.14.16 ZIP has 24 headers and the same 19 curated release
runtime/license files used by this integration.[^streamline]

`drivers/streamline/streamline_runtime.h` centralizes metadata and files for
the editor installer, native game exporter, and private package script.
Validate it offline with `devtools/package/streamline_manifest.py` and its
negative fixtures. Public editor/template archives must reject NVIDIA DLLs
even in nested folders or with uppercase names. Private package fixtures
and a header smoke are not native Windows runtime tests.

# Compile real interfaces

SDK 2.14.16 activates deprecation on `PFun_slSetTag`. The integration retains
its old tagging semantics through a narrowly warning-isolated exact-type
alias; migrating the resource-tagging model would require separate runtime
validation. Check SR/DLAA, RR, FG and Reflex signatures, versioned defaults,
and initial disabled state with the real `StreamlineContext` header.

Compile actual driver translation units with real Windows target headers as
well as Vulkan and D3D12 defines. The 2026-10-24 upgrade used MinGW-w64
GCC 14 and produced AMD64 Windows COFF objects for both adapter branches
and `LoadLibraryA` / `GetProcAddress`. This checks compilation only. Native
MSVC builds, missing/partial/previous DLL installations and GPU evaluation
remain distinct checks in [the upgrade guide](../../devtools/UPGRADE_4_8_BETA1.md).

# Resume optional SDK builds carefully

The existing PhysX helper's project generation deletes configuration build
directories. If PhysX succeeded and Blast or Flow later failed, resume that
optional stage directly rather than rerunning the helper and rebuilding the
CPU SDK. Keep source pins and module patches unchanged. SDK CPU simulation
or Flow loader tests must not be presented as GPU/engine integration tests.

[^streamline]: Verified official release, not an independently repackaged SDK.
