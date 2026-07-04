extends Node3D

const ENEMY_SCENE := preload("res://enemies/humanoid_chaser.tscn")

@export var spawn_radius := 24.0
@export var spawn_y := 0.2
@export var spawn_fov := 75.0
@export var min_spawn_distance := 10.0
@export var arena_half_extent := 118.0
@export var spawn_attempts := 12
@export var squad_refresh_interval := 0.25

var _run_director: Node = null
var _slot_refresh_timer := 0.0


func _ready() -> void:
	add_to_group("enemy_spawner")


func set_run_director(director: Node) -> void:
	_run_director = director


func _process(delta: float) -> void:
	_slot_refresh_timer += delta
	if _slot_refresh_timer >= squad_refresh_interval:
		_slot_refresh_timer = 0.0
		_refresh_squad_slots()


func clear_all_enemies() -> void:
	for child in get_children():
		if child.has_method("is_alive"):
			child.queue_free()
	_refresh_squad_slots()


func get_alive_count() -> int:
	var count := 0
	for child in get_children():
		if child.has_method("is_alive") and child.is_alive():
			count += 1
	return count


func kill_all_enemies() -> void:
	for child in get_children():
		if not child.has_method("is_alive") or not child.is_alive():
			continue
		if child.has_method("damage"):
			child.damage(Vector3.ZERO, Vector3.ZERO)
	_refresh_squad_slots()


func spawn_enemy() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var origin := Vector3.ZERO
	if player != null:
		origin = player.global_position

	var spawn_position: Variant = _pick_spawn_position(origin, player)
	if spawn_position == null:
		return

	var enemy := ENEMY_SCENE.instantiate() as Node3D
	add_child(enemy)
	enemy.global_position = spawn_position

	if enemy.has_signal("defeated") and _run_director != null:
		if not enemy.defeated.is_connected(_run_director.notify_enemy_defeated):
			enemy.defeated.connect(_run_director.notify_enemy_defeated)

	_refresh_squad_slots()


func _pick_spawn_position(origin: Vector3, player: Node3D) -> Variant:
	var forward_xz := _get_spawn_forward(player)

	for _attempt in spawn_attempts:
		var base_angle := atan2(forward_xz.z, forward_xz.x)
		var half_fov_rad := deg_to_rad(spawn_fov / 2.0)
		var angle_offset := randf_range(-half_fov_rad, half_fov_rad)
		var spawn_angle := base_angle + angle_offset

		var distance := randf_range(minf(min_spawn_distance, spawn_radius), spawn_radius)
		var spawn_position := origin + Vector3(cos(spawn_angle), 0.0, sin(spawn_angle)) * distance
		spawn_position.x = clampf(spawn_position.x, -arena_half_extent, arena_half_extent)
		spawn_position.z = clampf(spawn_position.z, -arena_half_extent, arena_half_extent)
		spawn_position.y = spawn_y

		if _is_spawn_position_clear(spawn_position):
			return spawn_position

	return null


func _get_spawn_forward(player: Node3D) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var forward_xz := Vector3.FORWARD
	if camera != null:
		var forward := -camera.global_transform.basis.z
		var horizontal := Vector3(forward.x, 0.0, forward.z).normalized()
		if horizontal.length_squared() > 0.001:
			forward_xz = horizontal
		elif player != null:
			var player_forward := -player.global_transform.basis.z
			var player_horizontal := Vector3(player_forward.x, 0.0, player_forward.z).normalized()
			if player_horizontal.length_squared() > 0.001:
				forward_xz = player_horizontal
	elif player != null:
		var player_forward := -player.global_transform.basis.z
		var player_horizontal := Vector3(player_forward.x, 0.0, player_forward.z).normalized()
		if player_horizontal.length_squared() > 0.001:
			forward_xz = player_horizontal
	return forward_xz


func _is_spawn_position_clear(position: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = capsule
	params.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.9)
	params.collide_with_areas = false
	params.collide_with_bodies = true

	for hit in space_state.intersect_shape(params, 8):
		if not hit.has("collider"):
			continue
		var collider: Object = hit.collider
		if collider is CharacterBody3D and collider.is_in_group("player"):
			continue
		return false

	var floor_origin := position + Vector3.UP * 2.0
	var floor_target := position + Vector3.DOWN * 4.0
	var floor_query := PhysicsRayQueryParameters3D.create(floor_origin, floor_target)
	floor_query.collision_mask = 0xFFFFFFFF
	var floor_hit := space_state.intersect_ray(floor_query)
	if floor_hit.is_empty():
		return false

	return true


func _refresh_squad_slots() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var squad: Array[Node] = []

	for child in get_children():
		if not child.has_method("set_squad_slot") or not child.has_method("is_alive"):
			continue
		if not child.is_alive():
			continue
		squad.append(child)

	var count := squad.size()
	if count == 0:
		return

	if player != null:
		squad.sort_custom(func(a: Node, b: Node) -> bool:
			var pos_a := (a as Node3D).global_position
			var pos_b := (b as Node3D).global_position
			var dist_a: float = pos_a.distance_squared_to(player.global_position)
			var dist_b: float = pos_b.distance_squared_to(player.global_position)
			return dist_a < dist_b
		)

	var ring_offset := 0.0
	if player != null:
		ring_offset = atan2(
			-player.global_transform.basis.z.z,
			-player.global_transform.basis.z.x
		)

	for i in count:
		var slot_angle := ring_offset + TAU * float(i) / float(count)
		var can_commit := i == 0
		squad[i].set_squad_slot(i, count, slot_angle, can_commit)
