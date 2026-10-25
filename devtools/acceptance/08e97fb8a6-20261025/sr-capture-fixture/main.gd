# This fixture records an application's SR preset request and scene execution.
# It cannot identify the resolved DLSS model, validate generated FG frames, or
# establish image quality. Use the native-test process wrapper on Windows.
extends Node3D

const SCALES := {
	"dlaa": 1.0,
	"quality": 0.6667,
	"balanced": 0.58,
	"performance": 0.5,
	"ultra_performance": 0.3333,
}
const PRESETS := ["Recommended", "?", "K", "L", "M"]
const REPORT_PATH := "user://dlss45_probe.json"

var _preset := "Recommended"
var _mode := "performance"
var _target_frames := 600
var _sharpness := 0.2
var _allow_unavailable := false
var _expected_backend := ""
var _frame := 0
var _running := false
var _report: Dictionary = {}
var _camera: Camera3D
var _moving_box: MeshInstance3D


func _ready() -> void:
	if not _parse_arguments():
		return
	var backend := RenderingServer.get_current_rendering_driver_name()
	var has_streamline := Engine.has_singleton("Streamline")
	var dlss_available := false
	if has_streamline:
		var streamline := Engine.get_singleton("Streamline")
		var capability := ClassDB.class_get_integer_constant("Streamline", "STREAMLINE_CAPABILITY_DLSS")
		dlss_available = streamline.call("get_capability", capability)
	_report = {
		"engine": Engine.get_version_info(),
		"os": OS.get_name(),
		"actual_backend": backend,
		"expected_backend": _expected_backend,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"requested_preset": _preset,
		"requested_mode": _mode,
		"requested_scale": SCALES[_mode],
		"requested_sharpness": _sharpness,
		"requested_frames": _target_frames,
		"frame_count_kind": "scene_process_updates",
		"streamline_singleton": has_streamline,
		"dlss_available": dlss_available,
		"allow_unavailable": _allow_unavailable,
		"active_model_confirmed": false,
		"frame_generation_requested": false,
		"ray_reconstruction_requested": false,
	}
	print("DLSS45_REQUEST ", JSON.stringify(_report))
	if not _expected_backend.is_empty() and backend != _expected_backend:
		_finish(1, "requested backend did not start")
		return
	if not has_streamline:
		_finish(1, "Streamline singleton is missing")
		return
	if not dlss_available and not _allow_unavailable:
		_finish(1, "DLSS is unavailable; GPU validation was not run")
		return
	var streamline := Engine.get_singleton("Streamline")
	var parameter := ClassDB.class_get_integer_constant("Streamline", "STREAMLINE_PARAM_DLSS_PRESET")
	streamline.call("set_parameter", parameter, _preset)
	var viewport := get_viewport()
	viewport.frame_generation = false
	viewport.fsr_sharpness = _sharpness
	if dlss_available:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_DLSS
		viewport.scaling_3d_scale = SCALES[_mode]
	else:
		# Keep the cloud/stub path free of unsupported render requests.
		print("DLSS45_UNAVAILABLE_ALLOWED no DLSS rendering or active-model validation")
	_build_scene()
	_running = true


func _parse_arguments() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--allow-unavailable":
			_allow_unavailable = true
		elif argument.begins_with("--preset="):
			_preset = argument.trim_prefix("--preset=")
		elif argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--frames="):
			var frames := argument.trim_prefix("--frames=")
			if not frames.is_valid_int() or frames.to_int() < 1:
				_finish(1, "--frames must be a positive integer")
				return false
			_target_frames = frames.to_int()
		elif argument.begins_with("--sharpness="):
			var sharpness := argument.trim_prefix("--sharpness=")
			if not sharpness.is_valid_float() or not is_finite(sharpness.to_float()) or sharpness.to_float() < 0.0 or sharpness.to_float() > 1.0:
				_finish(1, "--sharpness must be finite and between 0 and 1")
				return false
			_sharpness = sharpness.to_float()
		elif argument.begins_with("--expected-backend="):
			_expected_backend = argument.trim_prefix("--expected-backend=")
			if _expected_backend not in ["vulkan", "d3d12", "dummy"]:
				_finish(1, "--expected-backend must be vulkan, d3d12, or dummy")
				return false
		else:
			_finish(1, "unknown argument: " + argument)
			return false
	if _preset not in PRESETS or not SCALES.has(_mode):
		_finish(1, "invalid --preset or --mode")
		return false
	return true


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	return material


func _box(size: Vector3, location: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = location
	add_child(node)
	return node


func _build_scene() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.17, 0.23)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.75, 0.85)
	environment.ambient_light_energy = 0.5
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	add_child(sun)
	var dark := _material(Color(0.08, 0.1, 0.12))
	var pale := _material(Color(0.7, 0.7, 0.65))
	for x in range(-4, 4):
		for z in range(-4, 4):
			_box(Vector3(1.0, 0.1, 1.0), Vector3(x + 0.5, -0.1, z + 0.5), pale if (x + z) % 2 == 0 else dark)
	var blue := _material(Color(0.05, 0.25, 0.8))
	var warm := _material(Color(0.85, 0.2, 0.06))
	for index in range(15):
		_box(Vector3(0.025, 2.0, 0.025), Vector3((index - 7) * 0.22, 1.0, -2.0), pale)
	_box(Vector3(1.5, 1.5, 1.5), Vector3(-1.5, 0.7, 0), blue)
	_moving_box = _box(Vector3(0.7, 0.7, 0.7), Vector3(0, 0.7, 1), warm)
	_camera = Camera3D.new()
	_camera.fov = 75
	_camera.current = true
	add_child(_camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = "DLSS SR request: %s / %s\nActive model requires separate verification" % [_preset, _mode]
	canvas.add_child(label)
	_animate(0)


func _animate(frame: int) -> void:
	# Frame-based motion keeps camera/object poses comparable across runs.
	var t := frame / 60.0
	_camera.position = Vector3(sin(t * 0.4) * 2.5, 2.4, 7.0)
	_camera.look_at(Vector3(0, 0.7, 0))
	_moving_box.position.x = sin(t * 1.4) * 1.6
	_moving_box.rotation = Vector3(t * 0.5, t, 0)


func _process(_delta: float) -> void:
	if not _running:
		return
	_frame += 1
	_animate(_frame)
	if _frame == 240:
		var folder := OS.get_environment("GODOT_ACCEPTANCE_OUTPUT")
		DirAccess.make_dir_recursive_absolute(folder)
		get_viewport().get_texture().get_image().save_png(folder.path_join("application-frame.png"))
	if _frame >= _target_frames:
		_finish(0, "scene frame budget completed")


func _finish(exit_code: int, reason: String) -> void:
	_running = false
	_report["exit_code"] = exit_code
	_report["reason"] = reason
	_report["completed_frames"] = _frame
	_report["active_model_confirmed"] = false
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		printerr("DLSS45_RUN_FAILED could not write fixture metadata")
		exit_code = 1
		_report["exit_code"] = exit_code
	else:
		output.store_string(JSON.stringify(_report, "\t") + "\n")
		output.close()
	if exit_code == 0:
		print("DLSS45_RUN_COMPLETED ", JSON.stringify(_report))
	else:
		printerr("DLSS45_RUN_FAILED ", JSON.stringify(_report))
	get_tree().quit(exit_code)
