extends SceneTree
## Two owners share one MultiMesh. Observe real geometry under distinct materials
## and then under the same material with owner-transform-dependent vertex code.

const SIZE := Vector2i(640, 360)
const SHADER_CODE := """shader_type spatial;
render_mode cull_disabled;
uniform float material_y = 0.0;
uniform float world_x_scale = 0.0;
varying vec3 v_tint;
void vertex() {
	v_tint = MODEL_MATRIX[3].x < 0.0 ? vec3(1, 0, 0) : vec3(0, 0, 1);
	VERTEX.y += material_y + MODEL_MATRIX[3].x * world_x_scale;
}
void fragment() {
	ALBEDO = v_tint;
	EMISSION = v_tint * 0.5;
	ROUGHNESS = 1.0;
}
"""

var args: Dictionary = {}
var output: String
var scene: Node3D
var camera: Camera3D
var environment: Environment
var owners: Array[MultiMeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var shared_mm: MultiMesh
var mesh: QuadMesh
var started_ms: int
var phases: Array[Dictionary] = []
var all_passed := true
var driver_info: PackedStringArray

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() == 2 else "1"
	_run.call_deferred()

func _run() -> void:
	if not args.has("output"):
		push_error("Required: -- --output=<new isolated evidence directory>")
		quit(2)
		return
	output = str(args["output"])
	if DirAccess.dir_exists_absolute(output) or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Output directory must be new and writable: " + output)
		quit(2)
		return
	started_ms = Time.get_ticks_msec()
	_build_scene()
	if not await _phase("00_distinct_materials_shared_multimesh", [0.65, -0.65], 300):
		await _finish()
		return
	# Same ShaderMaterial RID for both owners. Material-only cache keys cannot
	# fix this case: MODEL_MATRIX differs, and each owner needs its own result.
	materials[0].set_shader_parameter("material_y", 0.0)
	materials[0].set_shader_parameter("world_x_scale", 1.0 / 3.0)
	owners[1].material_override = materials[0]
	await _phase("01_same_material_owner_world_transform", [-0.5, 0.5], 120)
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
	environment.set("pathtracing_samples_per_pixel", 2)
	environment.set("pathtracing_max_bounces", 2)
	environment.set("pathtracing_denoiser", 0)
	environment.set("ddgi_enabled", false)
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -25, 0)
	sun.light_energy = 0.5
	scene.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 0, 8)
	scene.add_child(camera)
	camera.current = true
	var shader := Shader.new()
	shader.code = SHADER_CODE
	for index: int in range(2):
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("material_y", 0.65 if index == 0 else -0.65)
		material.set_shader_parameter("world_x_scale", 0.0)
		materials.append(material)
	mesh = QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	shared_mm = MultiMesh.new()
	shared_mm.transform_format = MultiMesh.TRANSFORM_3D
	shared_mm.mesh = mesh
	shared_mm.instance_count = 1
	shared_mm.set_instance_transform(0, Transform3D.IDENTITY)
	shared_mm.custom_aabb = AABB(Vector3(-1, -2, -1), Vector3(2, 4, 2))
	for index: int in range(2):
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = shared_mm
		instance.material_override = materials[index]
		instance.position = Vector3(-1.5 if index == 0 else 1.5, 0, 0)
		instance.custom_aabb = AABB(Vector3(-1, -2, -1), Vector3(2, 4, 2))
		owners.append(instance)
		scene.add_child(instance)

