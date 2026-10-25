---
type: Finding
title: Keep native objects and archives distinct for module build variants
description: Windows incremental standard/Mono builds selected a standard export template from a Mono editor.
tags: [windows, mono, scons, export, incremental-build]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# Actual failure

Both public TPZ archives contained their correct native binaries and
`version.txt`. Explicit .NET custom-template exports ran successfully. After
installing both archives, however, a Mono editor at `3e024c0a0` and again at
`e0c27964e` resolved `find_export_template()` to the standard `4.8.beta1`
directory rather than `4.8.beta1.mono`. Its exported game printed a standard
version and could not load the C# script. A successful export exit was not
a passing game test.

# Isolation change

The six-target workflow alternates standard and Mono builds in one checkout.
Executable suffixes include `env.module_version_string`, but the native object
and archive suffixes did not. They reused the same targets across variants
with different generated module/version headers. Dependency records for the
affected export object omitted its generated version header; rescanning alone
did not repair the existing binary. This is a mixed-variant artifact defect,
not evidence that the TPZ contents or exporter copied the wrong file.

Include the existing module version suffix in native object, static library
and shared library targets as already done for executables. Standard output
names and public editor/template names remain unchanged. A fresh Mono variant
can then be built without deleting either cache or relying on stale standard
objects. A cold Mono editor build passed, then all six targets at engine
`1381c32593` built in 2436.610 seconds. The real installed-template lookup
resolved `4.8.beta1.mono`; standard/Mono Debug/Release exports all ran.
Self-contained C# games passed typed/dictionary PhysX assertions without SDK
discovery. These are combined regression-build results, not a claim that an
unbuilt, newly composed review-branch head has an identical binary hash.
