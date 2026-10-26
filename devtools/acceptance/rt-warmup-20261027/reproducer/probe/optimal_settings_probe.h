#pragma once

// Test-only read-only SDK query. Included after the pinned public SL headers.
// The caller must use Godot's render thread because these SDK getters are not
// thread safe. No SetOptions, feature evaluation, driver writes, or overrides.
#include <cmath>
#include <iomanip>

static const char *optimal_mode_name(sl::DLSSMode mode) {
	switch (mode) {
		case sl::DLSSMode::eOff: return "off";
		case sl::DLSSMode::eMaxPerformance: return "performance";
		case sl::DLSSMode::eBalanced: return "balanced";
		case sl::DLSSMode::eMaxQuality: return "quality";
		case sl::DLSSMode::eUltraPerformance: return "ultra_performance";
		case sl::DLSSMode::eUltraQuality: return "ultra_quality";
		case sl::DLSSMode::eDLAA: return "dlaa";
		default: return "unknown";
	}
}

template <typename Settings>
static void append_optimal_row(std::ostringstream &out, sl::DLSSMode mode,
		sl::Result result, const Settings &settings, int preset) {
	const bool bounds_well_formed = settings.renderWidthMin > 0 && settings.renderHeightMin > 0 &&
		settings.renderWidthMin <= settings.renderWidthMax && settings.renderHeightMin <= settings.renderHeightMax;
	const bool optimal_inside = bounds_well_formed &&
		settings.optimalRenderWidth >= settings.renderWidthMin && settings.optimalRenderWidth <= settings.renderWidthMax &&
		settings.optimalRenderHeight >= settings.renderHeightMin && settings.optimalRenderHeight <= settings.renderHeightMax;
	out << "{\"mode\":" << static_cast<unsigned int>(mode) << ",\"mode_name\":\"" << optimal_mode_name(mode)
		<< "\",\"preset\":" << preset << ",\"result\":" << static_cast<int>(result)
		<< ",\"godot_candidate\":" << ((mode != sl::DLSSMode::eOff && mode != sl::DLSSMode::eUltraQuality) ? "true" : "false")
		<< ",\"optimal_width\":" << settings.optimalRenderWidth << ",\"optimal_height\":" << settings.optimalRenderHeight
		<< ",\"width_min\":" << settings.renderWidthMin << ",\"height_min\":" << settings.renderHeightMin
		<< ",\"width_max\":" << settings.renderWidthMax << ",\"height_max\":" << settings.renderHeightMax
		<< ",\"bounds_well_formed\":" << (bounds_well_formed ? "true" : "false")
		<< ",\"optimal_inside_bounds\":" << (optimal_inside ? "true" : "false")
		<< ",\"usable_active_mode\":" << ((result == sl::Result::eOk && mode != sl::DLSSMode::eOff && optimal_inside) ? "true" : "false");
	// Use the same single-precision multiply and ceil as RendererViewport.
	const float scales[] = { 1.0f, 2.0f / 3.0f, 0.58f, 0.5f, 1.0f / 3.0f };
	const char *names[] = { "dlaa", "quality", "balanced", "performance", "ultra_performance" };
	out << ",\"godot_inputs\":[";
	for (size_t i = 0; i < 5; ++i) {
		const unsigned int width = static_cast<unsigned int>(std::ceil(2560.0f * scales[i]));
		const unsigned int height = static_cast<unsigned int>(std::ceil(1440.0f * scales[i]));
		const bool contained = bounds_well_formed && width >= settings.renderWidthMin && width <= settings.renderWidthMax &&
			height >= settings.renderHeightMin && height <= settings.renderHeightMax;
		if (i) { out << ','; }
		out << "{\"name\":\"" << names[i] << "\",\"scale_f32\":" << std::setprecision(17) << scales[i]
			<< ",\"width\":" << width << ",\"height\":" << height
			<< ",\"inside_bounds\":" << (contained ? "true" : "false") << '}';
	}
	out << "]}";
}

static std::string optimal_settings_snapshot(PFun_slGetFeatureFunction *get_function) {
	std::ostringstream out;
	out << "{\"schema\":1,\"read_only\":true,\"output_width\":2560,\"output_height\":1440"
		<< ",\"thread_id\":" << GetCurrentThreadId()
		<< ",\"query_options\":\"default constructed; output/mode and named SR preset slots only\"";
	if (!get_function) { return out.str() + ",\"getter_available\":false}"; }
	void *sr_function = nullptr;
	void *rr_function = nullptr;
	const sl::Result sr_import = get_function(sl::kFeatureDLSS, "slDLSSGetOptimalSettings", sr_function);
	const sl::Result rr_import = get_function(sl::kFeatureDLSS_RR, "slDLSSDGetOptimalSettings", rr_function);
	out << ",\"sr_import_result\":" << static_cast<int>(sr_import)
		<< ",\"rr_import_result\":" << static_cast<int>(rr_import) << ",\"sr\":[";
	const sl::DLSSMode modes[] = { sl::DLSSMode::eOff, sl::DLSSMode::eMaxPerformance, sl::DLSSMode::eBalanced,
		sl::DLSSMode::eMaxQuality, sl::DLSSMode::eUltraPerformance, sl::DLSSMode::eUltraQuality, sl::DLSSMode::eDLAA };
	bool first = true;
	if (sr_import == sl::Result::eOk && sr_function) {
		for (sl::DLSSPreset preset : { sl::DLSSPreset::eDefault, sl::DLSSPreset::ePresetK, sl::DLSSPreset::ePresetL, sl::DLSSPreset::ePresetM }) {
			for (sl::DLSSMode mode : modes) {
				sl::DLSSOptions options{};
				options.mode = mode;
				options.outputWidth = 2560;
				options.outputHeight = 1440;
				options.dlaaPreset = preset;
				options.qualityPreset = preset;
				options.balancedPreset = preset;
				options.performancePreset = preset;
				options.ultraPerformancePreset = preset;
				options.ultraQualityPreset = preset;
				sl::DLSSOptimalSettings settings{};
				const sl::Result result = reinterpret_cast<PFun_slDLSSGetOptimalSettings *>(sr_function)(options, settings);
				if (!first) { out << ','; } first = false;
				append_optimal_row(out, mode, result, settings, static_cast<int>(preset));
			}
		}
	}
	out << "],\"rr\":[";
	first = true;
	if (rr_import == sl::Result::eOk && rr_function) {
		for (sl::DLSSMode mode : modes) {
			sl::DLSSDOptions options{};
			options.mode = mode;
			options.outputWidth = 2560;
			options.outputHeight = 1440;
			sl::DLSSDOptimalSettings settings{};
			const sl::Result result = reinterpret_cast<PFun_slDLSSDGetOptimalSettings *>(rr_function)(options, settings);
			if (!first) { out << ','; } first = false;
			append_optimal_row(out, mode, result, settings, 0);
		}
	}
	out << "]}";
	return out.str();
}
