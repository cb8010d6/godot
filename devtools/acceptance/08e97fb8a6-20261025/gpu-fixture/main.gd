extends Node3D

var output := ""
var test_mode := "native"
var active_mode := "native"
var suite := "motion"
var expected_sdk := true
var sr_preset := "?"
var rr_preset := "?"
var warmup := 140
var wait_foreground := false
var requested_size := Vector2i(960, 540)
var requested_sharpness := 0.2
var marker: MeshInstance3D
var camera: Camera3D
var environment: Environment
var results: Array = []
var root: Window
var probe: Object
var probe_rows: Array = []
var probe_mutex := Mutex.new()
var probe_sampling := false
signal probe_idle


func _ready() -> void:
	root = get_tree().root
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--mode="):
			test_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--suite="):
			suite = argument.trim_prefix("--suite=")
		elif argument == "--expect-no-sdk":
			expected_sdk = false
		elif argument.begins_with("--preset="):
			sr_preset = argument.trim_prefix("--preset=")
		elif argument.begins_with("--rr-preset="):
			rr_preset = argument.trim_prefix("--rr-preset=")
		elif argument.begins_with("--warmup="):
			warmup = int(argument.trim_prefix("--warmup="))
		elif argument == "--wait-foreground":
			wait_foreground = true
		elif argument.begins_with("--res="):
			var dimensions := argument.trim_prefix("--res=").split("x")
			requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument.begins_with("--sharpness="):
			requested_sharpness = float(argument.trim_prefix("--sharpness="))
	if suite == "scene_restart":
		var cycle: int = int(root.get_meta("acceptance_scene_cycle", 0))
		output = output.path_join("scene_%d" % cycle)
		requested_size = Vector2i(810, 720) if cycle % 2 == 1 else Vector2i(960, 540)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if probe_sampling:
			RenderingServer.call_on_render_thread(_sample_probe.bind(Engine.get_frames_drawn(), active_mode, root.has_focus()))


func _sample_probe(frame: int, requested_mode: String, focused: bool) -> void:
	var payload: Variant = JSON.parse_string(probe.call("read_state"))
	if payload is Dictionary:
		payload["engine_frame"] = frame
		payload["requested_mode"] = requested_mode
		payload["window_focused"] = focused
		probe_mutex.lock()
		probe_rows.append(payload)
		probe_mutex.unlock()


func _probe_barrier() -> void:
	_probe_finished.call_deferred()


func _probe_finished() -> void:
	probe_idle.emit()


func _set_mode(selected: String) -> void:
	active_mode = selected
	root.frame_generation = false
	root.use_taa = false
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 1.0
	match selected:
		"taa":
			root.use_taa = true
		"fsr2":
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			root.scaling_3d_scale = 2.0 / 3.0
		"quality", "balanced", "performance", "dlaa", "fg", "rr":
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_DLSS
			root.scaling_3d_scale = {"quality": 2.0 / 3.0, "balanced": 0.58,
				"performance": 0.5, "dlaa": 1.0, "fg": 2.0 / 3.0, "rr": 2.0 / 3.0}[selected]
			root.frame_generation = selected == "fg"
	environment.pathtracing_enabled = selected == "rr"
	environment.pathtracing_denoiser = 1 if selected == "rr" else 0
	Streamline.set_parameter(Streamline.STREAMLINE_PARAM_REFLEX_MODE, 1.0 if selected == "fg" else 0.0)
	Streamline.set_parameter(Streamline.STREAMLINE_PARAM_REFLEX_FRAME_LIMIT_US, 16666.0 if selected == "fg" else 0.0)


func _scene() -> void:
	var node := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.015, 0.015)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.pathtracing_samples_per_pixel = 1
	environment.pathtracing_max_bounces = 2
	node.environment = environment
	add_child(node)
	marker = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.6, 0.15)
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0, 0)
	marker.material_override = material
	add_child(marker)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0, 6)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = 60
	camera.near = 0.1
	camera.far = 100
	add_child(camera)
	camera.current = true


func _snapshot(label: String) -> Dictionary:
	var image := root.get_texture().get_image()
	var file := label + ".png"
	var code := image.save_png(output.path_join(file))
	if code != OK:
		push_error("Cannot save actual viewport: " + str(code))
		get_tree().quit(4)
	var point := camera.unproject_position(marker.global_position)
	return {"label": label, "file": file, "width": image.get_width(), "height": image.get_height(),
		"expected_xy": [point.x, point.y], "marker_x": marker.position.x,
		"frame": Engine.get_frames_drawn(), "mode": root.scaling_3d_mode,
		"scale": root.scaling_3d_scale, "fg_requested": root.frame_generation,
		"pt_requested": environment.pathtracing_enabled, "requested_mode": active_mode}


