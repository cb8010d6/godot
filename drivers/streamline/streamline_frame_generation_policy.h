/**************************************************************************/
/*  streamline_frame_generation_policy.h                                */
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

#include <cstdint>

namespace StreamlineFGPolicy {

enum class Reason : uint8_t {
	UNAVAILABLE,
	EDITOR,
	NO_3D_VIEW,
	NO_REQUEST,
	MULTIPLE_VIEWS,
	OFFSCREEN,
	READY,
};

struct Input {
	bool game = false;
	bool available = false;
	uint32_t rendered_views = 0;
	uint32_t requested_views = 0;
	uint32_t requested_window_views = 0;
};

inline Reason select(const Input &p_input) {
	if (!p_input.game) {
		return Reason::EDITOR;
	}
	if (!p_input.available) {
		return Reason::UNAVAILABLE;
	}
	if (p_input.rendered_views == 0) {
		return Reason::NO_3D_VIEW;
	}
	if (p_input.requested_views == 0) {
		return Reason::NO_REQUEST;
	}
	if (p_input.rendered_views != 1 || p_input.requested_views != 1) {
		return Reason::MULTIPLE_VIEWS;
	}
	if (p_input.requested_window_views != 1) {
		return Reason::OFFSCREEN;
	}
	return Reason::READY;
}

inline const char *reason_name(Reason p_reason) {
	switch (p_reason) {
		case Reason::EDITOR:
			return "editor";
		case Reason::NO_3D_VIEW:
			return "no_3d_view";
		case Reason::NO_REQUEST:
			return "no_request";
		case Reason::MULTIPLE_VIEWS:
			return "multiple_3d_views";
		case Reason::OFFSCREEN:
			return "offscreen_viewport";
		case Reason::READY:
			return "ready";
		default:
			return "unavailable";
	}
}

} // namespace StreamlineFGPolicy
