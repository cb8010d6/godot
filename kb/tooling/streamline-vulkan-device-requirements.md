---
type: Finding
title: Provision supported Vulkan features required by Streamline runtime paths
description: Candidate enables privateData and the low-latency present-id dependency without duplicating promoted feature chains.
tags: [streamline, vulkan, features, validation]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
sources:
  - id: sl-chi214
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/platforms/sl.chi/vulkan.cpp
---

SL2.14 baseline reports privateData-04564 and device-extension dependency
01387 even when NIS and FG are off. The SDK checks whether the private-data
function pointer exists before creating a slot, but that alone does not
establish that the feature was enabled.[^sl-chi214] The injected low-latency
extension also requires present-id support in the device extension list.

The candidate queries privateData and presentId only for an active SL loader,
requests their optional extension dependencies, and enables supported feature
structures when creating the device. PrivateData is core in 1.3; the existing
1.2 aggregate/individual feature-chain correction is preserved. Missing DLLs
leave the added features disabled. Vulkan 1.4 and older-runtime limitations
must be recorded separately after actual GPU validation.
