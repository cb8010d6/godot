---
type: Finding
title: Factorized inverse for DLSS SR reprojection
description: A real split-screen results transition exposed precision loss when inverting a combined float reprojection matrix.
tags: [streamline, dlss, reprojection, numerical-precision]
status: active
generated: { by: codex, at: 2026-10-27T00:00:00Z }
---

# Observed failure

On Windows with an RTX 4060 Laptop GPU and Streamline 2.14.16, a raster
four-player skating round using the d29 native editor and DLSS Quality emitted
`Projection::invert`'s last-pivot error during the results transition. A shorter
forced-results diagnostic reproduced the same error three times with d29;
matched single runs with the official engine and FSR2, and d29 with native or
FSR2, did not emit it. Forced results are a diagnostic, not gameplay acceptance.

A separately identified diagnostic native build reproduced the error both with
and without its opt-in trace. An error-handler probe tied one occurrence to the
SR `prevClipToClip` inverse. The recorded 16 binary32 values describe a matrix
whose exact-input determinant is about 0.42927, but whose infinity-norm condition
number is about 1.22e8. The float determinant calculation yielded 2.0 and the
float elimination reached a zero pivot. This is a concrete precision failure for
one observed matrix, not evidence that every other inverse failure has that cause.

# Implemented change and boundary

For SR, form the inverse mapping from the original camera factors in reverse
order, rather than inverting their already-combined float product. Forward
reprojection and motion-vector decoding remain unchanged. The existing RR inverse
path remains in use when RR is actually available; an unavailable RR request
follows SR's factorized path. The change does not add a history reset, guard a
singular camera projection, or change feature selection.

An independent Decimal geometric oracle and a binary32 product model covered
stationary and moving perspective cameras, a large perspective camera jump, and
an orthographic jump. The model computes factor inverses in Decimal then rounds
them to binary32, so it does not exercise Godot's native inverse implementation.

Native `b3763e7c7ef8e621e2e19018589e5a022aba1f82` has since rebuilt the standard
editor and debug/release templates. The target error was absent in three forced
results trials and the original four-player natural match. Ten complete bot
matches pass across official 4.7.2 FSR2, b376 DLSS, and native controls; two short
actual-game strict SR checks and an installed-template production export also
pass. See the [measured acceptance report](../../devtools/RASTER_DLSS_ACCEPTANCE_2026_10_27.md)
for exact scope, timings, hashes and retained failures. These results support
the measured raster SR configuration; human input, normal temporal image quality
and history discontinuities still need separate acceptance. This change alone
does not establish correct temporal history or certify the unchanged RR path.
