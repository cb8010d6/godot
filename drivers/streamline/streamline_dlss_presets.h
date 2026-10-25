/**************************************************************************/
/*  streamline_dlss_presets.h                                              */
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

#pragma once

#include "drivers/streamline/streamline_headers.h"

#ifdef STREAMLINE_ENABLED
namespace StreamlineDLSSPresets {

// Internal token for the public "Recommended" string, not a model preset R.
inline constexpr char RECOMMENDED = 'R';

inline bool is_explicit_preset(uint32_t p_preset) {
	return p_preset >= 'F' && p_preset <= 'O';
}

// Keep policy selection at the SDK submission boundary. This only requests
// presets; driver overrides and the installed runtime determine the active model.
inline sl::Result submit_sr_options(PFun_slDLSSSetOptions *p_set_options, const sl::ViewportHandle &p_viewport, sl::DLSSOptions &r_options, char p_preset) {
	if (p_preset != '?' && p_preset != RECOMMENDED && !is_explicit_preset(p_preset)) {
		return sl::Result::eErrorInvalidParameter;
	}
	if (p_set_options == nullptr) {
		return sl::Result::eErrorMissingOrInvalidAPI;
	}

	if (p_preset == RECOMMENDED) {
		// Streamline 2.14.16 ProgrammingGuideDLSS, section 5. L and M are
		// second-generation Transformer presets; K remains recommended here
		// for the higher input-resolution modes. RR uses its own presets.
		r_options.dlaaPreset = sl::DLSSPreset::ePresetK;
		r_options.qualityPreset = sl::DLSSPreset::ePresetK;
		r_options.balancedPreset = sl::DLSSPreset::ePresetK;
		r_options.performancePreset = sl::DLSSPreset::ePresetM;
		r_options.ultraPerformancePreset = sl::DLSSPreset::ePresetL;
		r_options.ultraQualityPreset = sl::DLSSPreset::ePresetK;
	} else {
		sl::DLSSPreset preset = p_preset == '?' ? sl::DLSSPreset::eDefault : static_cast<sl::DLSSPreset>(static_cast<int>(sl::DLSSPreset::ePresetF) + p_preset - 'F');
		r_options.dlaaPreset = preset;
		r_options.qualityPreset = preset;
		r_options.balancedPreset = preset;
		r_options.performancePreset = preset;
		r_options.ultraPerformancePreset = preset;
		r_options.ultraQualityPreset = preset;
	}
	return p_set_options(p_viewport, r_options);
}

} // namespace StreamlineDLSSPresets
#endif
