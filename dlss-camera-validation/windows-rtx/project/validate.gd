extends Node

var mode := "SR"
var output := ""
var suite := "full"
var camera: Camera3D
var environment: Environment
var world: Node3D
var results: Array = []
var moving_box: MeshInstance3D
var root: Window

func _ready() -> void:
	root = get_tree().root
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size(), 2):
		if i + 1 >= args.size():
			break
		match args[i]:
			"--mode": mode = args[i + 1]
			"--output": output = args[i + 1]
			"--suite": suite = args[i + 1]
	call_deferred("run")

func vector_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.25 if metallic > 0.0 else 0.7
	return m

func box(pos: Vector3, size: Vector3, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material(color, metallic)
	world.add_child(item)
	item.position = pos
	return item

func create_scene() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env_node := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.11, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.7, 0.9)
	environment.ambient_light_energy = 0.6
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.pathtracing_samples_per_pixel = 1
	environment.pathtracing_max_bounces = 2
	environment.pathtracing_denoiser = 1
	environment.pathtracing_enabled = mode == "RR"
	env_node.environment = environment
	world.add_child(env_node)
	var anchor := Vector3(3, -7, 11)
	var colors := [Color(0.7, 0.14, 0.1), Color(0.1, 0.5, 0.7), Color(0.7, 0.6, 0.1)]
	for axis in range(3):
		for direction in [-1, 1]:
			var wall_pos := anchor
			wall_pos[axis] += 8.0 * direction
			var wall_size := Vector3(16, 16, 16)
			wall_size[axis] = 0.15
			box(wall_pos, wall_size, colors[axis])
			# Thin, contrasting geometry gives the upscaler visible edge detail.
			for stripe in range(-6, 7, 2):
				var stripe_pos := wall_pos
				stripe_pos[axis] -= 0.12 * direction
				stripe_pos[(axis + 1) % 3] += stripe
				var stripe_size := wall_size
				stripe_size[(axis + 1) % 3] = 0.08
				stripe_size[axis] = 0.06
				box(stripe_pos, stripe_size, Color(0.8, 0.8, 0.8))
	for x in [-4, 0, 4]:
		for y in [-4, 4]:
			for z in [-4, 4]:
				box(anchor + Vector3(x, y, z), Vector3(1, 1.5, 1), Color(0.3 + x * 0.04, 0.65, 0.35), 0.3)
	moving_box = box(anchor + Vector3(0, -1, -4), Vector3(1, 2, 1), Color(0.9, 0.55, 0.15), 0.7)
	var light := OmniLight3D.new()
	light.omni_range = 30
	light.light_energy = 7
	world.add_child(light)
	light.position = anchor + Vector3(0, 2, 0)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 1.0
	world.add_child(sun)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.near = 0.1
	camera.far = 100.0
	camera.position = anchor
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_DLSS
	root.scaling_3d_scale = 1.0 if mode == "DLAA" else 2.0 / 3.0
	root.fsr_sharpness = 0.0
	root.frame_generation = mode == "FG"
	Streamline.set_parameter(Streamline.STREAMLINE_PARAM_REFLEX_MODE, 1.0)

func cases() -> Array:
	var list: Array = []
	var dimensions := [Vector2i(720, 720), Vector2i(1440, 810), Vector2i(1680, 720), Vector2i(810, 1440)]
	var names := ["square", "16x9", "21x9", "9x16"]
	for keep_mode in [Camera3D.KEEP_WIDTH, Camera3D.KEEP_HEIGHT]:
		for i in dimensions.size():
			list.append({"id": "fov_%s_%s" % ["width" if keep_mode == Camera3D.KEEP_WIDTH else "height", names[i]],
				"size": dimensions[i], "keep": keep_mode, "basis": Basis.IDENTITY, "position": Vector3(3, -7, 11)})
	var rotations := [Basis.IDENTITY, Basis(Vector3.UP, PI / 2), Basis(Vector3.RIGHT, PI / 2), Basis(Vector3.BACK, PI / 2), Basis(Vector3(1, 2, 3).normalized(), 0.73)]
	var rotation_names := ["identity", "yaw90", "pitch90", "roll90", "axis123"]
	for i in rotations.size():
		list.append({"id": "basis_" + rotation_names[i], "size": Vector2i(1440, 810), "keep": Camera3D.KEEP_HEIGHT,
			"basis": rotations[i], "position": Vector3(3, -7, 11)})
	if suite == "smoke":
		return [list[1], list[9]]
	return list

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var capabilities := {}
	for key in range(6):
		capabilities[str(key)] = Streamline.get_capability(key)
	var metadata := {"mode": mode, "capabilities": capabilities, "gpu": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info()}
	print("[DLSS-SCENE] " + JSON.stringify(metadata))
	FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE).store_string(JSON.stringify(metadata, "\t"))
	if not capabilities["0"]:
		push_error("Real DLSS support is unavailable; refusing fallback validation")
		get_tree().quit(2)
		return
	if mode == "RR" and not capabilities["2"] or mode == "FG" and not capabilities["1"]:
		push_error("Requested feature is unavailable")
		get_tree().quit(3)
		return
	create_scene()
	if mode == "FG":
		Streamline.set_parameter(Streamline.STREAMLINE_PARAM_REFLEX_FRAME_LIMIT_US, 16666.7)
	for scenario in cases():
		root.size = scenario.size
		camera.keep_aspect = scenario.keep
		camera.fov = 90.0
		camera.transform = Transform3D(scenario.basis, scenario.position)
		if mode == "FG":
			root.grab_focus()
		var warmup_frames := 120 if mode == "FG" else 40
		for i in range(warmup_frames):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var start_frame := Engine.get_frames_drawn()
		for i in range(8):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var end_frame := Engine.get_frames_drawn()
		var projection := camera.get_camera_projection()
		var record := {"id": scenario.id, "mode": mode, "start_frame": start_frame, "end_frame": end_frame,
			"warmup_frames": warmup_frames, "max_fps": Engine.max_fps, "reflex_limit_us": 16666.7 if mode == "FG" else 0.0, "window_focused": DisplayServer.window_is_focused(),
			"width": root.size.x, "height": root.size.y, "keep_aspect": camera.keep_aspect,
			"expected_fov": 2.0 * atan(1.0 / projection.y.y),
			"expected_position": vector_array(camera.global_position),
			"expected_forward": vector_array(-camera.global_basis.z), "expected_up": vector_array(camera.global_basis.y),
			"expected_right": vector_array(camera.global_basis.x),
			"projection_y_scale": projection.y.y}
		var image := root.get_texture().get_image()
		record["screenshot_result"] = image.save_png(output.path_join(scenario.id + ".png"))
		results.append(record)
		print("[DLSS-SCENE] " + JSON.stringify(record))
		FileAccess.open(output.path_join("cases.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	# Short motion sequence: retain frames for checking temporal artifacts manually.
	if suite != "smoke":
		root.size = Vector2i(1440, 810)
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		for i in range(120):
			camera.transform = Transform3D(Basis(Vector3.UP, 0.2 * sin(i * 0.025)), Vector3(3 + 0.4 * sin(i * 0.04), -7, 11))
			moving_box.rotation.y = i * 0.02
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if i % 15 == 0:
				root.get_texture().get_image().save_png(output.path_join("motion_%03d.png" % i))
	print("[DLSS-SCENE] completed " + mode)
	get_tree().quit(0)
