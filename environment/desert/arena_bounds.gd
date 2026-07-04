extends Node3D

const ROCK_MAT := preload("res://environment/desert/rock_mat.tres")

@export var center := Vector3(0.0, 0.0, 12.0)
@export var half_extent_x := 38.0
@export var half_extent_z := 38.0
@export var wall_height := 5.5
@export var wall_thickness := 2.2
@export var segment_spacing := 7.0
@export var push_margin := 0.35


func _ready() -> void:
	add_to_group("arena_bounds")
	_build_walls()


func get_min_x() -> float:
	return center.x - half_extent_x


func get_max_x() -> float:
	return center.x + half_extent_x


func get_min_z() -> float:
	return center.z - half_extent_z


func get_max_z() -> float:
	return center.z + half_extent_z


func clamp_position(pos: Vector3) -> Vector3:
	return Vector3(
		clampf(pos.x, get_min_x() + push_margin, get_max_x() - push_margin),
		pos.y,
		clampf(pos.z, get_min_z() + push_margin, get_max_z() - push_margin),
	)


func contains_xz(pos: Vector3) -> bool:
	return pos.x >= get_min_x() and pos.x <= get_max_x() \
		and pos.z >= get_min_z() and pos.z <= get_max_z()


func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D:
			_clamp_player(node as CharacterBody3D)


func _clamp_player(player: CharacterBody3D) -> void:
	var pos := player.global_position
	var clamped := clamp_position(pos)
	if clamped.is_equal_approx(pos):
		return
	player.global_position = clamped
	var velocity := player.velocity
	if clamped.x != pos.x:
		velocity.x = 0.0
	if clamped.z != pos.z:
		velocity.z = 0.0
	player.velocity = velocity


func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "BoundaryCollision"
	body.collision_layer = 2
	add_child(body)

	var min_x := get_min_x()
	var max_x := get_max_x()
	var min_z := get_min_z()
	var max_z := get_max_z()
	var width_x := max_x - min_x
	var width_z := max_z - min_z

	_add_wall_segment(body, Vector3(center.x, wall_height * 0.5, min_z), Vector3(width_x + wall_thickness * 2.0, wall_height, wall_thickness))
	_add_wall_segment(body, Vector3(center.x, wall_height * 0.5, max_z), Vector3(width_x + wall_thickness * 2.0, wall_height, wall_thickness))
	_add_wall_segment(body, Vector3(min_x, wall_height * 0.5, center.z), Vector3(wall_thickness, wall_height, width_z + wall_thickness * 2.0))
	_add_wall_segment(body, Vector3(max_x, wall_height * 0.5, center.z), Vector3(wall_thickness, wall_height, width_z + wall_thickness * 2.0))

	_build_visual_ring(min_x, max_x, min_z, max_z)


func _add_wall_segment(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)


func _build_visual_ring(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	var visuals := Node3D.new()
	visuals.name = "BoundaryVisuals"
	add_child(visuals)

	_place_wall_line(visuals, Vector3(min_x, 0.0, min_z), Vector3(max_x, 0.0, min_z), true)
	_place_wall_line(visuals, Vector3(min_x, 0.0, max_z), Vector3(max_x, 0.0, max_z), true)
	_place_wall_line(visuals, Vector3(min_x, 0.0, min_z), Vector3(min_x, 0.0, max_z), false)
	_place_wall_line(visuals, Vector3(max_x, 0.0, min_z), Vector3(max_x, 0.0, max_z), false)


func _place_wall_line(parent: Node3D, start: Vector3, end: Vector3, along_x: bool) -> void:
	var delta := end - start
	var length := delta.length()
	var steps := maxi(1, int(length / segment_spacing))
	var dir := delta / float(steps)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start.x * 17.0 + start.z * 31.0)

	for i in range(steps + 1):
		var pos := start + dir * float(i)
		var rock := _make_boundary_rock(rng, along_x)
		rock.position = pos + Vector3(
			rng.randf_range(-0.8, 0.8),
			0.0,
			rng.randf_range(-0.8, 0.8),
		)
		parent.add_child(rock)


func _make_boundary_rock(rng: RandomNumberGenerator, along_x: bool) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	var height := rng.randf_range(2.8, 5.8)
	var width := rng.randf_range(2.0, 4.2)
	var depth := rng.randf_range(1.8, 3.6)
	if along_x:
		box.size = Vector3(width, height, depth)
	else:
		box.size = Vector3(depth, height, width)
	mesh_node.mesh = box
	mesh_node.material_override = ROCK_MAT
	mesh_node.position.y = height * 0.5
	mesh_node.rotation.y = rng.randf_range(0.0, TAU)
	return mesh_node
