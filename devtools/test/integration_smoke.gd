# Headless compatibility checks for the fork API. This does not render, bake
# probes, load NVIDIA runtime DLLs, or claim GPU/SDK functionality was tested.
extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("UPGRADE_SMOKE FAIL: ", message)


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property.name == property_name:
			return true
	return false


func _constant(engine_class: String, constant_name: String, expected: int) -> void:
	var exists := ClassDB.class_has_integer_constant(engine_class, constant_name)
	_expect(exists, "%s.%s remains registered" % [engine_class, constant_name])
	if exists:
		_expect(ClassDB.class_get_integer_constant(engine_class, constant_name) == expected,
			"%s.%s retains its serialized value" % [engine_class, constant_name])


func _optional_module(label: String, classes: Array[String], required: bool) -> void:
	var available := ClassDB.class_exists(classes[0])
	if required or available:
		for engine_class in classes:
			_expect(ClassDB.class_exists(engine_class), "%s class %s is registered" % [label, engine_class])
		print("UPGRADE_SMOKE MODULE ", label, ": API registration checked")
	else:
		print("UPGRADE_SMOKE SKIP ", label, ": module not compiled in")


func _check_streamline() -> void:
	var exists := Engine.has_singleton("Streamline")
	_expect(exists, "Streamline singleton remains available without SDK runtime")
	if not exists:
		return
	var streamline := Engine.get_singleton("Streamline")
	_expect(streamline.has_method("get_capability"), "Streamline capability query remains available")
	_expect(streamline.has_method("set_parameter"), "Streamline parameter API remains available")
	for constant_name in ["STREAMLINE_CAPABILITY_DLSS", "STREAMLINE_CAPABILITY_DLSS_G", "STREAMLINE_CAPABILITY_DLSS_RR", "STREAMLINE_CAPABILITY_REFLEX"]:
		var has_constant := ClassDB.class_has_integer_constant("Streamline", constant_name)
		_expect(has_constant, "Streamline.%s remains registered" % constant_name)
		if has_constant:
			var capability := ClassDB.class_get_integer_constant("Streamline", constant_name)
			var available: Variant = streamline.call("get_capability", capability)
			_expect(typeof(available) == TYPE_BOOL, "Streamline capability query returns a bool")
			# The runtime integration is disabled outside Windows; this exercises
			# its real no-SDK stub, without pretending to test Windows DLL loading.
			if OS.get_name() != "Windows":
				_expect(not available, "non-Windows Streamline capabilities safely report unavailable")
	for setting in ["reflex_mode", "reflex_frame_limit_us", "dlss_preset", "dlss_ray_reconstruction_preset"]:
		_expect(ProjectSettings.has_setting("rendering/streamline/" + setting), "Streamline setting %s exists" % setting)


func _check_environment_api(environment: Environment) -> void:
	var settings := {
		"pathtracing_enabled": true,
		"pathtracing_samples_per_pixel": 4,
		"pathtracing_max_bounces": 5,
		"pathtracing_denoiser": 1,
		"pathtracing_debug_mode": 1,
		"ddgi_enabled": true,
		"ddgi_cascades": 2,
		"ddgi_probe_spacing": 2.0,
		"ddgi_probe_grid": Vector3i(5, 4, 3),
		"ddgi_energy": 1.25,
		"ddgi_bounce_energy": 1.5,
		"ddgi_realtime_updates": true,
		"ddgi_follow_camera": false,
		"ddgi_debug_mode": 2,
	}
	for property_name in settings:
		if _has_property(environment, property_name):
			environment.set(property_name, settings[property_name])
			_expect(environment.get(property_name) == settings[property_name],
				"Environment.%s round trip" % property_name)
		else:
			_expect(false, "Environment.%s is registered" % property_name)
	# Do not request an actual path traced frame in a no-GPU test.
	environment.pathtracing_enabled = false
	environment.ddgi_enabled = false


