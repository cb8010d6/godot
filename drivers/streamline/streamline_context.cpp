/**************************************************************************/
/*  streamline_context.cpp                                                */
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

#include "streamline_context.h"

#ifdef STREAMLINE_ENABLED
#ifdef _WIN32
#include <windows.h>
#endif

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnon-virtual-dtor"
#pragma clang diagnostic ignored "-Wshadow"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#elif defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnon-virtual-dtor"
#pragma GCC diagnostic ignored "-Wshadow"
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

#if STREAMLINE_ENABLED_VULKAN
#include <vulkan/vulkan.h>
#endif

#if STREAMLINE_ENABLED_D3D12
#include <d3d12.h>
#endif

#if defined(__clang__)
#pragma clang diagnostic pop
#elif defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

#include "core/config/engine.h"
#include "core/config/project_settings.h"
#include "core/os/os.h"
#include "core/string/print_string.h"

#include <algorithm>

StreamlineContext &StreamlineContext::get() {
	static StreamlineContext _context;
	return _context;
}

void StreamlineContext::load_functions(bool d3d12) {
#ifdef _WIN32
	HMODULE streamline = LoadLibraryA("sl.interposer.dll");
	if (streamline == nullptr) {
		return;
	}
#define SL_GETPROC(type, name) (type *)(void *)GetProcAddress(streamline, name)
	this->slInit = SL_GETPROC(PFun_slInit, "slInit");
	this->slShutdown = SL_GETPROC(PFun_slShutdown, "slShutdown");
	this->slIsFeatureSupported = SL_GETPROC(PFun_slIsFeatureSupported, "slIsFeatureSupported");
	this->slGetFeatureFunction = SL_GETPROC(PFun_slGetFeatureFunction, "slGetFeatureFunction");
	this->slGetNewFrameToken = SL_GETPROC(PFun_slGetNewFrameToken, "slGetNewFrameToken");
	this->slSetFeatureLoaded = SL_GETPROC(PFun_slSetFeatureLoaded, "slSetFeatureLoaded");
	this->slSetD3DDevice = SL_GETPROC(PFun_slSetD3DDevice, "slSetD3DDevice");

	this->slAllocateResources = SL_GETPROC(PFun_slAllocateResources, "slAllocateResources");
	this->slFreeResources = SL_GETPROC(PFun_slFreeResources, "slFreeResources");
	this->slEvaluateFeature = SL_GETPROC(PFun_slEvaluateFeature, "slEvaluateFeature");
	this->slSetTag = SL_GETPROC(StreamlineSetTagFunction, "slSetTag");
	this->slSetConstants = SL_GETPROC(PFun_slSetConstants, "slSetConstants");
#undef SL_GETPROC

#if STREAMLINE_ENABLED_D3D12
	if (d3d12) {
		this->func_CreateDXGIFactory = (void *)GetProcAddress(streamline, "CreateDXGIFactory");
		this->func_CreateDXGIFactory1 = (void *)GetProcAddress(streamline, "CreateDXGIFactory1");
		this->func_CreateDXGIFactory2 = (void *)GetProcAddress(streamline, "CreateDXGIFactory2");
		this->func_D3D12CreateDevice = (void *)GetProcAddress(streamline, "D3D12CreateDevice");
		this->func_D3D12GetInterface = (void *)GetProcAddress(streamline, "D3D12GetInterface");
		this->func_DXGIGetDebugInterface1 = (void *)GetProcAddress(streamline, "DXGIGetDebugInterface1");
	}
#endif
#endif
}

