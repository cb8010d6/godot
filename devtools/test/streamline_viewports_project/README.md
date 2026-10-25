# Frame Generation viewport policy regression

Run this actual rendered project with a built Windows editor or an installed
export template. It uses the real Streamline runtime; absence of ordinary FG
support fails unless `--expect-unavailable` is explicitly selected.

```powershell
& $engine --path devtools/test/streamline_viewports_project --rendering-driver vulkan -- --scenario=dynamic --expected-backend=vulkan --output=fg-dynamic.json
```

Scenarios: `single`, `hud`, `main_plus_sub`, `one_sub`, `two_sub`, `four_sub`,
`dynamic`, `resize`. Repeat on D3D12 and with genuinely absent runtime DLLs.
The output parent directory must exist. `dynamic` checks single main view,
creation of a second view and return after its destruction. Offscreen-only
and multiple-3D-view arrangements must keep rendering and explain fallback;
2D HUD viewports must not disable the main view's eligible FG request.

The JSON includes the binary version, actual backend, GPU and repeated atomic
policy/SDK-option snapshots. `sdk_enabled` is the last successful application
SDK enable state. This test does **not** prove actual generated frames, image
quality or physical input latency. Use independent SDK frame-state/presentation
capture for that acceptance, and retain strict validation diagnostics even
when this policy test exits zero. No MFG capability is asserted.

The standalone `../streamline_fg_policy.cpp` provides twelve CPU-only boundary
checks. It has no proprietary SDK dependency; for example compile from the
repository root in an MSVC developer shell with `/std:c++17 /W4 /WX /I.`.
