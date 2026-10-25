#!/usr/bin/env python3
"""Regression tests for the fork's RT stages in compressed shader headers.

Run with python devtools/test/test_raytracing_builders.py. No compiler or GPU is
needed. These check the generator/encoding boundary, not GLSL validity or GPU
pipeline creation. Upstream's builder fixture suite covers raster/compute.
"""

from __future__ import annotations

import re
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))
from glsl_builders import build_rd_header  # noqa: E402 -- import the checkout's build helper.


class RaytracingBuilderTests(unittest.TestCase):
    def generate(self, stages: dict[str, str]) -> tuple[bytes, list[bytes | None]]:
        output = REPO_ROOT / "devtools/out/shader-builders"
        output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="stages-", dir=output) as temp:
            shader = Path(temp) / "stages.glsl"
            target = shader.with_suffix(".out")
            shader.write_text("".join(f"#[{name}]\n{source}\n" for name, source in stages.items()), encoding="utf-8")
            build_rd_header(str(target), str(shader))
            header = target.read_text(encoding="utf-8")
        array = re.search(r"_code_compressed\[\] = \{([^}]+)\}", header, re.DOTALL)
        self.assertIsNotNone(array, "shader stages must be embedded as compressed bytes")
        compressed = bytes(int(number) for number in re.findall(r"\d+", array.group(1)))
        decoded = zlib.decompress(compressed)
        sizes = re.search(r"_decompress_code\(_code_compressed, (\d+), (\d+)\)", header)
        self.assertIsNotNone(sizes)
        self.assertEqual(int(sizes.group(1)), len(compressed))
        self.assertEqual(int(sizes.group(2)), len(decoded))
        call = re.search(r'setup_raytracing\((.*), "StagesShaderRD"\);', header)
        self.assertIsNotNone(call, "RT stages must not be routed to raster/compute setup")
        arguments = call.group(1).split(", ")
        self.assertEqual(len(arguments), 5)
        stage_text = []
        for argument in arguments:
            if argument == "nullptr":
                stage_text.append(None)
            else:
                offset = re.fullmatch(r"_code.get_data\(\) \+ (\d+)", argument)
                self.assertIsNotNone(offset)
                start = int(offset.group(1))
                self.assertLess(start, len(decoded))
                end = decoded.index(b"\0", start)
                stage_text.append(decoded[start:end])
        return decoded, stage_text

    def test_all_five_stages_keep_their_source_and_order(self):
        # Distinct material/placeholder text catches a swapped stage or bad byte offset.
        sources = {
            "raygen": "#version 460\n#GLOBALS\nvoid main() { traceRayEXT(); }",
            "any_hit": "#version 460\n#CODE : ALPHA\nvoid main() { ignoreIntersectionEXT; }",
            "closest_hit": "#version 460\n#MATERIAL_UNIFORMS\n#CODE : FRAGMENT",
            "miss": '#version 460\n#define SKY_NAME "sky"\nvoid main() {}',
            "intersection": "#version 460\nvoid main() { reportIntersectionEXT(1.0, 0); }",
        }
        decoded, stages = self.generate(sources)
        self.assertEqual(stages, [(source + "\n").encode() for source in sources.values()])
        self.assertEqual(decoded.count(b"\0"), 5)

    def test_raygen_only_leaves_other_stages_null(self):
        source = "#version 460\nvoid main() {}"
        _, stages = self.generate({"raygen": source})
        self.assertEqual(stages, [(source + "\n").encode(), None, None, None, None])

    def test_hit_group_without_raygen_preserves_sparse_offsets(self):
        sources = {"closest_hit": "#version 460\n#CODE : FRAGMENT", "any_hit": "#version 460\n#CODE : ALPHA"}
        _, stages = self.generate(sources)
        self.assertEqual(
            stages, [None, (sources["any_hit"] + "\n").encode(), (sources["closest_hit"] + "\n").encode(), None, None]
        )


if __name__ == "__main__":
    unittest.main()