void StreamlineContext::load_functions_post_init() {
	if (slGetFeatureFunction) {
		slGetFeatureFunction(sl::kFeatureReflex, "slReflexSetOptions", (void *&)this->slReflexSetOptions);
		slGetFeatureFunction(sl::kFeatureReflex, "slReflexSleep", (void *&)this->slReflexSleep);
		slGetFeatureFunction(sl::kFeatureReflex, "slReflexGetState", (void *&)this->slReflexGetState);
		slGetFeatureFunction(sl::kFeaturePCL, "slPCLSetMarker", (void *&)this->slPCLSetMarker);
		slGetFeatureFunction(sl::kFeaturePCL, "slPCLSetOptions", (void *&)this->slPCLSetOptions);

		slGetFeatureFunction(sl::kFeatureDLSS, "slDLSSGetOptimalSettings", (void *&)this->slDLSSGetOptimalSettings);
		slGetFeatureFunction(sl::kFeatureDLSS, "slDLSSGetState", (void *&)this->slDLSSGetState);
		slGetFeatureFunction(sl::kFeatureDLSS, "slDLSSSetOptions", (void *&)this->slDLSSSetOptions);

		slGetFeatureFunction(sl::kFeatureDLSS_G, "slDLSSGGetState", (void *&)this->slDLSSGGetState);
		slGetFeatureFunction(sl::kFeatureDLSS_G, "slDLSSGSetOptions", (void *&)this->slDLSSGSetOptions);

		// DLSS Ray Reconstruction (DLSS-RR)
		slGetFeatureFunction(sl::kFeatureDLSS_RR, "slDLSSDGetOptimalSettings", (void *&)this->slDLSSDGetOptimalSettings);
		slGetFeatureFunction(sl::kFeatureDLSS_RR, "slDLSSDGetState", (void *&)this->slDLSSDGetState);
		slGetFeatureFunction(sl::kFeatureDLSS_RR, "slDLSSDSetOptions", (void *&)this->slDLSSDSetOptions);

		slGetFeatureFunction(sl::kFeatureNIS, "slNISSetOptions", (void *&)this->slNISSetOptions);
	}
}

static void _enumerate_support(StreamlineContext *self, sl::AdapterInfo &adapterInfo, StreamlineCapabilities &outSupport) {
	if (self->slIsFeatureSupported) {
		outSupport.dlss_available = self->slIsFeatureSupported(sl::kFeatureDLSS, adapterInfo) == sl::Result::eOk;
		outSupport.dlss_g_available = self->slIsFeatureSupported(sl::kFeatureDLSS_G, adapterInfo) == sl::Result::eOk;
		outSupport.dlss_rr_available = self->slIsFeatureSupported(sl::kFeatureDLSS_RR, adapterInfo) == sl::Result::eOk;
		outSupport.reflex_available = self->slIsFeatureSupported(sl::kFeatureReflex, adapterInfo) == sl::Result::eOk;
		outSupport.pcl_available = self->slIsFeatureSupported(sl::kFeaturePCL, adapterInfo) == sl::Result::eOk;
		outSupport.nis_available = self->slIsFeatureSupported(sl::kFeatureNIS, adapterInfo) == sl::Result::eOk;
	}
}

#if STREAMLINE_ENABLED_VULKAN
StreamlineCapabilities StreamlineContext::enumerate_support_vulkan(void *vk_physical_device) {
	VkPhysicalDevice device = (VkPhysicalDevice)vk_physical_device;
	StreamlineCapabilities support;
	sl::AdapterInfo adapterInfo;
	adapterInfo.vkPhysicalDevice = device;
	_enumerate_support(this, adapterInfo, support);
	return support;
}
#endif

#if STREAMLINE_ENABLED_D3D12
StreamlineCapabilities StreamlineContext::enumerate_support_d3d12(void *d3d_adapter_luid) {
	StreamlineCapabilities support;
	sl::AdapterInfo adapterInfo;
	adapterInfo.deviceLUID = (uint8_t *)d3d_adapter_luid;
	adapterInfo.deviceLUIDSizeInBytes = sizeof(LUID);
	_enumerate_support(this, adapterInfo, support);
	return support;
}

