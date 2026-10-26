class_name RTReadinessRegression
extends SceneTree
## Actual release/editor RT statistics. A disabled second view must stay unready;
## both views must then record two fresh live-ready frames, including after reload.

const DEADLINE_MSEC := 120000
const INFO := ["RT_FRAME_SERIAL", "RT_DISPATCHES", "RT_TLAS_INSTANCES", "RT_SHADER_PENDING", "RT_SHADER_FAILED"]
var views: Array[SubViewport] = []
var materials: Array[ShaderMaterial] = []
var environments: Array[Environment] = []
var output := ""
var started := 0
var pending_observed := false
var phases: Array[Dictionary] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	_run.call_deferred()


func _run() -> void:
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Required new writable --output=<directory>")
		quit(2)
		return
	started = Time.get_ticks_msec()
	if not ClassDB.class_has_integer_constant("RenderingServer", "VIEWPORT_RENDER_INFO_RT_FRAME_SERIAL"):
		_finish("SKIP", "readiness_api_unavailable")
		return
	var rd := RenderingServer.get_rendering_device()
	if rd == null or not rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE):
		_finish("SKIP", "raytracing_unavailable")
		return
	root.size = Vector2i(640, 360)
	for index in 2:
		_build_view(index)
	views[1].render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not await _wait_ready([0], "first_view_only"):
		return
	if _snapshot(views[1])["serial"] != 0:
		_finish("FAIL", "disabled_view_recorded_a_dispatch")
		return
	views[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not await _wait_ready([0, 1], "both_views"):
		return
	# A different source must not inherit the old hit group's live-ready state.
	materials[0].shader = _shader("vec3(0.15, 0.25, 0.85)")
	if not await _wait_ready([0, 1], "changed_source"):
		return
	environments[0].set("pathtracing_samples_per_pixel", 2)
	if not await _wait_ready([0, 1], "changed_variant"):
		return
	if not await _expect_rt_failure():
		return
	_finish("PASS", "")


func _shader(color: String) -> Shader:
	var shader := Shader.new()
	shader.code = "shader_type spatial; void fragment() { ALBEDO = " + color + "; ROUGHNESS = 0.8; }"
	return shader


func _build_view(index: int) -> void:
	var container := SubViewportContainer.new()
	container.position = Vector2(320 * index, 0)
	container.size = Vector2(320, 360)
	container.stretch = true
	root.add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 360)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	views.append(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.08)
	env.set("pathtracing_enabled", true)
	env.set("pathtracing_samples_per_pixel", 1)
	env.set("pathtracing_max_bounces", 2)
	we.environment = env
	environments.append(env)
	world.add_child(we)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	world.add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.4, -0.5, 0)
	light.light_energy = 2.0
	world.add_child(light)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = _shader("vec3(0.15, 0.8, 0.2)")
	mesh.material_override = material
	materials.append(material)
	world.add_child(mesh)


func _snapshot(vp: Viewport) -> Dictionary:
	var values: Array[int] = []
	for name: String in INFO:
		var key := ClassDB.class_get_integer_constant("RenderingServer", "VIEWPORT_RENDER_INFO_" + name)
		values.append(RenderingServer.viewport_get_render_info(vp.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, key))
	var serial := RenderingServer.viewport_get_render_info(vp.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		ClassDB.class_get_integer_constant("RenderingServer", "VIEWPORT_RENDER_INFO_RT_FRAME_SERIAL"))
	return {"serial": serial, "coherent": serial == values[0], "dispatches": values[1], "tlas": values[2], "pending": values[3], "failed": values[4]}


