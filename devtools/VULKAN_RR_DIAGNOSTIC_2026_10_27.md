# Vulkan Streamline RR follow-up — 2026-10-27

**The remaining automatic/F RR synchronization errors are not repaired.** Two
small diagnostic editors compile and four actual RTX runs retain strict errors.
The tested production/playable candidate remains `d29e706530`; none of this
instrumentation is merged into its native source.

Environment and full Windows acceptance are in the
[warm-up report](RT_WARMUP_ACCEPTANCE_2026_10_27.md). This round uses the same
RTX4060 Laptop / driver610.88, Streamline2.14.16 / NGX RR310.9.16 and explicit
VVL1.4.366, with fresh profiles, NIS0 and the FG plugin omitted at startup.
GPU tests run serially. Both editor builds use
`devtools/build/build.ps1 -Jobs 2 -VersionStatus beta1`.

| Native diagnostic | Build | Controlled difference | Observed result |
| --- | --- | --- | --- |
| `74abe06d76d4c181ffcb5826bbe72dc8e6c211a4` | PASS, 103.406s | No preallocation | Valid control, strict FAIL: WAW2 inside first Evaluate, original 09600x2 at submission |
| Same binary | Same build | Explicit allocation before first Evaluate | INVALID control: first two calls return invalid parameter, later succeeds; actual Evaluate still WAW2/09600x2, strict FAIL |
| `6467f55a260ba6ff48668d38ce7d414453d59507` | PASS, 38.656s | Legacy global tags | Valid control, strict FAIL: WAW2/09600x2 |
| Same binary | Same build | Eight identical resource tags as local Evaluate inputs | Valid control, same strict FAIL; preallocation disabled in both tag cases |

Both tag cases also query RR's actual F/Quality contract read-only. Output is
960x540; input640x360 equals the returned optimum and lies inside min480x270 /
max960x540. Query result0, mode3, requested preset6 are recorded. This narrows
the global tag-cache and invalid/non-optimal-size explanations for this case.
It does not certify every host contract or expose proprietary NGX implementation.

Every run retains actual non-Off/eOk RR, eight tag types, 160 SDK samples and
49 frame records/captures. Native exit0 and successful calls do not override
strict failures. WAW is observed inside Evaluate; submit-time layout errors
report the NGX region and its first expected oldLayout. The outer Draw label
alone is not evidence of a missing Godot draw barrier.

No blanket host barrier, SDK binary patch, validation filter, forced driver
override, unsafe feature free or model/preset default change was added. The
published SDK already forces initial history reset. The separate open
[upstream report126](https://github.com/NVIDIA-RTX/Streamline/issues/126) describes
a similar first-evaluation WAW with direct NGX; it is supporting context, not
proof that all our messages have the same cause. The queried latest official
release is still [2.14.16](https://github.com/NVIDIA-RTX/Streamline/releases/tag/v2.14.16).

The optional **RR-D + startup FG omission + NIS0** compatibility result remains
the separately measured single/four-player option. FG is unavailable there.
Automatic/F stays the unchanged default and remains outside strict sign-off.
Model weights, quality parity, generated-frame/latency measurement and long
stress are not newly accepted by this round.

The owned Job handles were closed. Immediate per-run NGX censuses still list
terminating children (17/16 and17/17), so those receipts do not prove immediate
zero. Next-run before-lists and a later independent CIM census are empty;
no test Godot/NGX/compiler processes remain in that later observation.

[Supplement and source patch](acceptance/rr-followup-20261027/README.md) contain
sanitized complete logs, exact byte hashes, request/call observations and the
local diagnostic source delta. Original failed records and the earlier evidence
snapshot are retained. Codex assisted the code, diagnosis and reports; all GPU
observations came from actual local execution. Existing dependency licenses
apply; no SDK/runtime binary or private game content is distributed.
