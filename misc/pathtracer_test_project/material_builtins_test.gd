extends SceneTree
## Real raster/PT/DDGI regression for MultiMesh built-ins and per-instance deformation.
## Use --case=custom|id|color|standard --lighting=pt|ddgi|raster --output=<directory>.
## Requires a real Vulkan Forward+ run; missing colored/deformed samples fail the test.

var args: Dictionary = {}
var camera: Camera3D
var environment: Environment
var test_case: String = "custom"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() == 2 else "1"
	_run.call_deferred()

func _run() -> void:
	if not args.has("output"):
		push_error("An explicit isolated output directory is required")
		quit(2)
		return
	var output: String = str(args["output"])
	DirAccess.make_dir_recursive_absolute(output)
	test_case = str(args.get("case", "custom"))
	var lighting: String = str(args.get("lighting", "pt"))
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	root.size = Vector2i(640, 360)
	Engine.max_fps = 60
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.02)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.set("pathtracing_enabled", lighting == "pt")
	environment.set("pathtracing_samples_per_pixel", 2)
	environment.set("pathtracing_max_bounces", 2)
	environment.set("pathtracing_denoiser", int(args.get("rr", "0")))
	environment.set("ddgi_enabled", lighting == "ddgi")
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -25, 0)
	sun.light_energy = 0.5
	scene.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if str(args.get("projection", "perspective")) == "orthographic" else Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 30.0
	camera.size = 4.2
	camera.position = Vector3(0, 0, 8)
	scene.add_child(camera)
	camera.current = true
	var shader := Shader.new()
	var vertex_code: String
	match test_case:
		"custom":
			vertex_code = "v_tint = INSTANCE_CUSTOM.rgb; VERTEX.y += INSTANCE_CUSTOM.a * 0.5;"
		"id":
			vertex_code = "v_tint = INSTANCE_ID == 0 ? vec3(1,0,0) : (INSTANCE_ID == 1 ? vec3(0,1,0) : vec3(0,0,1));"
		"color":
			vertex_code = "v_tint = COLOR.rgb;"
		"standard":
			vertex_code = "v_tint = vec3(1);"
		_:
			push_error("Unknown material regression case")
			quit(2)
			return
	shader.code = "shader_type spatial; render_mode cull_disabled; varying vec3 v_tint; void vertex(){" + vertex_code + "} void fragment(){ ALBEDO=v_tint; EMISSION=v_tint*0.5; ROUGHNESS=1.0; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.4, 1.4)
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 3
	var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
	for index: int in range(3):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3((index - 1) * 2, 0, 0)))
		multimesh.set_instance_color(index, colors[index])
		multimesh.set_instance_custom_data(index, Color(colors[index].r, colors[index].g, colors[index].b, index - 1))
	if test_case == "standard":
		for index: int in range(3):
			var control := MeshInstance3D.new()
			var control_mesh := QuadMesh.new()
			control_mesh.size = Vector2(1.4, 1.4)
			var control_material := StandardMaterial3D.new()
			control_material.albedo_color = colors[index]
			control_material.emission_enabled = true
			control_material.emission = colors[index]
			control_material.emission_energy_multiplier = 0.5
			control_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			control_mesh.material = control_material
			control.mesh = control_mesh
			control.position = Vector3((index - 1) * 2, 0, 0)
			scene.add_child(control)
	else:
		var instances := MultiMeshInstance3D.new()
		instances.multimesh = multimesh
		scene.add_child(instances)
	for _frame: int in range(int(args.get("frames", "360"))):
		await process_frame
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var samples: Array[Dictionary] = []
	for index: int in range(3):
		var expected_y: float = (index - 1) * 0.5 if test_case == "custom" else 0.0
		var locations: Array[float] = [expected_y]
		if test_case == "custom" and index != 1:
			locations.append(expected_y + (-0.55 if index == 0 else 0.55))
		for world_y: float in locations:
			var screen: Vector2 = camera.unproject_position(Vector3((index - 1) * 2, world_y, 0))
			var color: Color = image.get_pixel(int(screen.x), int(screen.y))
			var components: Array[float] = [color.r, color.g, color.b]
			var dominant: bool = components[index] > 0.1
			for other: int in range(3):
				if other != index:
					dominant = dominant and components[index] > components[other] * 1.8 + 0.03
			samples.append({"instance": index, "world_y": world_y, "screen": [screen.x, screen.y], "rgb": components, "expected_channel_dominant": dominant})
	var samples_passed: bool = true
	for sample: Dictionary in samples:
		samples_passed = samples_passed and bool(sample["expected_channel_dominant"])
	var image_error: Error = image.save_png(output.path_join("frame.png"))
	samples_passed = samples_passed and image_error == OK
	var file := FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "api": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "case": test_case, "lighting": lighting, "rr": environment.get("pathtracing_denoiser"),
		"projection": camera.projection, "fixture_sha256": FileAccess.get_sha256((get_script() as Script).resource_path),
		"frames": Engine.get_frames_drawn(), "samples": samples, "shader": shader.code, "samples_passed": samples_passed}, "\t"))
	file.close()
	image = null
	current_scene = null
	scene.queue_free()
	for _frame: int in range(8):
		await process_frame
	quit(0 if samples_passed else 1)
