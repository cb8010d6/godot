/**************************************************************************/
/*  streamline_fg_policy.cpp                                            */
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

// Standalone CPU policy boundary checks; not GPU or generated-frame validation.
#include "drivers/streamline/streamline_frame_generation_policy.h"

#include <cstdio>

int main() {
	using namespace StreamlineFGPolicy;
	struct Case {
		Input input;
		Reason expected;
	};
	const Case cases[] = {
		{ { false, true, 1, 1, 1 }, Reason::EDITOR },
		{ { true, false, 1, 1, 1 }, Reason::UNAVAILABLE },
		{ { true, true, 0, 0, 0 }, Reason::NO_3D_VIEW },
		{ { true, true, 1, 0, 0 }, Reason::NO_REQUEST },
		{ { true, true, 1, 1, 1 }, Reason::READY },
		{ { true, true, 1, 1, 0 }, Reason::OFFSCREEN },
		{ { true, true, 2, 1, 1 }, Reason::MULTIPLE_VIEWS },
		{ { true, true, 2, 2, 0 }, Reason::MULTIPLE_VIEWS },
		{ { true, true, 4, 4, 0 }, Reason::MULTIPLE_VIEWS },
		{ { true, true, 2, 2, 2 }, Reason::MULTIPLE_VIEWS },
		{ { true, true, 1, 2, 1 }, Reason::MULTIPLE_VIEWS },
		{ { true, true, 1, 1, 1 }, Reason::READY }, // Main view remains after children are destroyed.
	};
	for (const Case &test : cases) {
		if (select(test.input) != test.expected) {
			std::fprintf(stderr, "Frame Generation policy mismatch: expected %s\n", reason_name(test.expected));
			return 1;
		}
	}
	std::printf("12 Frame Generation policy boundary checks passed (CPU only)\n");
	return 0;
}
