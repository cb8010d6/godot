# Tooling

* [D3D12 native callback state](/tooling/d3d12-native-callback-state.md) - prepare legacy texture states and invalidate external bindings

* [D3D12 paired runtime layout](/tooling/d3d12-paired-runtime-layout.md) - isolate factory and legacy debug DLL lookup

* [Frame Generation viewport policy](/tooling/streamline-fg-viewport-policy.md) - deterministic fallback and queryable cached SDK state

* [Rejected Vulkan depth hypothesis](/tooling/streamline-vulkan-depth-handoff.md) - full pacer/swapchain messages contradicted the depth interpretation
* [Streamline swapchain transfer usage](/tooling/streamline-swapchain-transfer-usage.md) - real swapchain copy usage versus separate fake-layout/FG hazards

* [Streamline Vulkan device requirements](/tooling/streamline-vulkan-device-requirements.md) - supported privateData/presentId and explicit dependency provisioning

* [Vulkan Win32 window instance](/tooling/vulkan-window-instance.md) - recover HWND module ownership when the Unicode entry point supplies no instance

* [Separate NIS shader format and resource lifetime](/tooling/nis-separated-resources.md) - graph/format candidate and strict-validation acceptance boundary

* [DLSS 4.5 Super Resolution policy](/tooling/dlss-4.5-super-resolution.md) - request K/M/L by mode and verify active models separately

* [PT storage-image formats](/tooling/pt-storage-image-formats.md) - match output and RR normal/roughness declarations with real allocations

* [Abandoned RT pipeline cleanup](/tooling/pt-abandoned-pipeline-cleanup.md) - release the dependent pipeline before its owned shaders

* [DLSS output dependency](/tooling/dlss-output-dependency.md) - local GPU reproduction and independent render-graph correction under test

* [Vulkan 1.2 feature-chain exclusivity](/tooling/vulkan-12-feature-chain.md) - use either the aggregate or individual promoted feature structs during device creation

* [Streamline SDK upgrade validation](/tooling/streamline-sdk-validation.md) - release provenance, shared manifests, API compilation and runtime boundaries

* [Windows package version](/tooling/windows-package-version.md) - preserve the built beta1 status in release metadata and test installed templates

* [Windows Mono artifact isolation](/tooling/windows-mono-artifact-isolation.md) - keep module variants distinct and test installed templates, not only custom paths

* [DDGI test protocol](/tooling/ddgi-test-protocol.md) - converged comparisons, step response, motion error, flicker spread, cost, a real game level, A/B builds
* [Vulkan synchronization validation without the SDK](/tooling/vulkan-sync-validation.md) - load an existing Khronos layer DLL through a scratch manifest
* [Reading PDFs for research](/tooling/pdf-text-extraction.md) - extract text with pypdf when page rendering isn't available
