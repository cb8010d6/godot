---
type: Finding
title: Path-traced custom materials need real MultiMesh shader inputs
description: Missing instance built-ins and a shared displacement cache broke custom materials in an actual Vulkan game.
tags: [pathtracing, shaders, multimesh, regression]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

# Reproduction and cause

An actual Windows Vulkan game on RTX 4060 / driver 610.88 at native revision
`c1fc0252a9` saved failed closest-hit GLSL for crowd and foliage materials.
The crowd vertex code referenced `instance_custom`; foliage referenced
`rt_instance_id`. The PT compiler renamed the valid spatial shader built-ins
but its shared hit-stage globals did not declare or populate either value.
Replaying the exact dumps confirmed both undeclared-identifier failures.
This path already existed before the 4.8 beta 1 integration.

Compiling a declaration with a constant zero would not restore the shader's
meaning. MultiMesh shaders use their logical instance index, custom RGBA and
instance color. The merged-BLAS optimization also bakes instance transforms
into positions, losing the mesh-local `VERTEX` used by custom vertex code.

# Scoped correction

The internal geometry layout now carries logical instance ID, custom RGBA and
color. Host size and field-offset assertions match the GLSL std430 layout.
Custom shaders that read these inputs or run vertex code use the existing
expanded-TLAS path, preserving each logical instance's transform. Its values
come from the current MultiMesh data, using the same optional color/custom
offsets as raster rendering. Ordinary mesh inputs retain their actual defaults.

Custom vertex displacement uses a separate deformed-pool handle for each
MultiMesh surface and logical instance. Both compute displacement and hit-stage
vertex replay receive the same real inputs. Shrinking the visible instance
count releases unused tail slots; RID recycling and mesh changes release old
slots. Unused entries still have the existing TTL and shutdown cleanup.
The merged compute list ends before per-instance displacement starts, avoiding
nested compute lists. This trades merged-BLAS performance for correct material
semantics on affected custom shaders; no performance improvement is claimed.

Failed closest-hit, any-hit and intersection compiles now report their actual
compiler error as well as preserving the generated source dump.

# Regression boundary

Rebuild and rendered regression are required: use multiple instances of one
mesh with distinct nonzero ID/custom/color inputs, a custom-alpha-dependent
vertex displacement, count shrink/grow, mesh/material replacement and exit.
Compare a normal MeshInstance default-input control. A successful compile alone
does not prove the instance shader data or deformed geometry are correct.

This correction does not implement screen-space derivatives in hit shaders.
The same game also exposed `fwidth`/`dFdx`/`dFdy` in opaque custom materials;
those require a separately validated RT material path. Vertex texture sampling
and camera-dependent deformation keep their pre-existing limitations. Do not
silently replace unsupported inputs or derivatives with zero and call it fixed.
