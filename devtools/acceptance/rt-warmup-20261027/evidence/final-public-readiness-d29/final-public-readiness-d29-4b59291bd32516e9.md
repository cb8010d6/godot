# Final public readiness regression: D29

The existing native receipts and exported PCK passed a separate CPU audit. The runtime reported `d29e7065306d670a643ca0ea7a362c4b38cea3c5`, Vulkan, and NVIDIA GeForce RTX 4060 Laptop GPU. The native execution was performed by the main test queue; this audit started no native process.

| Stage | Actual exit | Receipt duration |
| --- | --- | --- |
| Headless import | 0 | 6.250 s |
| Headless export-pack | 0 | 5.265 s |
| Production release EXE, same-basename PCK | 0 | 5.281 s |

Original receipts/logs: `../../stabilization-20261026/public-readiness-d29e706530-{import,export,run}.json` and the corresponding `logs/` files. `PREPARED.json` remains a historical preparation record, not an execution result.

`pck-entry-proof.json` verifies all PCK payload MD5s, exact script bytes, registered custom MainLoop, project.binary startup values, the exported bootstrap scene/remap, and the unchanged release executable. `source-commit-provenance.json` independently compares all four project inputs with the exact committed D29 blobs and snapshot bytes.

The original `capture-20261026T191340Z-91f259e7/summary.json` reports PASS for all five phases. The first four phases pass their actual green/blue pixel assertions, including changed source and changed variant. Fresh recorded-command serials, effective TLAS, and live readiness are checked. The fifth phase deliberately injects an invalid RT identifier and detects `failed=1`; the intentional compiler error is retained. `pending_observed=true` is an actual observation, without claiming independently cold driver caches. The fixture's internal elapsed time is 1017 ms; the external receipt duration above includes process lifecycle.

Four original PNG files are retained and byte-hashed in the proof. The release EXE is 80,790,016 bytes, SHA256 `affa480e5a19f3e39b644035ac9c1938471ec7017a7f50db12f30e4257c26c53`; the PCK is 10,444 bytes, SHA256 `c17ac07442c3546fc8a66be6b0fc25d22fd6314793ed4e7d0a9e10e5b226e919`.

This validates the production release readiness counters and fixture execution. It does not validate GPU completion fences, presentation, strict GPU validation, DLSS model identity, RR, FG, or latency. Earlier v1 failures remain separate historical evidence.
