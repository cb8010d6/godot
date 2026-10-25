extends Node3D

var body: RigidBody3D
var ticks := 0


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10, 1, 10)
	var floor_collision := CollisionShape3D.new()
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5
	add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = floor_shape.size
	floor_mesh.mesh = floor_box
	floor_body.add_child(floor_mesh)
	body = RigidBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	body.position.y = 5
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	body.add_child(mesh)
	add_child(body)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(7, 6, 10)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	add_child(light)


func _physics_process(_delta: float) -> void:
	if body == null:
		return
	ticks += 1
	if ticks < 120:
		return
	var height := body.global_position.y
	var valid: bool = ProjectSettings.get_setting("physics/3d/physics_engine") == "PhysX" and absf(height - 0.5) < 0.08
	print("PHYSX_SMOKE_", "PASS" if valid else "FAIL", " height=", height, " ticks=", ticks)
	get_tree().quit(0 if valid else 1)
