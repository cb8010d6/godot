// Read-only, test-only GDExtension. Call read_state on the rendering/present
// thread after a rendered frame. It never enables or evaluates a feature.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#include "core/extension/gdextension_interface.gen.h"
#include "thirdparty/streamline/include/sl.h"
#include "thirdparty/streamline/include/sl_dlss.h"
#include "thirdparty/streamline/include/sl_dlss_d.h"
#include "thirdparty/streamline/include/sl_dlss_g.h"
#include "thirdparty/streamline/include/sl_reflex.h"
#include <algorithm>
#include <cctype>
#include <sstream>
#include <string>
#include "optimal_settings_probe.h"

static GDExtensionInterfaceGetProcAddress api;
static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
static GDExtensionInterfaceStringNewWithUtf8Chars string_new;
static GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
static GDExtensionInterfaceVariantGetPtrDestructor destroy_type;
static GDExtensionInterfaceClassdbConstructObject2 construct_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
struct alignas(16) Storage { unsigned char data[256]{}; };
static Storage class_name, parent_name, method_name, empty_name, empty_string;

static std::string snapshot() {
	std::ostringstream out;
	HMODULE module = GetModuleHandleW(L"sl.interposer.dll");
	const bool fg_module_observed = GetModuleHandleW(L"sl.dlss_g.dll") != nullptr;
	out << "{\"thread_id\":" << GetCurrentThreadId() << ",\"interposer_loaded\":" << (module ? "true" : "false");
	out << ",\"probe_schema\":\"fg-module-guard-v1\",\"fg_plugin_module_observed\":" << (fg_module_observed ? "true" : "false");
	DWORD foreground_pid=0;
	GetWindowThreadProcessId(GetForegroundWindow(),&foreground_pid);
	out << ",\"process_id\":" << GetCurrentProcessId() << ",\"foreground_process_id\":" << foreground_pid;
	if (!module) { return out.str() + "}"; }
	static uint32_t sample = 0;
	if (sample++ % 60 == 0) {
		HMODULE modules[1024]; DWORD bytes = 0;
		out << ",\"loaded_runtime_paths\":[";
		bool first = true;
		if (EnumProcessModules(GetCurrentProcess(),modules,sizeof(modules),&bytes)) {
			for (DWORD i=0;i<std::min<DWORD>(bytes/sizeof(HMODULE),1024);i++) {
				char buffer[32768]{};
				if (!GetModuleFileNameA(modules[i],buffer,sizeof(buffer))) { continue; }
				std::string path(buffer), lower(path);
				std::transform(lower.begin(),lower.end(),lower.begin(),[](unsigned char c){return static_cast<char>(std::tolower(c));});
				if (lower.find("\\ngx\\")==std::string::npos && lower.find("\\sl.")==std::string::npos && lower.find("\\nvngx_")==std::string::npos && lower.find("nvlowlatency")==std::string::npos) { continue; }
				if (!first) { out << ','; } first=false;
				out << '"'; for (char c:path) { if (c=='\\' || c=='"') { out << '\\'; } out << c; } out << '"';
			}
		}
		out << ']';
	}
	auto get_version = reinterpret_cast<PFun_slGetFeatureVersion *>(GetProcAddress(module,"slGetFeatureVersion"));
	auto get_function = reinterpret_cast<PFun_slGetFeatureFunction *>(GetProcAddress(module,"slGetFeatureFunction"));
	if (sample == 1) { out << ",\"optimal_settings_probe\":" << optimal_settings_snapshot(get_function); }
	if (get_version) {
		out << ",\"versions\":[";
		bool first = true;
		for (sl::Feature feature : {sl::kFeatureDLSS, sl::kFeatureDLSS_RR, sl::kFeatureDLSS_G, sl::kFeatureReflex, sl::kFeaturePCL}) {
			if (feature == sl::kFeatureDLSS_G && !fg_module_observed) {
				if (!first) { out << ','; }
				first = false;
				out << "{\"feature\":" << feature << ",\"query_executed\":false,\"skip_reason\":\"dlss_g_module_not_observed\"}";
				continue;
			}
			sl::FeatureVersion version;
			sl::Result result = get_version(feature,version);
			if (!first) { out << ','; }
			first = false;
			out << "{\"feature\":" << feature << ",\"result\":" << static_cast<int>(result)
				<< ",\"sl\":\"" << version.versionSL.toStr() << "\",\"ngx\":\"" << version.versionNGX.toStr() << "\"}";
		}
		out << ']';
	}
	if (get_function) {
		void *sr_function = nullptr;
		void *rr_function = nullptr;
		get_function(sl::kFeatureDLSS, "slDLSSGetState", sr_function);
		get_function(sl::kFeatureDLSS_RR, "slDLSSDGetState", rr_function);
		out << ",\"sr_rr_viewports\":[";
		for (unsigned int viewport = 1; viewport <= 2; viewport++) {
			sl::DLSSState sr_state;
			sl::DLSSDState rr_state;
			int sr_result = sr_function ? static_cast<int>(reinterpret_cast<PFun_slDLSSGetState *>(sr_function)(sl::ViewportHandle(viewport), sr_state)) : -1;
			int rr_result = rr_function ? static_cast<int>(reinterpret_cast<PFun_slDLSSDGetState *>(rr_function)(sl::ViewportHandle(viewport), rr_state)) : -1;
			if (viewport > 1) { out << ','; }
			out << "{\"viewport\":" << viewport << ",\"sr_result\":" << sr_result
				<< ",\"rr_result\":" << rr_result << ",\"sr_estimated_vram_bytes\":" << sr_state.estimatedVRAMUsageInBytes
				<< ",\"rr_estimated_vram_bytes\":" << rr_state.estimatedVRAMUsageInBytes << '}';
		}
		out << ']';
		void *function = nullptr;
		sl::Result loaded = sl::Result::eOk;
		if (fg_module_observed) {
			out << ",\"fg_query_executed\":true";
			loaded = get_function(sl::kFeatureDLSS_G,"slDLSSGGetState",function);
			out << ",\"fg_getter_result\":" << static_cast<int>(loaded);
			if (loaded == sl::Result::eOk && function) {
				sl::DLSSGState state;
				sl::Result result = reinterpret_cast<PFun_slDLSSGGetState *>(function)(sl::ViewportHandle(1),state,nullptr);
				out << ",\"fg\":{\"result\":" << static_cast<int>(result) << ",\"status\":" << static_cast<int>(state.status)
					<< ",\"presented_since_query\":" << state.numFramesActuallyPresented
					<< ",\"max_generated_frames\":" << state.numFramesToGenerateMax
					<< ",\"dynamic_mfg_supported\":" << static_cast<int>(state.bIsDynamicMFGSupported)
					<< ",\"min_dimension\":" << state.minWidthOrHeight << '}';
			}
		} else {
			out << ",\"fg_query_executed\":false,\"fg_query_skip_reason\":\"dlss_g_module_not_observed\"";
		}
		function = nullptr;
		loaded = get_function(sl::kFeatureReflex,"slReflexGetState",function);
		if (loaded == sl::Result::eOk && function) {
			sl::ReflexState state;
			sl::Result result = reinterpret_cast<PFun_slReflexGetState *>(function)(state);
			uint64_t latest = 0;
			int last = 0;
			for (int i = 0; i < sl::kReflexFrameReportCount; i++) {
				if (state.frameReport[i].frameID > latest) { latest = state.frameReport[i].frameID; last = i; }
			}
			const auto &r = state.frameReport[last];
			out << ",\"reflex\":{\"result\":" << static_cast<int>(result)
				<< ",\"low_latency_available\":" << (state.lowLatencyAvailable ? "true" : "false")
				<< ",\"report_available\":" << (state.latencyReportAvailable ? "true" : "false")
				<< ",\"frame_id\":" << latest << ",\"simulation_start\":" << r.simStartTime
				<< ",\"simulation_end\":" << r.simEndTime << ",\"render_submit_start\":" << r.renderSubmitStartTime
				<< ",\"render_submit_end\":" << r.renderSubmitEndTime << ",\"present_start\":" << r.presentStartTime
				<< ",\"present_end\":" << r.presentEndTime << ",\"gpu_start\":" << r.gpuRenderStartTime
				<< ",\"gpu_end\":" << r.gpuRenderEndTime << '}';
		}
	}
	out << '}';
	return out.str();
}

