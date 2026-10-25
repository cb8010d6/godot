extends Node3D

# Real rendered regression; a headless or unsupported invocation cannot pass.
func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not Engine.has_singleton("Streamline"):
		push_error("A real Forward+ renderer and the Streamline API are required")
		get_tree().quit(2)
		return
	var api := Engine.get_singleton("Streamline")
	var has_dlss := bool(api.call("get_capability", 0))
	var expect_missing := "--expect-no-sdk" in OS.get_cmdline_user_args()
	if has_dlss == expect_missing:
		push_error("Runtime availability differs from the requested test condition")
		get_tree().quit(3)
		return
	var before: Dictionary = api.call("get_frame_generation_status")
	var marker := MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.RED
	marker.material_override = material
	add_child(marker)
	var camera := Camera3D.new()
	camera.position.z = 4.0
	camera.current = true
	add_child(camera)
	if has_dlss:
		get_viewport().scaling_3d_mode = ClassDB.class_get_integer_constant("Viewport", "SCALING_3D_MODE_DLSS") as Viewport.Scaling3DMode
		get_viewport().scaling_3d_scale = 2.0 / 3.0
	await _frames(100)
	for cycle in range(3):
		var local := RenderingServer.create_local_rendering_device()
		if local == null:
			push_error("Local RenderingDevice creation failed")
			get_tree().quit(4)
			return
		local.free()
		var after: Dictionary = api.call("get_frame_generation_status")
		if bool(api.call("get_capability", 0)) != has_dlss or before.get("available") != after.get("available"):
			push_error("Local device destruction changed main Streamline availability")
			get_tree().quit(5)
			return
		await _frames(40)
	var image := get_viewport().get_texture().get_image()
	if image.is_empty() or image.get_pixel(image.get_width() / 2, image.get_height() / 2).r < 0.5:
		push_error("Main viewport did not render its marker after local device teardown")
		get_tree().quit(6)
		return
	print("STREAMLINE_LOCAL_DEVICE_PASS ", JSON.stringify({"engine": Engine.get_version_info(), "driver": RenderingServer.get_current_rendering_driver_name(), "gpu": RenderingServer.get_video_adapter_name(), "dlss": has_dlss, "cycles": 3}))
	get_tree().quit(0)


func _frames(count: int) -> void:
	for _frame in range(count):
		await RenderingServer.frame_post_draw