func _check_ddgi() -> void:
	if not ClassDB.class_exists("DDGIVolume") or not ClassDB.class_exists("DDGIProbeData"):
		_expect(false, "DDGIVolume and DDGIProbeData remain registered")
		return
	var volume: Node3D = ClassDB.instantiate("DDGIVolume")
	var probe_data: Resource = ClassDB.instantiate("DDGIProbeData")
	_expect(volume.get("size") == Vector3(24, 12, 24), "DDGI default volume size")
	_expect(volume.get("probe_count") == Vector3i(25, 13, 25), "DDGI default probe count")
	_expect(volume.get("probe_relocation") and volume.get("probe_classification"),
		"DDGI relocation and classification defaults")
	_expect(volume.has_method("bake"), "DDGIVolume.bake remains available")
	volume.set("probe_spacing", 2.0)
	volume.set("probe_count", Vector3i(5, 4, 3))
	_expect(volume.get("size") == Vector3(8, 6, 4), "DDGI probe count updates volume size")
	_expect(volume.get("probe_count") == Vector3i(5, 4, 3), "DDGI count and size remain consistent")
	volume.set("follow_camera", true)
	_expect(volume.get("infinite_world"), "legacy follow_camera scene property still loads")
	volume.set("infinite_world", false)
	volume.set("cascades", 2)
	volume.set("bounce_energy", 1.5)
	volume.set("realtime_updates", true)
	volume.set("bake_mode", 2)
	volume.set("bake_least_squares", false)
	var data := {
		"cascades": 2,
		"probe_grid": Vector3i(5, 4, 3),
		"probe_spacing": 2.0,
		"center": Vector3(1, 2, 3),
		"test_payload": PackedByteArray([1, 2, 3, 255]),
	}
	probe_data.set("data", data)
	volume.set("probe_data", probe_data)
	_expect(probe_data.call("get_cascades") == 2, "DDGI baked resource cascades")
	_expect(probe_data.call("get_probe_grid") == Vector3i(5, 4, 3), "DDGI baked resource grid")
	_expect(probe_data.call("get_center") == Vector3(1, 2, 3), "DDGI baked resource center")

	# Exercise actual resource/scene save and reload, rather than just setters.
	volume.name = "Volume"
	var packed := PackedScene.new()
	_expect(packed.pack(volume) == OK, "DDGI scene can be packed")
	# Exported PCKs are read-only. Use an isolated user directory in every mode.
	var scene_path := "user://ddgi_roundtrip.tscn"
	var saved := ResourceSaver.save(packed, scene_path)
	_expect(saved == OK, "DDGI scene can be saved")
	if saved == OK:
		var loaded := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		_expect(loaded != null, "DDGI scene reloads")
		if loaded != null:
			var copy := loaded.instantiate()
			_expect(copy.get("size") == Vector3(8, 6, 4), "DDGI saved volume layout survives")
			_expect(copy.get("bake_mode") == 2, "DDGI baked+dynamic mode survives")
			_expect(not copy.get("bake_least_squares"), "DDGI solver setting survives")
			var copied_data: Resource = copy.get("probe_data")
			_expect(copied_data != null, "DDGI baked resource survives scene save")
			if copied_data != null:
				_expect(copied_data.get("data") == data, "DDGI baked dictionary survives scene save")
			copy.free()

	# Test entering a world, forwarding node settings, and disabling GI on exit.
	# Empty probe payloads are not uploaded to a renderer in this headless check.
	volume.set("bake_mode", 0)
	var scene := Node3D.new()
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	world_environment.environment = environment
	get_tree().root.add_child(scene)
	scene.add_child(world_environment)
	scene.add_child(volume)
	_expect(environment.ddgi_enabled, "DDGIVolume enables its world's environment")
	_expect(environment.ddgi_probe_grid == Vector3i(5, 4, 3), "DDGIVolume forwards probe grid")
	_expect(environment.ddgi_bounce_energy == 1.5, "DDGIVolume forwards bounce energy")
	_expect(environment.ddgi_realtime_updates, "DDGIVolume forwards realtime updates")
	volume.set("enabled", false)
	_expect(not environment.ddgi_enabled, "DDGI can be disabled at runtime")
	volume.set("enabled", true)
	_expect(environment.ddgi_enabled, "DDGI can be enabled again")
	scene.remove_child(volume)
	_expect(not environment.ddgi_enabled, "removing DDGIVolume disables GI")
	volume.free()
	scene.free()


func _run() -> void:
	var version := Engine.get_version_info()
	_expect(version.major == 4 and version.minor == 8, "engine is Godot 4.8")
	_expect(String(version.status).begins_with("beta"), "engine has beta version status")
	print("UPGRADE_SMOKE VERSION ", version.string)
	_constant("RenderingServer", "VIEWPORT_SCALING_3D_MODE_DLSS", 6)
	_constant("RenderingServer", "PT_DENOISER_DLSS_RAY_RECONSTRUCTION", 1)
	_constant("Environment", "DDGI_DEBUG_CASCADES", 6)
	_constant("DDGIVolume", "BAKE_MODE_BAKED_DYNAMIC", 2)
	for method_name in ["viewport_set_frame_generation", "environment_set_ddgi_volume", "environment_set_ddgi_baked_data", "viewport_get_ddgi_probe_data"]:
		_expect(RenderingServer.has_method(method_name), "RenderingServer.%s is available" % method_name)
	for setting in ["quality", "near_field_rays", "skip_moving_objects", "apply_resolution", "light_transition_time"]:
		_expect(ProjectSettings.has_setting("rendering/global_illumination/ddgi/" + setting), "DDGI setting %s exists" % setting)
	var viewport := SubViewport.new()
	_expect(_has_property(viewport, "frame_generation"), "Viewport frame_generation remains registered")
	viewport.set("frame_generation", true)
	_expect(viewport.get("frame_generation"), "Viewport frame_generation round trip")
	viewport.free()
	_check_environment_api(Environment.new())
	_check_streamline()
	_check_ddgi()
	var arguments := OS.get_cmdline_user_args()
	_optional_module("PhysX", ["PhysXParticleFluid3D", "PhysXCloth3D", "PhysXVehicle3D", "PhysXWaterSurface3D"], "--require-physx" in arguments)
	_optional_module("Blast", ["PhysXDestructible3D", "PhysXBlastAsset"], "--require-blast" in arguments)
	_optional_module("Flow", ["PhysXFlow3D", "PhysXFlowEmitter3D"], "--require-flow" in arguments)
	_optional_module("CSharp", ["CSharpScript"], "--require-mono" in arguments)
	if _failures.is_empty():
		print("UPGRADE_SMOKE PASS checks=", _checks)
		get_tree().quit(0)
	else:
		printerr("UPGRADE_SMOKE FAILED checks=", _checks, " failures=", _failures.size())
		get_tree().quit(1)
