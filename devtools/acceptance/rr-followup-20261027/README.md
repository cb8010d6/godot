# Vulkan RR first-use diagnostics — 2026-10-27

This supplement records four actual Windows/RTX runs. **All four fail strict
validation.** The preallocation-enabled arm is additionally an invalid control
because its first two allocation calls fail. No production synchronization fix
is claimed. Final production native remains `d29e706530`.

`summary.json` preserves exact native identities, original log/matrix SHA-256,
RR call/tag proof, SDK/frame counts, markers and immediate child-process lists.
The four logs contain every diagnostic; only local path prefixes and UTF-8/BOM
serialization are changed. Original bytes remain in the private run archive.
No DLL, SDK header, model, private game asset or generated image is included.

## Findings

* Baseline `74abe06d76`: two WAW inside first RR Evaluate, two original 09600
  messages at submission. Preallocation initially returns invalid parameter at
  frames 4/5; frame 6 succeeds and actual evaluation retains the same errors.
  That arm is INVALID, not a successful once-before-first-evaluation experiment.
* Matched `6467f55a26` pair: legacy global tags versus the same eight tags as
  local Evaluate inputs. Both diagnostic contracts are valid and strict FAIL.
  Preallocation is explicitly disabled in both. Neither error class changes.
* Both RR F/Quality queries return success: input 640x360 exactly equals optimal
  640x360, inside min 480x270 / max 960x540, output 960x540. These calls exclude
  an out-of-range or non-optimal extent as their explanation.
* Job close is issued for contained children. Immediate censuses still list
  terminating NGX children (17/16 and 17/17); they are **not** immediate-zero
  proof. Every next-run before-list and the separate later CIM census are empty.

Each run retains real non-Off/eOk RR, eight tag types, 160 SDK samples, 49 frame
records/captures, module/layer isolation and native exit0. None overrides strict
failure or proves model weights, visual parity, long stability or FG rendering.

## Reproduce the source discriminator

`diagnostic.patch` applies to engine source
`ce8ae17454f2c4ce43223d3a416a47492b182b1c`. It is **test instrumentation** kept
outside production source. The two local diagnostic commits are identified by
SHA in the summary; the combined patch provides their native source changes.
Build the standard editor with the repository script and Jobs2. Obtain required
SDK/runtime dependencies under their normal licenses.

Use the [existing public primitive fixture](../rt-warmup-20261027/reproducer/README.md)
and its matching probe/validation setup. Keep fresh isolated profiles, SDK214,
RR F, NIS0 and startup FG omission fixed. Its fixture request arguments are
`--mode=rr --preset=Recommended --rr-preset=F --sharpness=0 --suite=motion --warmup=100`.
Run two processes with `GODOT_RR_DIAG_PREALLOCATE=0`, changing only
`GODOT_RR_DIAG_LOCAL_TAGS=0` versus `1`. Keep strict validation enabled; preserve
every error. Inspect the first `RRDIAG_BOUNDS`, `RRDIAG_LOCAL_TAGS` and Evaluate
brackets. The markers log host requests/call results, not neural-weight readback.

The earlier preallocation experiment used the preceding diagnostic revision;
its combined patch's query/local-tag additions are absent from that first build.
Do not relabel the two native builds as identical. The opt-in preallocation
branch remains deliberately unsuitable for production: failed attempts do not
certify successful resource creation.