void StreamlineContext::init_device_d3d12(void *d3d12_device) {
	if (this->slSetD3DDevice) {
		sl::Result result = this->slSetD3DDevice(d3d12_device);
		ERR_FAIL_COND_MSG(result != sl::Result::eOk, StreamlineContext::result_to_string(result));
	}
}
#endif

#define STREAMLINE_GAME_ONLY \
	if (!is_game) \
		return;

void StreamlineContext::dlssg_disable() {
	STREAMLINE_GAME_ONLY; // Disable DLSS-G for editor or project settings.

	dlssg_delay = 10;

	if (slDLSSGSetOptions && (uint32_t)dlssg_viewport != UINT_MAX) {
		WARN_PRINT("Force disabling DLSS-G on viewport: " + itos((unsigned int)StreamlineContext::get().dlssg_viewport));

		sl::DLSSGOptions dlssGOptions{};
		dlssGOptions.mode = sl::DLSSGMode::eOff;
		sl::Result result = slDLSSGSetOptions(dlssg_viewport, dlssGOptions);
		ERR_FAIL_COND_MSG(result != sl::Result::eOk, "Failed to disable Streamline Frame Generation. Result: " + String(result_to_string(result)));

		dlssg_viewport = sl::ViewportHandle(-1);
	}
	publish_frame_generation_status();
}

void StreamlineContext::update_frame_generation_policy(uint32_t p_rendered_views, uint32_t p_requested_views, uint32_t p_requested_window_views) {
	const bool available = frame_generation_device_live && streamline_capabilities.dlss_g_available && slDLSSGSetOptions != nullptr;
	StreamlineFGPolicy::Reason reason = StreamlineFGPolicy::select({ is_game, available, p_rendered_views, p_requested_views, p_requested_window_views });
	if (reason != frame_generation_reason && p_requested_views > 0 &&
			(reason == StreamlineFGPolicy::Reason::MULTIPLE_VIEWS || reason == StreamlineFGPolicy::Reason::OFFSCREEN)) {
		WARN_PRINT(vformat("DLSS Frame Generation uses ordinary rendering for this viewport arrangement: %s.", StreamlineFGPolicy::reason_name(reason)));
	}
	frame_generation_reason = reason;
	frame_generation_rendered_views = p_rendered_views;
	frame_generation_requested_views = p_requested_views;
	frame_generation_allowed = reason == StreamlineFGPolicy::Reason::READY;
	if (!frame_generation_allowed && (uint32_t)dlssg_viewport != UINT_MAX) {
		// Do not repeatedly reset SDK options or its enable delay for each
		// offscreen context. An existing owner is disabled once on transition.
		dlssg_disable();
	}
	publish_frame_generation_status();
}

void StreamlineContext::publish_frame_generation_status() {
	const bool available = frame_generation_device_live && streamline_capabilities.dlss_g_available && slDLSSGSetOptions != nullptr;
	uint64_t snapshot = static_cast<uint8_t>(frame_generation_reason);
	snapshot |= uint64_t(std::min(frame_generation_rendered_views, 0xffffu)) << 8;
	snapshot |= uint64_t(std::min(frame_generation_requested_views, 0xffffu)) << 24;
	snapshot |= uint64_t(available) << 40;
	snapshot |= uint64_t((uint32_t)dlssg_viewport != UINT_MAX) << 41;
	frame_generation_snapshot.store(snapshot, std::memory_order_release);
}

void StreamlineContext::reflex_set_options(const sl::ReflexOptions &opts) {
	STREAMLINE_GAME_ONLY; // Disable reflex for editor or project settings.

	reflex_options = opts;
	reflex_options_dirty = false;
	sl::Result result = this->slReflexSetOptions ? this->slReflexSetOptions(opts) : sl::Result::eOk;
	ERR_FAIL_COND_MSG(result != sl::Result::eOk, StreamlineContext::result_to_string(result));
}

