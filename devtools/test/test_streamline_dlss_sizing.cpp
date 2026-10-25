/**************************************************************************/
/*  test_streamline_dlss_sizing.cpp                                        */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

// Standalone CPU policy checks. No SDK import, runtime DLL, or GPU execution.
// c++ -std=c++17 -Wall -Wextra -Werror -I. devtools/test/test_streamline_dlss_sizing.cpp -o <scratch>/dlss_sizing
#include "drivers/streamline/streamline_dlss_sizing.h"

#include <cstdio>
#include <limits>

using namespace StreamlineDLSSSizing;

static int checks = 0;
static int failures = 0;

static void expect_size(RenderSize p_actual, RenderSize p_expected, const char *p_message) {
	++checks;
	if (p_actual.width != p_expected.width || p_actual.height != p_expected.height) {
		++failures;
		std::fprintf(stderr, "FAIL: %s (got %u x %u, expected %u x %u)\n", p_message, p_actual.width, p_actual.height, p_expected.width, p_expected.height);
	}
}

template <size_t N>
static RenderSize reconcile(RenderSize p_desired, const ModeBounds (&p_bounds)[N]) {
	return reconcile_render_size(p_desired, p_bounds, N);
}

int main() {
	// Captured real SDK 2.14.16 / NGX 310.9.16 bounds at 2560 x 1440.
	// The policy test consumes data; it does not simulate a successful SDK call.
	const ModeBounds measured[] = {
		{ { 2534, 1426 }, { 2560, 1440 }, { 2560, 1440 }, true },
		{ { 1280, 720 }, { 2560, 1440 }, { 1707, 960 }, true },
		{ { 1280, 720 }, { 2560, 1440 }, { 1485, 835 }, true },
		{ { 1280, 720 }, { 2560, 1440 }, { 1280, 720 }, true },
		{ { 853, 480 }, { 853, 480 }, { 853, 480 }, true },
	};
	expect_size(reconcile({ 854, 480 }, measured), { 853, 480 }, "fullscreen Ultra ceil width is reconciled to the actual SDK limit");
	expect_size(reconcile({ 853, 480 }, measured), { 853, 480 }, "already legal Ultra size is unchanged");
	expect_size(reconcile({ 1707, 960 }, measured), { 1707, 960 }, "Quality size is unchanged");
	expect_size(reconcile({ 1485, 836 }, measured), { 1485, 836 }, "valid Balanced ceil size is not snapped to its optimal size");
	expect_size(reconcile({ 1280, 720 }, measured), { 1280, 720 }, "Performance size is unchanged");
	expect_size(reconcile({ 2560, 1440 }, measured), { 2560, 1440 }, "DLAA size is unchanged");
	expect_size(reconcile({ 960, 540 }, measured), { 960, 540 }, "a large unsupported scale gap is not silently assigned a mode");
	expect_size(reconcile({ 768, 432 }, measured), { 768, 432 }, "a far smaller unsupported scale is left for the normal error path");

	const ModeBounds fixed[] = { { { 853, 480 }, { 853, 480 }, { 853, 480 }, true } };
	expect_size(reconcile({ 854, 481 }, fixed), { 853, 480 }, "one-pixel rounding on both axes is permitted");
	expect_size(reconcile({ 852, 479 }, fixed), { 853, 480 }, "one-pixel rounding below both minima is permitted");
	expect_size(reconcile({ 853, 481 }, fixed), { 853, 480 }, "height alone may need reconciliation");
	expect_size(reconcile({ 852, 480 }, fixed), { 853, 480 }, "width alone may need reconciliation");
	expect_size(reconcile({ 855, 480 }, fixed), { 855, 480 }, "width differences greater than one are rejected");
	expect_size(reconcile({ 853, 482 }, fixed), { 853, 482 }, "height differences greater than one are rejected");
	expect_size(reconcile({ 851, 479 }, fixed), { 851, 479 }, "a one-pixel height difference cannot excuse a two-pixel width difference");
	expect_size(reconcile({ 0, 480 }, fixed), { 0, 480 }, "invalid zero-width requests remain unchanged");
	expect_size(reconcile({ 853, 0 }, fixed), { 853, 0 }, "invalid zero-height requests remain unchanged");

	const ModeBounds portrait[] = { { { 480, 853 }, { 480, 853 }, { 480, 853 }, true } };
	expect_size(reconcile({ 480, 854 }, portrait), { 480, 853 }, "portrait height is checked independently of width");
	expect_size(reconcile({ 481, 854 }, portrait), { 480, 853 }, "portrait rounding can reconcile both axes");
	expect_size(reconcile({ 482, 853 }, portrait), { 482, 853 }, "portrait width still enforces the one-pixel limit");

	const ModeBounds cross_mode[] = {
		fixed[0],
		{ { 800, 450 }, { 900, 600 }, { 850, 500 }, true },
	};
	expect_size(reconcile({ 854, 480 }, cross_mode), { 854, 480 }, "a valid later mode wins over an earlier one-pixel candidate");
	const ModeBounds nearer[] = {
		{ { 853, 479 }, { 853, 479 }, { 853, 479 }, true },
		fixed[0],
	};
	expect_size(reconcile({ 854, 480 }, nearer), { 853, 480 }, "a closer legal input wins over a two-axis adjustment");

	expect_size(reconcile_render_size({ 854, 480 }, nullptr, 0), { 854, 480 }, "no SDK bounds preserves the original fallback");
	expect_size(reconcile_render_size({ 854, 480 }, measured, 0), { 854, 480 }, "an empty SDK result set preserves the original fallback");
	const ModeBounds invalid[] = {
		{ { 853, 480 }, { 853, 480 }, { 853, 480 }, false }, // SDK failure with populated output.
		{ { 854, 480 }, { 853, 480 }, { 853, 480 }, true }, // Width minimum exceeds maximum.
		{ { 853, 481 }, { 853, 480 }, { 853, 480 }, true }, // Height minimum exceeds maximum.
		{ { 0, 480 }, { 853, 480 }, { 853, 480 }, true },
		{ { 853, 0 }, { 853, 480 }, { 853, 480 }, true },
		{ { 853, 480 }, { 853, 480 }, { 854, 480 }, true }, // Optimal outside width range.
		{ { 853, 480 }, { 853, 480 }, { 853, 479 }, true }, // Optimal outside height range.
		{},
	};
	for (const ModeBounds &bounds : invalid) {
		expect_size(reconcile_render_size({ 854, 480 }, &bounds, 1), { 854, 480 }, "failed or malformed SDK bounds cannot justify an adjustment");
	}
	const ModeBounds failed_then_valid[] = { invalid[0], fixed[0] };
	expect_size(reconcile({ 854, 480 }, failed_then_valid), { 853, 480 }, "failed query does not suppress a separate valid mode");

	const uint32_t maximum = std::numeric_limits<uint32_t>::max();
	const ModeBounds large[] = { { { maximum, 480 }, { maximum, 480 }, { maximum, 480 }, true } };
	expect_size(reconcile({ maximum - 1, 480 }, large), { maximum, 480 }, "unsigned boundary differences do not overflow");
	expect_size(reconcile({ 1, 480 }, large), { 1, 480 }, "large unsigned distances cannot wrap into the one-pixel allowance");

	if (failures) {
		std::fprintf(stderr, "FAIL: %d/%d CPU sizing checks\n", failures, checks);
		return 1;
	}
	std::printf("PASS: %d CPU sizing checks (no SDK runtime or GPU execution)\n", checks);
	return 0;
}
