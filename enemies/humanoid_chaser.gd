extends CharacterBody3D

enum SquadRole { STRIKER, FLANKER, LURKER }

signal defeated

const SMOKE_PUFF_SCENE := preload("res://enemies/smoke_puff/smoke_puff.tscn")

@export var move_speed := 3.2
@export var stop_distance := 1.6
@export var gravity := 30.0
@export var contact_damage := 10.0
@export var damage_cooldown := 0.8
@export var orbit_radius := 2.6
@export var separation_radius := 1.35
@export var separation_strength := 3.2
@export var commit_speed_multiplier := 1.35
@export var wall_probe_distance := 1.35
@export var unstuck_frames := 6
@export var direct_chase_distance := 12.0

@onready var _visual_root: Node3D = $VisualRoot

var _alive := true
var _damage_timer := 0.0
var _slot_angle := 0.0
var _slot_index := 0
var _squad_size := 1
var _role := SquadRole.FLANKER
var _can_commit := false
var _angle_jitter := 0.0
var _stuck_frames := 0
var _unstick_side := 1.0


func _ready() -> void:
	_angle_jitter = randf_range(-0.22, 0.22)
	_unstick_side = 1.0 if randf() > 0.5 else -1.0
	var roll := randf()
	if roll < 0.35:
		_role = SquadRole.STRIKER
	elif roll < 0.75:
		_role = SquadRole.FLANKER
	else:
		_role = SquadRole.LURKER


func is_alive() -> bool:
	return _alive


func set_squad_slot(index: int, squad_size: int, slot_angle: float, can_commit: bool) -> void:
	_slot_index = index
	_squad_size = maxi(1, squad_size)
	_slot_angle = slot_angle
	_can_commit = can_commit


func _get_role_orbit_radius() -> float:
	match _role:
		SquadRole.STRIKER:
			return orbit_radius * 0.78
		SquadRole.LURKER:
			return orbit_radius * 1.32
		_:
			return orbit_radius


func _compute_separation() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Node3D):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue

		var other := node as Node3D
		var offset := global_position - other.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist > 0.01 and dist < separation_radius:
			var strength := (separation_radius - dist) / separation_radius
			push += offset.normalized() * strength

	return push * separation_strength * 0.35


func _compute_move_direction(player: Node3D) -> Vector3:
	var player_pos := player.global_position
	var to_player := player_pos - global_position
	to_player.y = 0.0
	var dist_to_player := to_player.length()

	if dist_to_player <= stop_distance:
		return Vector3.ZERO

	if dist_to_player > direct_chase_distance:
		var direct := to_player.normalized() + _compute_separation() * 0.35
		if direct.length_squared() < 0.001:
			return Vector3.ZERO
		return direct.normalized()

	var slot_dir := Vector3(
		cos(_slot_angle + _angle_jitter),
		0.0,
		sin(_slot_angle + _angle_jitter)
	)
	var orbit_target := player_pos + slot_dir * _get_role_orbit_radius()
	var to_orbit := orbit_target - global_position
	to_orbit.y = 0.0

	var seek := Vector3.ZERO
	if to_orbit.length() > 0.35:
		seek = to_orbit.normalized()
		if _is_direction_blocked(seek):
			seek = to_player.normalized()
	elif _can_commit and _role == SquadRole.STRIKER:
		seek = to_player.normalized()
	elif dist_to_player > stop_distance + 0.5:
		seek = to_player.normalized() * 0.35

	if _role == SquadRole.LURKER and dist_to_player < _get_role_orbit_radius() * 0.85:
		seek = seek * 0.55 - to_player.normalized() * 0.45

	var direction := seek + _compute_separation()

	if _can_commit and dist_to_player < stop_distance * 2.2 and dist_to_player > stop_distance:
		direction = direction.lerp(to_player.normalized(), 0.55)

	if direction.length_squared() < 0.001:
		return Vector3.ZERO
	return direction.normalized()


func _is_direction_blocked(direction: Vector3) -> bool:
	if direction.length_squared() < 0.0001:
		return false
	var space_state := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.85
	var ahead := origin + direction.normalized() * wall_probe_distance * 1.4
	var query := PhysicsRayQueryParameters3D.create(origin, ahead)
	query.exclude = [get_rid()]
	return not space_state.intersect_ray(query).is_empty()


