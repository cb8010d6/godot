extends SceneTree
## Private native red/green seam. Baseline --mm-path=merged, candidate --mm-path=expanded.
## Pixel/color checks are identical for both routes. No RR/DDGI/DLSS or emission.

const SIZE := Vector2i(640, 360)
const DEADLINE_MS := 160000
var args: Dictionary = {}
var scene: Node3D
var geometry: Node3D
var camera: Camera3D
var environment: Environment
var material: StandardMaterial3D
var multimesh: MultiMesh
var reference: MeshInstance3D
var output: String
var started_ms: int
var all_passed: bool = true
var mm_path: String = "expanded"
var phases: Array[Dictionary] = []
var driver_info: PackedStringArray

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() == 2 else "1"
	_run.call_deferred()

func _run() -> void:
	mm_path = str(args.get("mm-path", "expanded"))
	if not args.has("output") or mm_path not in ["merged", "expanded"]:
		push_error("Required --output=<new directory>; --mm-path=merged|expanded")
		quit(2)
		return
	output = str(args["output"])
	if DirAccess.dir_exists_absolute(output) or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Evidence output must be new and writable")
		quit(2)
		return
	started_ms = Time.get_ticks_msec()
	_build_scene()
	_clear_geometry()
	material = _color_material(false)
	var strips: MeshInstance3D = MeshInstance3D.new()
	strips.mesh = _strips_mesh()
	strips.material_override = material
	geometry.add_child(strips)
	if not await _phase("00_mesh_green_white_vertex_strips", 300, "strips"):
		await _finish()
		return
	_build_mm(false, false)
	if not await _phase("01_multimesh_rgb_linear", 180, "rgb"):
		await _finish()
		return
	_build_mm(false, true)
	if not await _phase("02_multimesh_midgray_linear", 180, "constant"):
		await _finish()
		return
	_build_mm(true, true)
	await _phase("03_multimesh_midgray_srgb", 180, "constant")
	await _finish()

func _build_scene() -> void:
	driver_info = OS.get_video_adapter_driver_info()
	Engine.max_fps = 60
	root.size = SIZE
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 1.0
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.02)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.set("pathtracing_enabled", true)
	environment.set("pathtracing_samples_per_pixel", 4)
	environment.set("pathtracing_max_bounces", 2)
	environment.set("pathtracing_denoiser", 0)
	environment.set("ddgi_enabled", false)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -25, 0)
	sun.light_energy = 0.5
	scene.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 0, 8)
	scene.add_child(camera)
	camera.current = true

func _clear_geometry() -> void:
	if is_instance_valid(geometry):
		geometry.queue_free()
	geometry = Node3D.new()
	scene.add_child(geometry)
	multimesh = null
	reference = null

func _color_material(srgb: bool) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = srgb
	result.albedo_color = Color.WHITE
	result.roughness = 1.0
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _strips_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors: Array[Color] = [Color(0.05, 0.65, 0.12), Color(0.8, 0.8, 0.8)]
	for index: int in range(2):
		var x: float = -0.7 if index == 0 else 0.7
		var points: Array[Vector3] = [Vector3(x - 0.6, -0.7, 0), Vector3(x - 0.6, 0.7, 0), Vector3(x + 0.6, 0.7, 0), Vector3(x + 0.6, -0.7, 0)]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3.BACK)
			surface.set_color(colors[index])
			surface.set_uv(Vector2.ZERO)
			surface.add_vertex(points[corner])
	return surface.commit()