void StreamlineContext::pcl_set_options(const sl::PCLOptions &opts) {
	STREAMLINE_GAME_ONLY; // Disable PCL for editor or project settings.

	pcl_options = opts;
	pcl_options_dirty = false;
	sl::Result result = this->slPCLSetOptions ? this->slPCLSetOptions(opts) : sl::Result::eOk;
	ERR_FAIL_COND_MSG(result != sl::Result::eOk, StreamlineContext::result_to_string(result));
}

void StreamlineContext::pcl_marker(sl::FrameToken *frameToken, sl::PCLMarker marker) {
	STREAMLINE_GAME_ONLY; // Disable PCL for editor or project settings.

	sl::Result result = this->slPCLSetMarker ? this->slPCLSetMarker(marker, *frameToken) : sl::Result::eOk;
	ERR_FAIL_COND_MSG(result != sl::Result::eOk, StreamlineContext::result_to_string(result));
}

void StreamlineContext::reflex_sleep(sl::FrameToken *frameToken) {
	STREAMLINE_GAME_ONLY; // Disable reflex for editor or project settings.

	if (frameToken == nullptr) {
		return;
	}

	sl::Result result = this->slReflexSleep ? this->slReflexSleep(*frameToken) : sl::Result::eOk;
	ERR_FAIL_COND_MSG(result != sl::Result::eOk, StreamlineContext::result_to_string(result));
}

void StreamlineContext::reflex_get_state(sl::ReflexState &reflexState) {
	STREAMLINE_GAME_ONLY; // Disable reflex for editor or project settings.

	sl::Result result = this->slReflexGetState ? this->slReflexGetState(reflexState) : sl::Result::eOk;
	ERR_FAIL_COND_MSG(result != sl::Result::eOk, StreamlineContext::result_to_string(result));
}

sl::FrameToken *StreamlineContext::get_new_frame_token() {
	sl::Result result = this->slGetNewFrameToken ? this->slGetNewFrameToken(last_token, nullptr) : sl::Result::eOk;
	ERR_FAIL_COND_V_MSG(result != sl::Result::eOk, nullptr, StreamlineContext::result_to_string(result));
	return last_token;
}

