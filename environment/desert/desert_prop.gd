class_name DesertProp
extends Node3D

enum Kind { ROCK, PILLAR, DUNE, BOULDER }

const ROCK_MAT := preload("res://environment/desert/rock_mat.tres")
const RUIN_MAT := preload("res://environment/desert/ruin_mat.tres")


func setup(kind: Kind, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match kind:
		Kind.ROCK:
			_build_rock_cluster(rng)
		Kind.PILLAR:
			_build_ruin_pillar(rng)
		Kind.DUNE:
			_build_dune(rng)
		Kind.BOULDER:
			_build_boulder(rng)


func _build_rock_cluster(rng: RandomNumberGenerator) -> void:
	var body := _make_body()
	var chunk_count := rng.randi_range(2, 4)
	for i in chunk_count:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		var sx := rng.randf_range(0.7, 1.8)
		var sy := rng.randf_range(0.35, 1.1)
		var sz := rng.randf_range(0.7, 1.7)
		box.size = Vector3(sx, sy, sz)
		mesh.mesh = box
		mesh.material_override = ROCK_MAT
		mesh.position = Vector3(
			rng.randf_range(-0.8, 0.8),
			sy * 0.5,
			rng.randf_range(-0.8, 0.8),
		)
		mesh.rotation.y = rng.randf_range(0.0, TAU)
		add_child(mesh)
		_add_box_collision(body, mesh.position, box.size * 0.92)


func _build_ruin_pillar(rng: RandomNumberGenerator) -> void:
	var body := _make_body()
	var height := rng.randf_range(2.2, 4.8)
	var radius := rng.randf_range(0.35, 0.65)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * rng.randf_range(0.55, 0.85)
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh.mesh = cylinder
	mesh.material_override = RUIN_MAT
	mesh.position = Vector3(0.0, height * 0.5, 0.0)
	mesh.rotation.y = rng.randf_range(0.0, TAU)
	add_child(mesh)
	_add_cylinder_collision(body, mesh.position, radius, height)

	if rng.randf() > 0.35:
		var cap := MeshInstance3D.new()
		var cap_box := BoxMesh.new()
		cap_box.size = Vector3(radius * 2.4, rng.randf_range(0.2, 0.45), radius * 2.0)
		cap.mesh = cap_box
		cap.material_override = ROCK_MAT
		cap.position = mesh.position + Vector3(
			rng.randf_range(-0.25, 0.25),
			height * 0.5 + cap_box.size.y * 0.35,
			rng.randf_range(-0.25, 0.25),
		)
		cap.rotation.y = rng.randf_range(0.0, TAU)
		add_child(cap)


func _build_dune(rng: RandomNumberGenerator) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var size := rng.randf_range(2.0, 4.5)
	sphere.radius = size
	sphere.height = size * 0.35
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.material_override = ROCK_MAT
	mesh.scale = Vector3(rng.randf_range(1.1, 1.8), 0.22, rng.randf_range(1.0, 1.6))
	mesh.position = Vector3(0.0, size * 0.08, 0.0)
	mesh.rotation.y = rng.randf_range(0.0, TAU)
	add_child(mesh)


func _build_boulder(rng: RandomNumberGenerator) -> void:
	var body := _make_body()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var radius := rng.randf_range(0.55, 1.35)
	sphere.radius = radius
	sphere.height = radius * 1.6
	sphere.radial_segments = 12
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.material_override = ROCK_MAT
	mesh.scale = Vector3(
		rng.randf_range(0.9, 1.3),
		rng.randf_range(0.55, 0.85),
		rng.randf_range(0.9, 1.2),
	)
	mesh.position = Vector3(0.0, radius * 0.35, 0.0)
	mesh.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
	add_child(mesh)
	_add_sphere_collision(body, mesh.position, radius * 0.9)


func _make_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	add_child(body)
	return body


func _add_box_collision(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)


func _add_cylinder_collision(body: StaticBody3D, pos: Vector3, radius: float, height: float) -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position = pos
	body.add_child(shape)


func _add_sphere_collision(body: StaticBody3D, pos: Vector3, radius: float) -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	shape.position = pos
	body.add_child(shape)
