# Actual rendered policy/lifecycle test. sdk_enabled is not presented-frame proof.
extends Node3D

var _scenario := "single"
var _output := "user://fg_viewports.json"
var _expected_backend := ""
var _expect_unavailable := false
var _children: Array[Node] = []
var _main_camera: Camera3D
var _rows: Array[Dictionary] = []
var _failed := false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			_scenario = argument.trim_prefix("--scenario=")
		elif argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		elif argument.begins_with("--expected-backend="):
			_expected_backend = argument.trim_prefix("--expected-backend=")
		elif argument == "--expect-unavailable":
			_expect_unavailable = true
		else:
			push_error("Unknown argument: " + argument)
			get_tree().quit(2)
			return
	if not _expected_backend.is_empty() and RenderingServer.get_current_rendering_driver_name() != _expected_backend:
		push_error("Requested backend did not start")
		get_tree().quit(2)
		return
	if not _expect_unavailable and not Streamline.get_capability(Streamline.STREAMLINE_CAPABILITY_DLSS_G):
		push_error("Real Frame Generation runtime is unavailable; GPU policy test was not run")
		get_tree().quit(2)
		return
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.7, 1.0)
	box.material_override = material
	add_child(box)
	_main_camera = _camera(self)
	_configure(get_tree().root)
	Streamline.set_parameter(Streamline.STREAMLINE_PARAM_REFLEX_MODE, 1.0)
	_run.call_deferred()


func _camera(parent: Node) -> Camera3D:
	var camera := Camera3D.new()
	parent.add_child(camera)
	camera.position = Vector3(0, 0.6, 4)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	return camera


func _configure(viewport: Viewport) -> void:
	viewport.fsr_sharpness = 0.0
	viewport.frame_generation = true
	if Streamline.get_capability(Streamline.STREAMLINE_CAPABILITY_DLSS):
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_DLSS
		viewport.scaling_3d_scale = 2.0 / 3.0


func _subviews(count: int, hud_only: bool = false) -> void:
	for index in range(count):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 180)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		_children.append(viewport)
		if hud_only:
			var label := Label.new()
			label.text = "2D HUD policy control"
			viewport.add_child(label)
		else:
			_camera(viewport)
			_configure(viewport)
		var rectangle := TextureRect.new()
		rectangle.texture = viewport.get_texture()
		rectangle.position = Vector2((index % 2) * 320, floori(index / 2.0) * 180)
		rectangle.size = Vector2(320, 180)
		add_child(rectangle)
		_children.append(rectangle)


func _clear_children() -> void:
	for child in _children:
		child.queue_free()
	_children.clear()


func _sample(label: String, expected_reason: String) -> void:
	for frame in range(220):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if frame >= 200:
			var status: Dictionary = Streamline.get_frame_generation_status()
			_rows.append({"label": label, "engine_frame": Engine.get_frames_drawn(), "status": status})
			var expected := "unavailable" if _expect_unavailable else expected_reason
			if status.get("reason") != expected:
				_failed = true
			if expected != "ready" and status.get("sdk_enabled", false):
				_failed = true
			if expected == "ready" and not status.get("sdk_enabled", false):
				_failed = true
	print("FG_POLICY_SAMPLE ", label, " ", JSON.stringify(Streamline.get_frame_generation_status()))


func _run() -> void:
	match _scenario:
		"single":
			await _sample("single", "ready")
		"hud":
			_subviews(1, true)
			await _sample("main_plus_2d_hud", "ready")
		"main_plus_sub":
			_subviews(1)
			await _sample("main_plus_sub", "multiple_3d_views")
		"one_sub", "two_sub", "four_sub":
			_main_camera.queue_free()
			_subviews({"one_sub": 1, "two_sub": 2, "four_sub": 4}[_scenario])
			await _sample(_scenario, "offscreen_viewport" if _scenario == "one_sub" else "multiple_3d_views")
		"dynamic":
			await _sample("main_before", "ready")
			_subviews(1)
			await _sample("added_sub", "multiple_3d_views")
			_clear_children()
			await _sample("main_after_destroy", "ready")
		"resize":
			for size in [Vector2i(640, 360), Vector2i(810, 720), Vector2i(960, 540)]:
				get_tree().root.size = size
				await _sample(str(size), "ready")
		_:
			push_error("Unknown scenario: " + _scenario)
			get_tree().quit(2)
			return
	var report := {
		"engine": Engine.get_version_info(), "actual_backend": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "scenario": _scenario, "samples": _rows,
		"fallback_only": _expect_unavailable, "failed": _failed,
		"scope": "rendered eligibility and cached SDK options; no generated-frame visual or latency acceptance",
	}
	var file := FileAccess.open(_output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write policy evidence")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	if _failed:
		push_error("Frame Generation viewport policy regression")
	get_tree().quit(1 if _failed else 0)
