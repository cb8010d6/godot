/**************************************************************************/
/*  test_streamline_dlss_presets.cpp                                       */
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

// Captures the real submission helper's typed callback arguments. No runtime
// DLL or GPU is used, and this does not identify the model a driver will load.
// c++ -std=c++17 -Wall -Wextra -Werror -I. devtools/test/test_streamline_dlss_presets.cpp -o /tmp/dlss_presets
// /tmp/dlss_presets
#ifndef STREAMLINE_ENABLED
#define STREAMLINE_ENABLED
#endif
#include "drivers/streamline/streamline_dlss_presets.h"

#include <array>
#include <cstdio>

static int failures = 0;
static int checks = 0;
static int calls = 0;
static uint32_t received_viewport = 0;
static sl::DLSSOptions received_options;
static sl::Result callback_result = sl::Result::eOk;

static void expect(bool p_condition, const char *p_message) {
	++checks;
	if (!p_condition) {
		++failures;
		std::fprintf(stderr, "FAIL: %s\n", p_message);
	}
}

static sl::Result capture_options(const sl::ViewportHandle &p_viewport, const sl::DLSSOptions &p_options) {
	++calls;
	received_viewport = static_cast<uint32_t>(p_viewport);
	received_options = p_options;
	return callback_result;
}

static std::array<sl::DLSSPreset, 6> presets(const sl::DLSSOptions &p_options) {
	return { p_options.dlaaPreset, p_options.qualityPreset, p_options.balancedPreset, p_options.performancePreset, p_options.ultraPerformancePreset, p_options.ultraQualityPreset };
}

static void expect_presets(const sl::DLSSOptions &p_options, const std::array<sl::DLSSPreset, 6> &p_expected) {
	expect(presets(p_options) == p_expected, "all SDK preset slots match the requested policy");
}

static std::array<sl::DLSSPreset, 6> uniform(sl::DLSSPreset p_preset) {
	return { p_preset, p_preset, p_preset, p_preset, p_preset, p_preset };
}

int main() {
	static_assert(static_cast<int>(sl::DLSSPreset::ePresetK) == 11);
	static_assert(static_cast<int>(sl::DLSSPreset::ePresetL) == 12);
	static_assert(static_cast<int>(sl::DLSSPreset::ePresetM) == 13);
	expect(!StreamlineDLSSPresets::is_explicit_preset(0x014d), "non-ASCII text is not truncated into preset M");
	const sl::ViewportHandle viewport(42);
	sl::DLSSOptions options;
	options.outputWidth = 2560;
	options.outputHeight = 1440;
	options.colorBuffersHDR = sl::Boolean::eFalse;
	options.preExposure = 2.0f;
	options.exposureScale = 0.75f;
	options.useAutoExposure = sl::Boolean::eTrue;
	options.alphaUpscalingEnabled = sl::Boolean::eTrue;
	options.indicatorInvertAxisX = sl::Boolean::eTrue;
	const std::array<sl::DLSSPreset, 6> recommended = {
		sl::DLSSPreset::ePresetK, sl::DLSSPreset::ePresetK, sl::DLSSPreset::ePresetK,
		sl::DLSSPreset::ePresetM, sl::DLSSPreset::ePresetL, sl::DLSSPreset::ePresetK
	};
	const sl::DLSSMode modes[] = { sl::DLSSMode::eDLAA, sl::DLSSMode::eMaxQuality, sl::DLSSMode::eBalanced, sl::DLSSMode::eMaxPerformance, sl::DLSSMode::eUltraPerformance };
	for (sl::DLSSMode mode : modes) {
		options.mode = mode;
		const int before = calls;
		expect(StreamlineDLSSPresets::submit_sr_options(capture_options, viewport, options, StreamlineDLSSPresets::RECOMMENDED) == sl::Result::eOk, "recommended request succeeds");
		expect(calls == before + 1 && received_viewport == 42, "exactly one SDK callback receives the original viewport");
		expect_presets(received_options, recommended);
		expect(received_options.mode == mode && received_options.outputWidth == 2560 && received_options.outputHeight == 1440, "mode and output size survive submission");
		expect(received_options.colorBuffersHDR == sl::Boolean::eFalse && received_options.preExposure == 2.0f && received_options.exposureScale == 0.75f && received_options.useAutoExposure == sl::Boolean::eTrue, "HDR and exposure settings survive submission");
		expect(received_options.alphaUpscalingEnabled == sl::Boolean::eTrue && received_options.indicatorInvertAxisX == sl::Boolean::eTrue, "other SR flags survive submission");
		expect(received_options.structVersion == sl::kStructVersion3, "SDK structure version survives submission");
	}

	// Fixed L/M can also be requested for high-input-resolution modes, rather
	// than being forced back to the recommended K by the current DLSS mode.
	options.mode = sl::DLSSMode::eDLAA;
	const struct {
		char letter;
		int sdk_value;
	} explicit_presets[] = { { 'M', 13 }, { 'L', 12 }, { 'K', 11 }, { 'F', 6 }, { 'G', 7 }, { 'H', 8 }, { 'I', 9 }, { 'J', 10 }, { 'N', 14 }, { 'O', 15 } };
	for (const auto &preset : explicit_presets) {
		expect(StreamlineDLSSPresets::submit_sr_options(capture_options, viewport, options, preset.letter) == sl::Result::eOk, "explicit request succeeds");
		expect_presets(received_options, uniform(static_cast<sl::DLSSPreset>(preset.sdk_value)));
		expect(received_options.mode == sl::DLSSMode::eDLAA, "explicit preset preserves the selected rendering mode");
	}
	expect(StreamlineDLSSPresets::submit_sr_options(capture_options, viewport, options, '?') == sl::Result::eOk, "switching back to runtime default succeeds");
	expect_presets(received_options, uniform(sl::DLSSPreset::eDefault));
	expect(StreamlineDLSSPresets::submit_sr_options(capture_options, viewport, options, StreamlineDLSSPresets::RECOMMENDED) == sl::Result::eOk, "recommended policy can be restored after an override");
	expect_presets(received_options, recommended);

	const int before_rejection = calls;
	const auto before_presets = presets(options);
	for (char invalid : { '\0', 'E', 'P', 'Z', 'm' }) {
		expect(StreamlineDLSSPresets::submit_sr_options(capture_options, viewport, options, invalid) == sl::Result::eErrorInvalidParameter, "invalid selection returns an error");
		expect(calls == before_rejection && presets(options) == before_presets, "invalid selection does not call the SDK or mutate options");
	}
	expect(StreamlineDLSSPresets::submit_sr_options(nullptr, viewport, options, '?') == sl::Result::eErrorMissingOrInvalidAPI, "missing runtime entry returns an error");
	expect(calls == before_rejection && presets(options) == before_presets, "missing entry does not mutate options");
	callback_result = sl::Result::eErrorFeatureNotSupported;
	expect(StreamlineDLSSPresets::submit_sr_options(capture_options, viewport, options, 'M') == callback_result, "SDK failure is returned without a silent preset fallback");
	expect(calls == before_rejection + 1, "failed SDK request is dispatched once");
	expect_presets(received_options, uniform(sl::DLSSPreset::ePresetM));
	if (failures) {
		std::fprintf(stderr, "FAIL: %d/%d checks\n", failures, checks);
		return 1;
	}
	std::printf("PASS: %d checks, %d captured SR submissions (no runtime or active-model verification)\n", checks, calls);
	return 0;
}
