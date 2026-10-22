DLSS camera constants source-extraction regression harness

Baseline: NVIDIA-RTX/godot nvidia-pt-dlss, 135dff3887a3d2ccf45cafbd9bdffa7b718e1e76
FOV commit: cb8010d6/godot 2ccecd2d10d2304e442dc8fb94a6878cd61d08be
Basis commit: cb8010d6/godot 0b50d914deb01928f4985b555e4765f8fa16b43b

Requires Python 3 and a C++17 compiler (tested g++ on Linux). Place
check_dlss_constants.py and check_dlss_constants.cpp.in in the same directory.
No network, SDK DLLs, GPU, generated engine headers or full engine build needed.

Run independently for either patch:
  python3 check_dlss_constants.py /path/to/godot --check-fov
  python3 check_dlss_constants.py /path/to/godot --check-basis
Add --precision double to compile with Godot's REAL_T_IS_DOUBLE.
Set CXX to select a different C++ compiler.

What is executed:
- Real Godot math headers, projection.cpp and basis.cpp from the selected checkout.
- Real bundled sl::Constants and PFun_slSetConstants types.
- Verbatim extracted DLSS renderer get_fov/get_aspect/get_fovy statements and
  params.fovy assignment, conversion helpers, and full slSetConstants block.
- A mock SDK function captures the complete Constants argument at the original
  slSetConstants call expression. The mock is installed via the real SDK function
  pointer type; the surrounding renderer and StreamlineContext are minimal stubs.
- Unexpected production math errors throw; the normal constants block's SDK
  success path runs. No other production math/constant statements are rewritten.

Checks:
- FOV: square, 16:9, 21:9, 9:16 under KEEP_WIDTH horizontal 90 and KEEP_HEIGHT
  vertical 90. Captured cameraFOV is checked in radians against independent
  trigonometry and against 2*atan(1 / projection[1][1]). cameraAspectRatio must
  remain width/height. Baseline: 6/8 fail. FOV patch: 8/8 pass, both precisions.
- Basis: identity, positive 90-degree yaw/pitch/roll, arbitrary axis rotation
  with translation. Captured world directions are checked against an independent
  Rodrigues transform of local canonical vectors, plus unit length, orthogonality,
  handedness and camera position. Baseline: 4/5 fail. Basis patch: 5/5 pass,
  both precisions.

Logs are in the eight *-baseline/fixed-single/double.txt files. Nonzero baseline
exit codes are expected regression failures; patched commands return zero.

Limits:
This is an isolated CPU source-extraction test with a mock SDK call. It is not
an execution of Godot's renderer or a call into NVIDIA's Streamline runtime.
The Linux environment has no RTX device, and the project disables Streamline
on non-Windows platforms (SConstruct). No full Windows/Vulkan/D3D12 build,
DLSS mode evaluation, GPU rendering, image-quality, ghosting or performance
validation was performed. Those remain runtime follow-up work.

Published fix blobs match the tested local commits byte for byte.
The logs retain the local checkout paths used for execution.
