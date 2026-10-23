# Visual review

Reviewed on 2026-10-23 after the final numerical/SDK checks passed.

- Inspected the mode comparison: base/combined at the rotated-camera case across
  DLAA, SR, RR, and SR+FG. Geometry and edge detail render; RR shadows are visible.
- Inspected square, landscape, ultrawide, and portrait RR captures for both base
  and combined builds. Images preserve aspect ratio and contain rendered content.
- Inspected the RR motion comparison at frames 15 through 105. Frame 0 still
  shows the preceding settled pose because of render-queue latency; originals
  are preserved and that transition frame is excluded from the sheet.
- All 336 original PNGs passed nonblank and dimension checks. Per-file hashes,
  dimensions, entropy, and channel standard deviations are saved in
  `logs/image-inventory.json`.

This was a visual spot check of comparison sheets plus automated integrity
checks of all originals. It does not establish that temporal artifacts are
absent, demonstrate better image quality, or measure performance. FG intermediate
frames are not included in viewport PNGs; SDK presentation counters establish
the observed extra-frame activity.
