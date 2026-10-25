/**************************************************************************/
/*  streamline_dlss_sizing.h                                               */
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

#include <cstddef>
#include <cstdint>

// CPU policy only. Runtime queries and their SR/RR choice belong to the caller.
namespace StreamlineDLSSSizing {

struct RenderSize {
	uint32_t width = 0;
	uint32_t height = 0;
};

struct ModeBounds {
	RenderSize minimum;
	RenderSize maximum;
	RenderSize optimal;
	bool query_succeeded = false;
};

inline bool is_usable(const ModeBounds &p_bounds) {
	return p_bounds.query_succeeded &&
			p_bounds.minimum.width > 0 && p_bounds.minimum.height > 0 &&
			p_bounds.minimum.width <= p_bounds.maximum.width && p_bounds.minimum.height <= p_bounds.maximum.height &&
			p_bounds.optimal.width >= p_bounds.minimum.width && p_bounds.optimal.width <= p_bounds.maximum.width &&
			p_bounds.optimal.height >= p_bounds.minimum.height && p_bounds.optimal.height <= p_bounds.maximum.height;
}

inline bool contains(const ModeBounds &p_bounds, RenderSize p_size) {
	return p_size.width >= p_bounds.minimum.width && p_size.width <= p_bounds.maximum.width &&
			p_size.height >= p_bounds.minimum.height && p_size.height <= p_bounds.maximum.height;
}

inline RenderSize reconcile_render_size(RenderSize p_desired, const ModeBounds *p_bounds, size_t p_count) {
	if (p_bounds == nullptr || p_desired.width == 0 || p_desired.height == 0) {
		return p_desired;
	}

	// Keep all currently legal inputs, even if another mode is closer to optimal.
	for (size_t i = 0; i < p_count; i++) {
		if (is_usable(p_bounds[i]) && contains(p_bounds[i], p_desired)) {
			return p_desired;
		}
	}

	RenderSize selected = p_desired;
	uint32_t closest_change = 3; // Each accepted axis contributes at most one.
	for (size_t i = 0; i < p_count; i++) {
		const ModeBounds &bounds = p_bounds[i];
		if (!is_usable(bounds)) {
			continue;
		}

		RenderSize candidate;
		candidate.width = p_desired.width < bounds.minimum.width ? bounds.minimum.width : (p_desired.width > bounds.maximum.width ? bounds.maximum.width : p_desired.width);
		candidate.height = p_desired.height < bounds.minimum.height ? bounds.minimum.height : (p_desired.height > bounds.maximum.height ? bounds.maximum.height : p_desired.height);
		const uint32_t width_change = candidate.width > p_desired.width ? candidate.width - p_desired.width : p_desired.width - candidate.width;
		const uint32_t height_change = candidate.height > p_desired.height ? candidate.height - p_desired.height : p_desired.height - candidate.height;
		if (width_change > 1 || height_change > 1) {
			continue;
		}
		const uint32_t change = width_change * width_change + height_change * height_change;
		if (change < closest_change) {
			selected = candidate;
			closest_change = change;
		}
	}
	return selected;
}

} // namespace StreamlineDLSSSizing