func _wait_ready(indices: Array, name: String) -> bool:
	var previous: Dictionary = {}
	var counts: Dictionary = {}
	for index: int in indices:
		previous[index] = _snapshot(views[index])["serial"]
		counts[index] = 0
	while Time.get_ticks_msec() - started < DEADLINE_MSEC:
		await RenderingServer.frame_post_draw
		var samples: Array[Dictionary] = []
		var ready := true
		for index: int in indices:
			var sample := _snapshot(views[index])
			samples.append(sample)
			pending_observed = pending_observed or int(sample["pending"]) > 0
			if sample["coherent"] and int(sample["failed"]) > 0:
				_finish("FAIL", "shader_failed_" + name)
				return false
			var fresh: bool = sample["coherent"] and int(sample["serial"]) > 0 and sample["serial"] != previous[index]
			var valid: bool = fresh and int(sample["dispatches"]) > 0 and int(sample["tlas"]) > 0 and int(sample["pending"]) == 0
			if fresh:
				previous[index] = sample["serial"]
				counts[index] = int(counts[index]) + 1 if valid else 0
			ready = ready and valid and int(counts[index]) >= 2
		if ready:
			var image := root.get_texture().get_image()
			var saved := image.save_png(output.path_join(name + ".png"))
			var pixels: Array[Dictionary] = []
			var pixels_passed := true
			for index: int in indices:
				var viewport_image := views[index].get_texture().get_image()
				var color := viewport_image.get_pixelv(viewport_image.get_size() / 2)
				var blue := index == 0 and name in ["changed_source", "changed_variant"]
				var dominant: float = color.b if blue else color.g
				var other: float = maxf(color.r, color.g if blue else color.b)
				var passed := dominant > 0.08 and dominant > other * 1.15
				pixels.append({"view": index, "rgb": [color.r, color.g, color.b], "expected": "blue" if blue else "green", "passed": passed})
				pixels_passed = pixels_passed and passed
			phases.append({"phase": name, "samples": samples, "fresh_ready_counts": counts, "pixels": pixels, "pixels_passed": pixels_passed, "png_error": saved})
			if saved != OK or not pixels_passed:
				_finish("FAIL", "pixels_or_png_failed_" + name)
				return false
			return true
	_finish("FAIL", "timeout_" + name)
	return false


func _expect_rt_failure() -> bool:
	var invalid := Shader.new()
	# Raster stays valid; this intentionally reproduces RT-only front-end failure.
	invalid.code = "shader_type spatial;\nvoid fragment() {\n ALBEDO=vec3(0.2);\n#if defined(RT)\n ALBEDO=readiness_missing_identifier;\n#endif\n}\n"
	materials[0].shader = invalid
	var previous: int = _snapshot(views[0])["serial"]
	var false_ready_count := 0
	while Time.get_ticks_msec() - started < DEADLINE_MSEC:
		await RenderingServer.frame_post_draw
		var sample := _snapshot(views[0])
		if not sample["coherent"]:
			continue
		if int(sample["failed"]) > 0:
			phases.append({"phase": "intentional_rt_frontend_failure", "sample": sample, "failed_detected": int(sample["failed"]) > 0})
			return true
		if int(sample["serial"]) > 0 and sample["serial"] != previous:
			previous = sample["serial"]
			var ready: bool = int(sample["dispatches"]) > 0 and int(sample["tlas"]) > 0 and int(sample["pending"]) == 0
			false_ready_count = false_ready_count + 1 if ready else 0
			if false_ready_count >= 2:
				_finish("FAIL", "invalid_rt_source_became_ready")
				return false
	_finish("FAIL", "invalid_rt_source_failure_not_reported")
	return false


func _finish(status: String, reason: String) -> void:
	var result := {"status": status, "reason": reason, "engine": Engine.get_version_info(),
		"api": RenderingServer.get_current_rendering_driver_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"pending_observed": pending_observed, "elapsed_msec": Time.get_ticks_msec() - started, "phases": phases,
		"intentional_rt_error_phase": phases.any(func(phase: Dictionary) -> bool: return phase.get("phase") == "intentional_rt_frontend_failure"),
		"scope": "Recorded RT commands/live pipeline, not GPU fence, present, DLSS or FG verification"}
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("RT_READINESS: ", status, " ", reason)
	quit(0 if status in ["PASS", "SKIP"] else 1)