func _run() -> void:
	if output.is_empty():
		push_error("Provide --output=<evidence-directory>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var capabilities := {}
	for index in range(6):
		capabilities[str(index)] = Streamline.get_capability(index)
	var metadata := {"engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"capabilities": capabilities, "mode": test_mode, "suite": suite,
		"editor_hint": Engine.is_editor_hint(), "process_id": OS.get_process_id(),
		"requested_sr_preset": sr_preset, "requested_rr_preset": rr_preset}
	FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE).store_string(JSON.stringify(metadata, "\t"))
	print("GPU_ACCEPTANCE_METADATA ", JSON.stringify(metadata))
	if expected_sdk and test_mode in ["quality", "balanced", "performance", "dlaa", "rr", "fg"] and not capabilities["0"]:
		push_error("Requested real DLSS support is unavailable")
		get_tree().quit(3)
		return
	if not expected_sdk and (capabilities["0"] or capabilities["1"] or capabilities["2"]):
		push_error("Missing-runtime test unexpectedly advertises DLSS")
		get_tree().quit(3)
		return
	_scene()
	root.fsr_sharpness = requested_sharpness
	Streamline.set_parameter(Streamline.STREAMLINE_PARAM_DLSS_PRESET, sr_preset)
	Streamline.set_parameter(Streamline.STREAMLINE_PARAM_DLSS_RR_PRESET, rr_preset)
	if ClassDB.class_exists("RTXAcceptanceProbe"):
		probe = ClassDB.instantiate("RTXAcceptanceProbe")
		probe_sampling = true
	root.size = requested_size
	root.grab_focus()
	_set_mode(test_mode)
	if wait_foreground:
		print("GPU_ACCEPTANCE_WAITING_FOR_OS_FOREGROUND")
		var start := Time.get_ticks_msec()
		var foreground := false
		while not foreground and Time.get_ticks_msec() - start < 120000:
			await _frames(1)
			probe_mutex.lock()
			if not probe_rows.is_empty():
				var state: Dictionary = probe_rows.back()
				foreground = state.get("foreground_process_id", -1) == state.get("process_id", -2)
			probe_mutex.unlock()
		if not foreground:
			push_error("OS foreground verification timed out")
			get_tree().quit(7)
			return
		print("GPU_ACCEPTANCE_OS_FOREGROUND_CONFIRMED")
	await _frames(warmup)
	results.append(_snapshot("static"))
	if suite == "inspect":
		root.grab_focus()
		await _frames(7200)
		results.append(_snapshot("inspect_end"))
	elif suite == "lifecycle":
		for cycle in range(3):
			for selected in ["quality", "balanced", "performance", "dlaa", "fg", "quality", "native"]:
				_set_mode(selected)
				root.size = Vector2i(960, 540) if cycle % 2 == 0 else Vector2i(810, 720)
				root.grab_focus()
				if wait_foreground and selected == "fg":
					var start := Time.get_ticks_msec()
					var foreground := false
					while not foreground and Time.get_ticks_msec() - start < 120000:
						await _frames(1)
						probe_mutex.lock()
						if not probe_rows.is_empty():
							var state: Dictionary = probe_rows.back()
							foreground = state.get("foreground_process_id", -1) == state.get("process_id", -2)
						probe_mutex.unlock()
					if not foreground:
						push_error("FG cycle OS foreground verification timed out")
						get_tree().quit(7)
						return
				await _frames(maxi(140, warmup) if selected == "fg" else 140)
				results.append(_snapshot("cycle_%d_%s" % [cycle, selected]))
			marker.queue_free()
			await _frames(12)
			marker = MeshInstance3D.new()
			var mesh := SphereMesh.new()
			marker.mesh = mesh
			add_child(marker)
	elif suite in ["motion", "camera"]:
		for index in range(48):
			if suite == "camera":
				camera.position.x = -1.8 + index * 0.075
			else:
				marker.position.x = -1.8 + index * 0.075
			await _frames(1)
			results.append(_snapshot("motion_%03d" % index))
	FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	print("GPU_ACCEPTANCE_FINISHED actual_viewport_captures=", results.size())
	_set_mode("native")
	await _frames(12)
	if probe != null:
		probe_sampling = false
		RenderingServer.call_on_render_thread(_probe_barrier)
		await probe_idle
		FileAccess.open(output.path_join("sdk-state.json"), FileAccess.WRITE).store_string(JSON.stringify(probe_rows, "\t"))
		probe.free()
	if suite == "scene_restart":
		var cycle: int = int(root.get_meta("acceptance_scene_cycle", 0))
		if cycle < 2:
			root.set_meta("acceptance_scene_cycle", cycle + 1)
			var error := get_tree().change_scene_to_file("res://main.tscn")
			if error != OK:
				push_error("Scene replacement failed: " + str(error))
				get_tree().quit(8)
			return
	get_tree().quit(0)
