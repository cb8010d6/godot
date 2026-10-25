extends Node3D

signal sampled
var probe: Object
var output := ""
var runtime_state: Dictionary = {}

func _ready() -> void:
	output = OS.get_environment("GODOT_ACCEPTANCE_OUTPUT")
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	add_child(mesh)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1, 4)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 20, 0)
	add_child(light)
	if ClassDB.class_exists("RTXAcceptanceProbe"):
		probe = ClassDB.instantiate("RTXAcceptanceProbe")
	_run.call_deferred()

func _sample() -> void:
	var payload: Variant = JSON.parse_string(probe.call("read_state"))
	_record.call_deferred(payload)

func _record(payload: Variant) -> void:
	if payload is Dictionary:
		runtime_state = payload
	sampled.emit()

func _run() -> void:
	for _i in range(30):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	if probe != null:
		RenderingServer.call_on_render_thread(_sample)
		await sampled
	var metadata := {
		"engine": Engine.get_version_info(),
		"backend": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"frame_count": Engine.get_frames_drawn(),
		"editor_hint": Engine.is_editor_hint(),
		"force_legacy": OS.get_environment("GODOT_ACCEPTANCE_FORCE_D3D12_LEGACY"),
		"runtime": runtime_state,
	}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("metadata.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()
		get_viewport().get_texture().get_image().save_png(output.path_join("actual-frame.png"))
	print("STARTUP_DIAGNOSTIC ", JSON.stringify(metadata))
	if probe != null:
		probe.free()
	get_tree().quit()
