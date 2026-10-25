/**************************************************************************/
/*  streamline_context.h                                                  */
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

#ifdef STREAMLINE_ENABLED
#include "drivers/streamline/streamline_data.h"
#include "drivers/streamline/streamline_frame_generation_policy.h"
#include "drivers/streamline/streamline_headers.h"

#include <atomic>
class StreamlineContext {
public:
	using TerminalGPUWaitCallback = bool (*)(void *p_userdata);

	// Successful SDK initialization, distinct from loading its entry points.
	bool sdk_initialized = false;

	// Interposer
	PFun_slInit *slInit = nullptr;
	PFun_slShutdown *slShutdown = nullptr;
	PFun_slIsFeatureSupported *slIsFeatureSupported = nullptr;
	PFun_slGetFeatureFunction *slGetFeatureFunction = nullptr;

	PFun_slGetNewFrameToken *slGetNewFrameToken = nullptr;
	PFun_slAllocateResources *slAllocateResources = nullptr;
	PFun_slFreeResources *slFreeResources = nullptr;
	PFun_slEvaluateFeature *slEvaluateFeature = nullptr;
	StreamlineSetTagFunction *slSetTag = nullptr;
	PFun_slSetConstants *slSetConstants = nullptr;
	PFun_slSetFeatureLoaded *slSetFeatureLoaded = nullptr;
	PFun_slSetD3DDevice *slSetD3DDevice = nullptr;

	// Reflex
	sl::ReflexOptions reflex_options;
	bool reflex_options_dirty = true;
	PFun_slReflexGetState *slReflexGetState = nullptr;
	PFun_slReflexSetOptions *slReflexSetOptions = nullptr;
	PFun_slReflexSleep *slReflexSleep = nullptr;

	// PCL
	sl::PCLOptions pcl_options;
	bool pcl_options_dirty = true;
	PFun_slPCLSetMarker *slPCLSetMarker = nullptr;
	PFun_slPCLSetOptions *slPCLSetOptions = nullptr;

	// DLSS Super Resolution
	PFun_slDLSSGetOptimalSettings *slDLSSGetOptimalSettings = nullptr;
	PFun_slDLSSGetState *slDLSSGetState = nullptr;
	PFun_slDLSSSetOptions *slDLSSSetOptions = nullptr;
	char dlss_default_preset = '?';
	char dlss_rr_default_preset = '?';

	// DLSS Ray Reconstruction (DLSS-D / DLSS-RR)
	PFun_slDLSSDGetOptimalSettings *slDLSSDGetOptimalSettings = nullptr;
	PFun_slDLSSDGetState *slDLSSDGetState = nullptr;
	PFun_slDLSSDSetOptions *slDLSSDSetOptions = nullptr;

	// DLSS Frame Generation
	PFun_slDLSSGGetState *slDLSSGGetState = nullptr;
	PFun_slDLSSGSetOptions *slDLSSGSetOptions = nullptr;

	// NIS
	PFun_slNISSetOptions *slNISSetOptions = nullptr;

	// D3D12
	void *func_D3D12GetInterface = nullptr;
	void *func_D3D12CreateDevice = nullptr;
	void *func_DXGIGetDebugInterface1 = nullptr;
	void *func_CreateDXGIFactory = nullptr;
	void *func_CreateDXGIFactory1 = nullptr;
	void *func_CreateDXGIFactory2 = nullptr;

	void load_functions(bool d3d12);
	void load_functions_post_init();
	static const char *result_to_string(sl::Result result);

	void reflex_set_options(const sl::ReflexOptions &opts);
	void reflex_sleep(sl::FrameToken *frameToken);
	void reflex_get_state(sl::ReflexState &reflexState);
	void pcl_set_options(const sl::PCLOptions &opts);
	void pcl_marker(sl::FrameToken *frameToken, sl::PCLMarker marker);
	sl::FrameToken *get_new_frame_token();

	void dlssg_disable();
	void update_frame_generation_policy(uint32_t p_rendered_views, uint32_t p_requested_views, uint32_t p_requested_window_views);
	void publish_frame_generation_status();
	uint64_t get_frame_generation_status_snapshot() const { return frame_generation_snapshot.load(std::memory_order_acquire); }

	static void initialize(bool d3d12);
	void set_terminal_gpu_wait_callback(TerminalGPUWaitCallback p_callback, void *p_userdata) {
		terminal_gpu_wait_callback = p_callback;
		terminal_gpu_wait_userdata = p_userdata;
	}
	// Terminal only: call after host rendering is drained, before native teardown.
	void shutdown();

	static StreamlineContext &get();

	sl::FrameToken *last_token = nullptr;
	bool is_game = false;

	sl::ViewportHandle dlssg_viewport;
	int dlssg_delay = 0;
	bool frame_generation_allowed = false;
	bool frame_generation_device_live = false;
	StreamlineFGPolicy::Reason frame_generation_reason = StreamlineFGPolicy::Reason::UNAVAILABLE;
	uint32_t frame_generation_rendered_views = 0;
	uint32_t frame_generation_requested_views = 0;
	std::atomic<uint64_t> frame_generation_snapshot{ 0 };

#if STREAMLINE_ENABLED_VULKAN
	StreamlineCapabilities enumerate_support_vulkan(void *vk_physical_device);
#endif
#if STREAMLINE_ENABLED_D3D12
	void init_device_d3d12(void *d3d_device);
	StreamlineCapabilities enumerate_support_d3d12(void *d3d_adapter_luid);
#endif

	StreamlineCapabilities streamline_capabilities;

private:
	TerminalGPUWaitCallback terminal_gpu_wait_callback = nullptr;
	void *terminal_gpu_wait_userdata = nullptr;
};
#endif
