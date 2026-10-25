/**************************************************************************/
/*  streamline_api_smoke.cpp                                               */
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

// Standalone check of the engine's enabled Streamline declarations, including
// on a host where SConstruct disables the optional runtime. No SDK DLLs or GPU
// are loaded. From the repository root:
// c++ -std=c++17 -Wall -Wextra -Werror -I. devtools/test/streamline_api_smoke.cpp -o streamline_api_smoke
// ./streamline_api_smoke
#ifndef STREAMLINE_ENABLED
#define STREAMLINE_ENABLED
#endif
#include "drivers/streamline/streamline_context.h"

#include <cstdio>
#include <type_traits>

static_assert(SL_VERSION_MAJOR == 2 && SL_VERSION_MINOR == 14 && SL_VERSION_PATCH == 16, "Expected the pinned Streamline SDK");
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slDLSSSetOptions), const sl::ViewportHandle &, const sl::DLSSOptions &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slDLSSGetOptimalSettings), const sl::DLSSOptions &, sl::DLSSOptimalSettings &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slDLSSDSetOptions), const sl::ViewportHandle &, const sl::DLSSDOptions &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slDLSSDGetOptimalSettings), const sl::DLSSDOptions &, sl::DLSSDOptimalSettings &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slDLSSGSetOptions), const sl::ViewportHandle &, const sl::DLSSGOptions &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slDLSSGGetState), const sl::ViewportHandle &, sl::DLSSGState &, const sl::DLSSGOptions *>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slReflexSetOptions), const sl::ReflexOptions &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slPCLSetOptions), const sl::PCLOptions &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slSetConstants), const sl::Constants &, const sl::FrameToken &, const sl::ViewportHandle &>);
static_assert(std::is_invocable_r_v<sl::Result, decltype(StreamlineContext::slSetTag), const sl::ViewportHandle &, const sl::ResourceTag *, uint32_t, sl::CommandBuffer *>);

int main() {
	const StreamlineContext context;
	const sl::DLSSOptions sr;
	const sl::DLSSDOptions rr;
	const sl::DLSSGOptions fg;
	const sl::DLSSGState fg_state;
	if (sr.mode != sl::DLSSMode::eOff || rr.mode != sl::DLSSMode::eOff || fg.mode != sl::DLSSGMode::eOff ||
			fg.numFramesToGenerate != 1 || fg.queueParallelismMode != sl::DLSSGQueueParallelismMode::eBlockPresentingClientQueue ||
			fg.enableUserInterfaceRecomposition != sl::Boolean::eFalse || fg.dynamicTargetFrameRate != 0.0f ||
			fg.structVersion != sl::kStructVersion5 || fg_state.structVersion != sl::kStructVersion4) {
		std::fputs("FAIL: unexpected Streamline options or structure versions\n", stderr);
		return 1;
	}
	// Missing runtime starts with no callable entry points or advertised features.
	// This checks initial state, not Windows DLL loading or driver behavior.
	const StreamlineCapabilities &caps = context.streamline_capabilities;
	if (context.slInit || context.slShutdown || context.slGetFeatureFunction || context.slSetConstants || context.slSetTag ||
			context.slDLSSSetOptions || context.slDLSSDSetOptions || context.slDLSSGSetOptions || context.slReflexSetOptions ||
			context.slPCLSetOptions || context.last_token || caps.dlss_available || caps.dlss_rr_available ||
			caps.dlss_g_available || caps.reflex_available || caps.pcl_available || caps.nis_available) {
		std::fputs("FAIL: Streamline starts with callable runtime entries or advertised features\n", stderr);
		return 1;
	}
	std::puts("PASS: Streamline 2.14.16 API, versioned options, and disabled initial state (no runtime or GPU test)");
	return 0;
}
