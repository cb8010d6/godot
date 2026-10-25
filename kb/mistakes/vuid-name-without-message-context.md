---
type: Mistake
title: VUID names alone led to the wrong resource hypothesis
description: Read the complete validation message, actual resource and command region before implementing an adapter.
tags: [testing, vulkan, diagnosis]
status: stable
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The names oldLayout-01213 and copy-aspect-06663 were interpreted as native
depth cloning. An R32F depth adapter was built and tested but did not change
the failures. Full messages showed a COLOR_ATTACHMENT-only real swapchain
destination and an SL pacer/fake-swapchain layout mismatch, even during startup.

Preserve that negative run and remove only the ineffective experiment.
Classify by complete message, resource/usage and command region, not identifier
wording. A successful build or GPU run does not validate a root-cause hypothesis.