func _build_mm(srgb: bool, constant: bool) -> void:
	_clear_geometry()
	material = _color_material(srgb)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = 3
	var colors: Array[Color] = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]
	for index: int in range(3):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3((index - 1) * 2, 0.65, 0)))
		multimesh.set_instance_color(index, Color(0.5, 0.5, 0.5) if constant else colors[index])
	var instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instances.multimesh = multimesh
	geometry.add_child(instances)
	if constant:
		# Independent HG0 reference: source_color albedo converts sRGB to linear.
		# Match the actual shader contract, rather than accepting any gray output.
		var reference_material: StandardMaterial3D = StandardMaterial3D.new()
		reference_material.albedo_color = Color(0.5, 0.5, 0.5) if srgb else Color(0.5, 0.5, 0.5).linear_to_srgb()
		reference_material.roughness = 1.0
		reference_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var reference_mesh: QuadMesh = QuadMesh.new()
		reference_mesh.size = Vector2(0.9, 0.7)
		reference_mesh.material = reference_material
		reference = MeshInstance3D.new()
		reference.mesh = reference_mesh
		reference.position = Vector3(0, -1.0, 0)
		geometry.add_child(reference)

func _phase(name: String, waits: int, kind: String) -> bool:
	var first_draw: int = Engine.get_frames_drawn()
	for _frame: int in range(waits):
		await process_frame
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() - started_ms > DEADLINE_MS:
			all_passed = false
			var timeout: Dictionary = {"phase": name, "timeout": true, "elapsed_ms": Time.get_ticks_msec() - started_ms}
			phases.append(timeout)
			_write_json(output.path_join(name + "-timeout.json"), timeout)
			return false
	var image: Image = root.get_texture().get_image()
	var samples: Array[Dictionary] = []
	if kind == "strips":
		_dominant_sample(image, samples, Vector3(-0.7, 0, 0), 1, "green_strip")
		var white: Dictionary = _pixel(image, Vector3(0.7, 0, 0), "white_strip")
		var rgb: Array = white["rgb"]
		white["passed"] = bool(white["in_bounds"]) and minf(float(rgb[0]), minf(float(rgb[1]), float(rgb[2]))) > 0.1 and maxf(float(rgb[0]), maxf(float(rgb[1]), float(rgb[2]))) - minf(float(rgb[0]), minf(float(rgb[1]), float(rgb[2]))) < 0.08
		white["expected"] = "lit_neutral_white_strip"
		samples.append(white)
	elif kind == "rgb":
		for index: int in range(3):
			_dominant_sample(image, samples, Vector3((index - 1) * 2, 0.65, 0), index, "instance_" + str(index))
	else:
		var ref: Dictionary = _pixel(image, Vector3(0, -1, 0), "independent_hg0_reference")
		var ref_rgb: Array = ref["rgb"]
		var reference_lit: bool = bool(ref["in_bounds"]) and minf(float(ref_rgb[0]), minf(float(ref_rgb[1]), float(ref_rgb[2]))) > 0.1
		ref["passed"] = reference_lit
		ref["expected"] = "independent_non_vertex_color_reference_is_lit"
		samples.append(ref)
		for index: int in range(3):
			var sample: Dictionary = _pixel(image, Vector3((index - 1) * 2, 0.65, 0), "instance_" + str(index))
			var rgb: Array = sample["rgb"]
			var maximum_error: float = 0.0
			for channel: int in range(3):
				maximum_error = maxf(maximum_error, absf(float(rgb[channel]) - float(ref_rgb[channel])))
			sample["max_rgb_reference_error"] = maximum_error
			sample["expected"] = "matches_independent_hg0_reference_within_0.045_per_channel"
			sample["passed"] = bool(sample["in_bounds"]) and reference_lit and maximum_error <= 0.045
			samples.append(sample)
	var background: Dictionary = _pixel(image, Vector3(3.3, -1.0, 0), "background")
	var bg: Array = background["rgb"]
	background["expected"] = "background_max_rgb_below_0.25"
	background["passed"] = bool(background["in_bounds"]) and maxf(float(bg[0]), maxf(float(bg[1]), float(bg[2]))) < 0.25
	samples.append(background)
	var pixels_passed: bool = true
	for sample: Dictionary in samples:
		pixels_passed = pixels_passed and bool(sample["passed"])
	var expected_tlas: int = 1 if kind == "strips" else ((1 if mm_path == "merged" else 3) + (1 if kind == "constant" else 0))
	var actual_tlas: int = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_RT_TLAS_INSTANCES)
	var config_passed: bool = RenderingServer.get_current_rendering_driver_name() == "vulkan" and bool(environment.get("pathtracing_enabled")) and int(environment.get("pathtracing_denoiser")) == 0 and not bool(environment.get("ddgi_enabled")) and ProjectSettings.get_setting("rendering/pathtracing/async_shader_compilation") == false and root.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR and root.scaling_3d_scale == 1.0 and root.size == SIZE and material.vertex_color_use_as_albedo and not material.emission_enabled and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	var image_error: Error = image.save_png(output.path_join(name + ".png"))
	var phase_passed: bool = pixels_passed and config_passed and actual_tlas == expected_tlas and image_error == OK
	var record: Dictionary = {"phase": name, "kind": kind, "samples": samples, "pixels_passed": pixels_passed, "config_passed": config_passed,
		"expected_mm_path": mm_path, "expected_tlas_instances": expected_tlas, "actual_tlas_instances": actual_tlas,
		"waited_post_draws": waits, "drawn_frame_delta": Engine.get_frames_drawn() - first_draw,
		"elapsed_ms": Time.get_ticks_msec() - started_ms, "image_save_error": image_error, "phase_passed": phase_passed,
		"material": {"vertex_color_use_as_albedo": material.vertex_color_use_as_albedo, "vertex_color_is_srgb": material.vertex_color_is_srgb,
			"albedo": [material.albedo_color.r, material.albedo_color.g, material.albedo_color.b], "emission_enabled": material.emission_enabled}, "runtime": _runtime()}
	all_passed = _write_json(output.path_join(name + ".json"), record) and phase_passed and all_passed
	phases.append(record)
	print("STANDARD_COLOR_PHASE " + JSON.stringify(record))
	return true