const char *StreamlineContext::result_to_string(sl::Result result) {
	switch (result) {
		case sl::Result::eOk:
			return "sl::eOk";
		case sl::Result::eErrorIO:
			return "sl::eErrorIO";
		case sl::Result::eErrorDriverOutOfDate:
			return "sl::eErrorDriverOutOfDate";
		case sl::Result::eErrorOSOutOfDate:
			return "sl::eErrorOSOutOfDate";
		case sl::Result::eErrorOSDisabledHWS:
			return "sl::eErrorOSDisabledHWS";
		case sl::Result::eErrorDeviceNotCreated:
			return "sl::eErrorDeviceNotCreated";
		case sl::Result::eErrorNoSupportedAdapterFound:
			return "sl::eErrorNoSupportedAdapterFound";
		case sl::Result::eErrorAdapterNotSupported:
			return "sl::eErrorAdapterNotSupported";
		case sl::Result::eErrorNoPlugins:
			return "sl::eErrorNoPlugins";
		case sl::Result::eErrorVulkanAPI:
			return "sl::eErrorVulkanAPI";
		case sl::Result::eErrorDXGIAPI:
			return "sl::eErrorDXGIAPI";
		case sl::Result::eErrorD3DAPI:
			return "sl::eErrorD3DAPI";
		case sl::Result::eErrorNRDAPI:
			return "sl::eErrorNRDAPI";
		case sl::Result::eErrorNVAPI:
			return "sl::eErrorNVAPI";
		case sl::Result::eErrorReflexAPI:
			return "sl::eErrorReflexAPI";
		case sl::Result::eErrorNGXFailed:
			return "sl::eErrorNGXFailed";
		case sl::Result::eErrorJSONParsing:
			return "sl::eErrorJSONParsing";
		case sl::Result::eErrorMissingProxy:
			return "sl::eErrorMissingProxy";
		case sl::Result::eErrorMissingResourceState:
			return "sl::eErrorMissingResourceState";
		case sl::Result::eErrorInvalidIntegration:
			return "sl::eErrorInvalidIntegration";
		case sl::Result::eErrorMissingInputParameter:
			return "sl::eErrorMissingInputParameter";
		case sl::Result::eErrorNotInitialized:
			return "sl::eErrorNotInitialized";
		case sl::Result::eErrorComputeFailed:
			return "sl::eErrorComputeFailed";
		case sl::Result::eErrorInitNotCalled:
			return "sl::eErrorInitNotCalled";
		case sl::Result::eErrorExceptionHandler:
			return "sl::eErrorExceptionHandler";
		case sl::Result::eErrorInvalidParameter:
			return "sl::eErrorInvalidParameter";
		case sl::Result::eErrorMissingConstants:
			return "sl::eErrorMissingConstants";
		case sl::Result::eErrorDuplicatedConstants:
			return "sl::eErrorDuplicatedConstants";
		case sl::Result::eErrorMissingOrInvalidAPI:
			return "sl::eErrorMissingOrInvalidAPI";
		case sl::Result::eErrorCommonConstantsMissing:
			return "sl::eErrorCommonConstantsMissing";
		case sl::Result::eErrorUnsupportedInterface:
			return "sl::eErrorUnsupportedInterface";
		case sl::Result::eErrorFeatureMissing:
			return "sl::eErrorFeatureMissing";
		case sl::Result::eErrorFeatureNotSupported:
			return "sl::eErrorFeatureNotSupported";
		case sl::Result::eErrorFeatureMissingHooks:
			return "sl::eErrorFeatureMissingHooks";
		case sl::Result::eErrorFeatureFailedToLoad:
			return "sl::eErrorFeatureFailedToLoad";
		case sl::Result::eErrorFeatureWrongPriority:
			return "sl::eErrorFeatureWrongPriority";
		case sl::Result::eErrorFeatureMissingDependency:
			return "sl::eErrorFeatureMissingDependency";
		case sl::Result::eErrorFeatureManagerInvalidState:
			return "sl::eErrorFeatureManagerInvalidState";
		case sl::Result::eErrorInvalidState:
			return "sl::eErrorInvalidState";
		case sl::Result::eWarnOutOfVRAM:
			return "sl::eWarnOutOfVRAM";
		default:
			return "sl::eUnknown";
	}
}

void StreamlineContext::shutdown() {
	// Consume the entry point before calling the SDK so repeated terminal
	// cleanup paths cannot shut the process-wide SDK down twice.
	PFun_slShutdown *shutdown_function = slShutdown;
	const bool was_initialized = sdk_initialized;
	slShutdown = nullptr;
	sdk_initialized = false;

	sl::Result result = sl::Result::eOk;
	if (was_initialized) {
		result = shutdown_function ? shutdown_function() : sl::Result::eErrorMissingOrInvalidAPI;
	}

	// Plugins may have unloaded. Preserve the interposer module and slInit
	// sentinel, but never retain callable plugin pointers or a frame token.
	// initialize() remains terminal after shutdown; process reinitialization
	// is not introduced by this cleanup change.
	slIsFeatureSupported = nullptr;
	slGetFeatureFunction = nullptr;
	slGetNewFrameToken = nullptr;
	slAllocateResources = nullptr;
	slFreeResources = nullptr;
	slEvaluateFeature = nullptr;
	slSetTag = nullptr;
	slSetConstants = nullptr;
	slSetFeatureLoaded = nullptr;
	slSetD3DDevice = nullptr;
	slReflexGetState = nullptr;
	slReflexSetOptions = nullptr;
	slReflexSleep = nullptr;
	slPCLSetMarker = nullptr;
	slPCLSetOptions = nullptr;
	slDLSSGetOptimalSettings = nullptr;
	slDLSSGetState = nullptr;
	slDLSSSetOptions = nullptr;
	slDLSSDGetOptimalSettings = nullptr;
	slDLSSDGetState = nullptr;
	slDLSSDSetOptions = nullptr;
	slDLSSGGetState = nullptr;
	slDLSSGSetOptions = nullptr;
	slNISSetOptions = nullptr;
	func_D3D12GetInterface = nullptr;
	func_D3D12CreateDevice = nullptr;
	func_DXGIGetDebugInterface1 = nullptr;
	func_CreateDXGIFactory = nullptr;
	func_CreateDXGIFactory1 = nullptr;
	func_CreateDXGIFactory2 = nullptr;
	last_token = nullptr;
	streamline_capabilities = {};
	is_game = false;
	frame_generation_device_live = false;
	frame_generation_allowed = false;
	frame_generation_reason = StreamlineFGPolicy::Reason::UNAVAILABLE;
	frame_generation_rendered_views = 0;
	frame_generation_requested_views = 0;
	dlssg_viewport = sl::ViewportHandle(-1);
	publish_frame_generation_status();
	if (result != sl::Result::eOk) {
		ERR_PRINT("Failed to shut down Streamline. Result: " + String(result_to_string(result)));
	} else if (was_initialized) {
		print_verbose("Streamline SDK shutdown completed before native graphics teardown.");
	}
}