static void read_state(void *, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr *, GDExtensionInt,
		GDExtensionVariantPtr returned, GDExtensionCallError *error) {
	Storage text;
	string_new(&text, snapshot().c_str());
	from_type(GDEXTENSION_VARIANT_TYPE_STRING)(returned, &text);
	destroy_type(GDEXTENSION_VARIANT_TYPE_STRING)(&text);
	error->error = GDEXTENSION_CALL_OK;
}
static void read_state_ptr(void *, GDExtensionClassInstancePtr, const GDExtensionConstTypePtr *, GDExtensionTypePtr returned) {
	string_new(returned, snapshot().c_str());
}
static GDExtensionObjectPtr create(void *, GDExtensionBool) {
	GDExtensionObjectPtr object = construct_object(&parent_name);
	set_instance(object, &class_name, new unsigned int(0));
	return object;
}
static void free_instance(void *, GDExtensionClassInstancePtr instance) { delete static_cast<unsigned int *>(instance); }
static void initialize(void *, GDExtensionInitializationLevel level) {
	if (level != GDEXTENSION_INITIALIZATION_SCENE) { return; }
	name_new(&class_name,"RTXAcceptanceProbe"); name_new(&parent_name,"Object");
	name_new(&method_name,"read_state"); name_new(&empty_name,""); string_new(&empty_string,"");
	GDExtensionClassCreationInfo6 info{};
	info.is_exposed = true; info.create_instance_func = create; info.free_instance_func = free_instance;
	register_class(library,&class_name,&parent_name,&info);
	GDExtensionPropertyInfo value{};
	value.type = GDEXTENSION_VARIANT_TYPE_STRING; value.name = &empty_name; value.class_name = &empty_name;
	value.hint_string = &empty_string;
	GDExtensionClassMethodInfo method{};
	method.name = &method_name; method.call_func = read_state;
	method.ptrcall_func = read_state_ptr;
	method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
	method.has_return_value = true; method.return_value_info = &value;
	register_method(library,&class_name,&method);
}
static void deinitialize(void *, GDExtensionInitializationLevel level) {
	if (level != GDEXTENSION_INITIALIZATION_SCENE) { return; }
	unregister_class(library,&class_name);
	for (Storage *item : {&class_name,&parent_name,&method_name,&empty_name}) { destroy_type(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(item); }
	destroy_type(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}
extern "C" __declspec(dllexport) GDExtensionBool rtx_probe_init(GDExtensionInterfaceGetProcAddress get,
		GDExtensionClassLibraryPtr lib, GDExtensionInitialization *initialization) {
	api = get; library = lib;
#define LOAD(target, type, name) target = reinterpret_cast<type>(api(name)); if (!target) { return false; }
	LOAD(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars")
	LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars")
	LOAD(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor")
	LOAD(destroy_type,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor")
	LOAD(construct_object,GDExtensionInterfaceClassdbConstructObject2,"classdb_construct_object2")
	LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance")
	LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6")
	LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method")
	LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class")
#undef LOAD
	initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
	initialization->initialize = initialize; initialization->deinitialize = deinitialize;
	return true;
}
