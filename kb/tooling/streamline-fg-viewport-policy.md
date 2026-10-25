---
type: Finding
title: Guard global Frame Generation ownership before drawing viewports
description: Explain unsupported viewport arrangements without per-viewport SDK toggling.
tags: [streamline, frame-generation, viewport, validation]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The integration has one global SDK FG owner. Letting several 3D contexts
request it can move ownership back and forth every draw. Before drawing,
count visible 3D views and requests, allowing exactly one non-XR 3D view
rendered directly into a window. Multiview and offscreen/multiple-view
arrangements retain their requested properties but fall back with a warning
on reason transitions. Pure 2D HUD viewports do not count.

Disable an existing SDK owner once when eligibility is lost and on its
context destruction. Do not repeatedly reset the existing enable delay for
every offscreen context. Publish one atomic read-only status snapshot for
scripts; cached successful SDK options are distinct from actual presentation.
This integration advertises at most one generated frame (ordinary 2X).

`devtools/test/streamline_viewports_project` exercises live creation/destruction,
one/two/four offscreen views, a 2D HUD and resize. A CPU-only policy boundary
test complements it. Implementation is pending compilation and real GPU
policy regression; it does not fix or excuse existing SDK sync diagnostics.
