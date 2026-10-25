extends "res://test_base.gd"

var destination: String
var state_rows: Array = []
var second: SubViewport
var second_camera: Camera3D
var moving: MeshInstance3D
var observer: Object
signal sampled

func _ready() -> void:
	super._ready()
	destination = args.get("output", "")
	DirAccess.make_dir_recursive_absolute(destination)
	hud.hide()
	observer = ClassDB.instantiate("RTXAcceptanceProbe")
	_run_checks.call_deferred()

func _sample() -> void:
	state_rows.append(JSON.parse_string(observer.call("read_state")))
	_notify.call_deferred()

func _notify() -> void:
	sampled.emit()

func _wait(frames: int, animate: bool = false) -> void:
	for f in range(frames):
		if animate:
			camera.position.x += 0.002
			moving.position.x += 0.004 * sin(f * 0.1)
		await RenderingServer.frame_post_draw

func _capture(label: String) -> void:
	var error := get_viewport().get_texture().get_image().save_png(destination.path_join(label + ".png"))
	if error != OK:
		push_error("Screenshot failed: " + str(error))
	RenderingServer.call_on_render_thread(_sample)
	await sampled
	print("RR_CASE ", label, " denoiser=", env.pathtracing_denoiser, " driver=", RenderingServer.get_current_rendering_driver_name())

func _run_checks() -> void:
	print("RR_REAL_GPU ", JSON.stringify({"engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_driver_name(), "sr": Streamline.get_capability(0), "rr": Streamline.get_capability(1), "editor_hint": Engine.is_editor_hint()}))
	if not Streamline.get_capability(1):
		push_error("RR unavailable")
		get_tree().quit(3)
		return
	get_tree().root.size = Vector2i(960, 540)
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_DLSS
	get_viewport().scaling_3d_scale = 2.0 / 3.0
	env.pathtracing_enabled = true
	env.pathtracing_samples_per_pixel = 1
	moving = MeshInstance3D.new()
	moving.mesh = SphereMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 1.0, 0.1)
	moving.material_override = material
	add_child(moving)
	for selected in ["glass", "emissive", "shaders", "lighting"]:
		_set_view(selected)
		moving.position = VIEWS[selected][1] + Vector3(0, 0.2, 0)
		for enabled in [0, 1, 0, 1]:
			env.pathtracing_denoiser = enabled
			await _wait(160, true)
			await _capture(selected + "_rr%d_frame%d" % [enabled, Engine.get_frames_drawn()])
	_set_view("glass")
	for preset in ["D", "E", "F"]:
		Streamline.set_parameter(Streamline.STREAMLINE_PARAM_DLSS_RR_PRESET, preset)
		await _wait(160)
		await _capture("rr_requested_preset_" + preset)
	for guide in [Viewport.DEBUG_DRAW_DLSS_RR_DIFFUSE_ALBEDO, Viewport.DEBUG_DRAW_DLSS_RR_SPECULAR_ALBEDO, Viewport.DEBUG_DRAW_DLSS_RR_NORMAL_ROUGHNESS, Viewport.DEBUG_DRAW_DLSS_RR_SPECULAR_HIT_DIST, Viewport.DEBUG_DRAW_MOTION_VECTORS, Viewport.DEBUG_DRAW_RECONSTRUCTED_DEPTH]:
		get_viewport().debug_draw = guide
		await _wait(80)
		await _capture("guide_%d" % guide)
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	second = SubViewport.new()
	second.size = Vector2i(320, 180)
	second.world_3d = get_world_3d()
	second.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	second.scaling_3d_mode = Viewport.SCALING_3D_MODE_DLSS
	second.scaling_3d_scale = 2.0 / 3.0
	add_child(second)
	second_camera = Camera3D.new()
	second.add_child(second_camera)
	second_camera.global_transform = camera.global_transform
	second_camera.current = true
	await _wait(240)
	second.get_texture().get_image().save_png(destination.path_join("second_viewport.png"))
	await _capture("two_viewports")
	get_tree().root.size = Vector2i(700, 900)
	second.size = Vector2i(500, 260)
	await _wait(180, true)
	await _capture("portrait_resize")
	second.queue_free()
	await _wait(40)
	env.pathtracing_enabled = false
	await _wait(120)
	await _capture("raster_after_rr")
	FileAccess.open(destination.path_join("sdk-state.json"), FileAccess.WRITE).store_string(JSON.stringify(state_rows, "\t"))
	observer.free()
	print("RR_SUITE_FINISHED captures=", state_rows.size())
	get_tree().quit()