func _pixel(image: Image, world: Vector3, label: String) -> Dictionary:
	var screen: Vector2 = camera.unproject_position(world)
	var position: Vector2i = Vector2i(int(screen.x), int(screen.y))
	var in_bounds: bool = position.x >= 0 and position.y >= 0 and position.x < image.get_width() and position.y < image.get_height()
	var color: Color = image.get_pixelv(position) if in_bounds else Color(-1, -1, -1)
	return {"label": label, "world": [world.x, world.y, world.z], "pixel": [position.x, position.y], "rgb": [color.r, color.g, color.b], "in_bounds": in_bounds}

func _dominant_sample(image: Image, samples: Array[Dictionary], world: Vector3, channel: int, label: String) -> void:
	var sample: Dictionary = _pixel(image, world, label)
	var rgb: Array = sample["rgb"]
	var passed: bool = bool(sample["in_bounds"]) and float(rgb[channel]) > 0.1
	for other: int in range(3):
		if other != channel:
			passed = passed and float(rgb[channel]) > float(rgb[other]) * 1.8 + 0.03
	sample["passed"] = passed
	sample["expected"] = "dominant_channel_" + str(channel)
	samples.append(sample)

func _runtime() -> Dictionary:
	return {"engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(), "driver": driver_info,
		"api": RenderingServer.get_current_rendering_driver_name(), "api_version": RenderingServer.get_video_adapter_api_version(),
		"fixture_sha256": FileAccess.get_sha256((get_script() as Script).resource_path), "resolution": [root.size.x, root.size.y],
		"pt": environment.get("pathtracing_enabled"), "rr": environment.get("pathtracing_denoiser"), "ddgi": environment.get("ddgi_enabled"),
		"async_shader_compilation": ProjectSettings.get_setting("rendering/pathtracing/async_shader_compilation")}

func _write_json(path: String, value: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write evidence JSON: " + path)
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK

func _finish() -> void:
	all_passed = _write_json(output.path_join("summary.json"), {"phases": phases, "runtime": _runtime(), "all_checks_passed": all_passed,
		"requested_exit_code": 0 if all_passed else 1}) and all_passed
	current_scene = null
	scene.queue_free()
	for _frame: int in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	print("STANDARD_COLOR_EXIT " + str(0 if all_passed else 1))
	quit(0 if all_passed else 1)