void StreamlineContext::initialize(bool d3d12) {
	StreamlineContext::get().is_game = true;
	if (Engine::get_singleton()->is_editor_hint() || Engine::get_singleton()->is_project_manager_hint()) {
		StreamlineContext::get().is_game = false;
	}

	if (StreamlineContext::get().slInit != nullptr) {
		return; // already initialized.
	}

	StreamlineContext::get().load_functions(d3d12);
	if (StreamlineContext::get().slInit == nullptr) {
		return;
	}

	sl::Preferences pref;

	Vector<sl::Feature> featuresToLoad;

	if (StreamlineContext::get().is_game) {
		featuresToLoad.push_back(sl::kFeaturePCL);
		featuresToLoad.push_back(sl::kFeatureReflex);
		featuresToLoad.push_back(sl::kFeatureDLSS_G);

		if (bool(GLOBAL_GET("rendering/streamline/streamline_imgui"))) {
			featuresToLoad.push_back(sl::kFeatureImGUI);
		}
	}
	featuresToLoad.push_back(sl::kFeatureDLSS);
	featuresToLoad.push_back(sl::kFeatureDLSS_RR); // DLSS Ray Reconstruction
	featuresToLoad.push_back(sl::kFeatureNIS);

	pref.featuresToLoad = featuresToLoad.ptr();
	pref.numFeaturesToLoad = featuresToLoad.size();

	pref.renderAPI = d3d12 ? sl::RenderAPI::eD3D12 : sl::RenderAPI::eVulkan;
	pref.applicationId = 0x90d07004;
	pref.flags = sl::PreferenceFlags::eDisableCLStateTracking;
	// Allow offline validation of the installed release without an OTA download
	// or a plugin substitution from the system cache. Normal builds keep OTA.
	if (OS::get_singleton()->get_environment("GODOT_STREAMLINE_DISABLE_OTA") != "1") {
		pref.flags |= sl::PreferenceFlags::eAllowOTA | sl::PreferenceFlags::eLoadDownloadedPlugins;
	}

	if (bool(GLOBAL_GET("rendering/streamline/streamline_log"))) {
		pref.logLevel = sl::LogLevel::eVerbose;
		pref.showConsole = true;
	} else {
		pref.logLevel = sl::LogLevel::eOff;
		pref.showConsole = false;
	}
	sl::Result result = StreamlineContext::get().slInit(pref, sl::kSDKVersion);
	ERR_FAIL_COND_MSG(result != sl::Result::eOk, StreamlineContext::result_to_string(result));
	StreamlineContext::get().sdk_initialized = true;
}

#endif