func _steer_around_walls(direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.0001:
		return direction

	var best := direction
	var best_clearance := _probe_clearance(direction)
	if best_clearance > 0.85:
		return direction

	for angle_deg in [-50.0, -28.0, 28.0, 50.0, 90.0, -90.0]:
		var rotated := direction.rotated(Vector3.UP, deg_to_rad(angle_deg))
		var clearance := _probe_clearance(rotated)
		if clearance > best_clearance:
			best_clearance = clearance
			best = rotated

	if best_clearance < 0.2:
		return _steer_around_walls_single(direction)
	return best.normalized()


func _probe_clearance(direction: Vector3) -> float:
	var space_state := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.85
	var ahead := origin + direction.normalized() * wall_probe_distance
	var query := PhysicsRayQueryParameters3D.create(origin, ahead)
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	return origin.distance_to(hit.position) / wall_probe_distance


func _steer_around_walls_single(direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.0001:
		return direction

	var space_state := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.85
	var ahead := origin + direction * wall_probe_distance
	var query := PhysicsRayQueryParameters3D.create(origin, ahead)
	query.exclude = [get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return direction

	var normal: Vector3 = hit.normal
	normal.y = 0.0
	if normal.length_squared() < 0.0001:
		return direction
	normal = normal.normalized()

	var slide := direction.slide(normal)
	if slide.length_squared() > 0.05:
		return slide.normalized()

	var tangent := Vector3(-normal.z, 0.0, normal.x) * _unstick_side
	if direction.dot(tangent) < 0.0:
		tangent = -tangent
	return tangent.normalized()


func _apply_unstick(direction: Vector3, moved_distance: float) -> Vector3:
	if direction.length_squared() < 0.0001:
		return direction

	if moved_distance > 0.02:
		_stuck_frames = 0
		return direction

	_stuck_frames += 1
	if _stuck_frames < unstuck_frames:
		return direction

	_stuck_frames = 0
	_unstick_side *= -1.0
	_nudge_off_wall()

	var slide_collision := get_last_slide_collision()
	if slide_collision:
		var normal := slide_collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() > 0.0001:
			return Vector3(-normal.z, 0.0, normal.x).normalized() * _unstick_side

	return Vector3(-direction.z, 0.0, direction.x).normalized() * _unstick_side


func _nudge_off_wall() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal: Vector3 = collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() > 0.0001:
			global_position += normal.normalized() * 0.65
			return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.0001:
		global_position += to_player.normalized() * 0.45


func _physics_process(delta: float) -> void:
	if not _alive:
		return

	_damage_timer = maxf(0.0, _damage_timer - delta)
	var target := get_tree().get_first_node_in_group("player") as Node3D
	var dist := 0.0
	var wants_move := false
	if target != null:
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()
		wants_move = dist > stop_distance

		if wants_move:
			var direction := _compute_move_direction(target)
			direction = _steer_around_walls(direction)
			var speed := move_speed
			if _can_commit and dist < stop_distance * 2.5:
				speed *= commit_speed_multiplier
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			if direction.length_squared() > 0.001:
				look_at(global_position + direction, Vector3.UP)
			_visual_root.rotation.z = sin(Time.get_ticks_msec() * 0.012) * 0.035
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			if to_target.length_squared() > 0.001:
				look_at(global_position + to_target.normalized(), Vector3.UP)
			_try_damage_player(target)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	if not is_on_floor():
		velocity.y -= gravity * delta

	var position_before := global_position
	move_and_slide()

	if target != null and wants_move:
		var moved := Vector2(
			global_position.x - position_before.x,
			global_position.z - position_before.z
		).length()
		var direction := Vector3(velocity.x, 0.0, velocity.z)
		if direction.length_squared() > 0.01:
			direction = direction.normalized()
			var unstuck_dir := _apply_unstick(direction, moved)
			if unstuck_dir != direction:
				velocity.x = unstuck_dir.x * move_speed * 1.25
				velocity.z = unstuck_dir.z * move_speed * 1.25
				move_and_slide()


func _try_damage_player(target: Node3D) -> void:
	if _damage_timer > 0.0:
		return

	if target.has_method("take_damage"):
		target.take_damage(contact_damage, self)
		_damage_timer = damage_cooldown


func damage(_impact_point: Vector3, _force: Vector3) -> void:
	if not _alive:
		return

	_alive = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	defeated.emit()
	_spawn_death_puff()
	_flash_death_materials(_visual_root)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual_root, "scale", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual_root, "rotation:x", randf_range(-0.45, 0.45), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual_root, "rotation:z", randf_range(-0.7, 0.7), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func _spawn_death_puff() -> void:
	var puff := SMOKE_PUFF_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(puff)
	puff.global_position = global_position + Vector3.UP * 0.85
	puff.scale = Vector3.ONE * 0.78


func _flash_death_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.12, 0.05, 1.0)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.08, 0.03, 1.0)
		material.emission_energy_multiplier = 2.8
		material.roughness = 0.4
		mesh.material_override = material

	for child in node.get_children():
		_flash_death_materials(child)