func _phase(name: String, expected_y: Array, waits: int) -> bool:
	var starting_draws := Engine.get_frames_drawn()
	for _frame: int in range(waits):
		await process_frame
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() - started_ms > 170000:
			all_passed = false
			var timeout := {"phase": name, "timeout": true, "elapsed_ms": Time.get_ticks_msec() - started_ms}
			phases.append(timeout)
			_write_json(output.path_join(name + "-timeout.json"), timeout)
			return false
	var image := root.get_texture().get_image()
	var samples: Array[Dictionary] = []
	for index: int in range(2):
		var x := owners[index].position.x
		var y := float(expected_y[index])
		_sample(image, samples, index, "center", Vector3(x, y, 0), true)
		_sample(image, samples, index, "outer_deformed_edge", Vector3(x, y + signf(y) * 0.35, 0), true)
		_sample(image, samples, index, "opposite_owner_displacement_must_be_empty", Vector3(x, -y, 0), false)
		if absf(y) > 0.6:
			_sample(image, samples, index, "undeformed_center_must_be_empty", Vector3(x, 0, 0), false)
	var pixels_passed := true
	for sample: Dictionary in samples:
		pixels_passed = pixels_passed and bool(sample["passed"])
	var tlas_count := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_RT_TLAS_INSTANCES)
	var config_passed: bool = RenderingServer.get_current_rendering_driver_name() == "vulkan" and RenderingServer.get_current_rendering_method() == "forward_plus" and bool(environment.get("pathtracing_enabled")) and int(environment.get("pathtracing_denoiser")) == 0 and not bool(environment.get("ddgi_enabled")) and ProjectSettings.get_setting("rendering/pathtracing/async_shader_compilation") == false and root.size == SIZE and root.scaling_3d_scale == 1.0 and root.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR
	var image_error := image.save_png(output.path_join(name + ".png"))
	var phase_passed: bool = pixels_passed and config_passed and tlas_count == 2 and image_error == OK
	var record := {"phase": name, "expected_y": expected_y, "waited_post_draws": waits,
		"drawn_frame_delta": Engine.get_frames_drawn() - starting_draws, "elapsed_ms": Time.get_ticks_msec() - started_ms,
		"samples": samples, "pixels_passed": pixels_passed, "actual_tlas_instances": tlas_count,
		"expected_tlas_instances": 2, "config_passed": config_passed, "image_save_error": image_error,
		"phase_passed": phase_passed, "runtime": _runtime(), "owners": _owner_state()}
	var json_written := _write_json(output.path_join(name + ".json"), record)
	all_passed = all_passed and phase_passed and json_written
	phases.append(record)
	print("SHARED_OWNER_PHASE " + JSON.stringify(record))
	return true

func _sample(image: Image, samples: Array[Dictionary], index: int, label: String, world: Vector3, expected_color: bool) -> void:
	var screen := camera.unproject_position(world)
	var pixel := Vector2i(int(screen.x), int(screen.y))
	var in_bounds := pixel.x >= 0 and pixel.x < image.get_width() and pixel.y >= 0 and pixel.y < image.get_height()
	var color := image.get_pixelv(pixel) if in_bounds else Color(-1, -1, -1)
	var rgb: Array[float] = [color.r, color.g, color.b]
	var channel := 0 if index == 0 else 2
	var passed := in_bounds
	if expected_color:
		passed = passed and rgb[channel] > 0.1
		for other: int in range(3):
			if other != channel:
				passed = passed and rgb[channel] > rgb[other] * 1.8 + 0.03
	else:
		passed = passed and maxf(rgb[0], maxf(rgb[1], rgb[2])) < 0.25
	samples.append({"owner": index, "label": label, "world": [world.x, world.y, world.z],
		"pixel": [pixel.x, pixel.y], "rgb": rgb, "expected": "dominant_channel_" + str(channel) if expected_color else "background_max_rgb_below_0.25", "passed": passed})

func _owner_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance: MultiMeshInstance3D in owners:
		result.append({"node_rid": instance.get_instance().get_id(), "multimesh_rid": instance.multimesh.get_rid().get_id(),
			"material_rid": instance.material_override.get_rid().get_id(), "position": [instance.position.x, instance.position.y, instance.position.z],
			"material_y": instance.material_override.get_shader_parameter("material_y"),
			"world_x_scale": instance.material_override.get_shader_parameter("world_x_scale")})
	return result

func _runtime() -> Dictionary:
	return {"engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(), "driver": driver_info,
		"api": RenderingServer.get_current_rendering_driver_name(), "api_version": RenderingServer.get_video_adapter_api_version(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "os": OS.get_name(), "os_version": OS.get_version(),
		"fixture_sha256": FileAccess.get_sha256((get_script() as Script).resource_path), "shader": SHADER_CODE,
		"resolution": [root.size.x, root.size.y], "camera_position": [0, 0, 8], "camera_fov": camera.fov,
		"mesh_rid": mesh.get_rid().get_id(), "mesh_size": [mesh.size.x, mesh.size.y], "logical_instances_per_owner": shared_mm.instance_count,
		"async_shader_compilation": ProjectSettings.get_setting("rendering/pathtracing/async_shader_compilation"),
		"pt": environment.get("pathtracing_enabled"), "rr": environment.get("pathtracing_denoiser"), "ddgi": environment.get("ddgi_enabled"),
		"samples_per_pixel": environment.get("pathtracing_samples_per_pixel"), "max_bounces": environment.get("pathtracing_max_bounces")}

func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write evidence JSON: " + path)
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK

func _finish() -> void:
	var record := {"runtime": _runtime(), "phases": phases, "all_checks_passed": all_passed,
		"elapsed_ms_before_teardown": Time.get_ticks_msec() - started_ms, "requested_exit_code": 0 if all_passed else 1}
	all_passed = _write_json(output.path_join("summary.json"), record) and all_passed
	current_scene = null
	scene.queue_free()
	for _frame: int in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	print("SHARED_OWNER_EXIT " + str(0 if all_passed else 1))
	quit(0 if all_passed else 1)
