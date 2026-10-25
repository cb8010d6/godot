---
type: Finding
title: Windows RTX acceptance at C1 and d37
description: Native build and GPU results with separate source revisions and unresolved SDK validation limits.
tags: [testing, windows, streamline, provenance]
status: stable
generated: { by: codex, at: 2026-10-26T00:00:00Z }
sources:
  - id: report
    url: ../../devtools/acceptance/stabilization-20261026/REPORT.md
    title: Measured Windows RTX acceptance report
  - id: manifest
    url: ../../devtools/acceptance/stabilization-20261026/MANIFEST.json
    title: Public evidence and original-input hashes
---

The measured native revision is `c1fc0252a98913d3be394417b6977a8c5aa4d77d`
(C1). On Windows 10, MSVC 19.44 and RTX 4060 Laptop / driver 610.88,
all six standard/Mono editor/template builds passed in 527.406 seconds.
Both repository smoke suites, 43 source-generator tests, four installed-template
exports and runs, 17 frozen game captures, and two production game natural-exit
cases passed their recorded assertions. These are functional checks, without a
performance improvement or full gameplay claim.[^report]

The strict GPU matrix belongs to `d37b63e72b`, not C1. Its six D3D12 controls
and no-SDK Vulkan control are clean; six Streamline Vulkan controls still fail
with SDK/pacer layout, semaphore, synchronization or threading diagnostics.
C1 changes only the editor documentation-cache lifetime guard in native code;
it does not count as a repeat of those strict runs. This remains experimental,
not an RC.[^report]

Actual runtime indicator images, SDK requests, driver reports and physical
latency are distinct evidence. Foreground presented-two reports establish a
limited ordinary FG execution result, not generated-frame image quality or
physical input latency. Missing-plugin controls exit and render with fallback,
while retaining `eErrorNoPlugins`; they are not error-free passes.[^report]

The public evidence bundle contains redacted text and unchanged PNG bytes.
Its manifest records public-file and original-input hashes. Raw failures remain
separate from later successful reruns, and private SDK binaries and Hub startup
logs are excluded.[^manifest]

The scoped Git attributes disable newline conversion for this evidence bundle
and whitespace lint for captured logs. Verify the staged blob bytes against
the manifest as well as the working files: a working-tree-only hash audit can
miss automatic CRLF-to-LF conversion during staging. Preserve raw diagnostic
whitespace rather than trimming it to satisfy a source-code style check.
