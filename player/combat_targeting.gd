class_name CombatTargeting
extends RefCounted

## Unified soft-lock, threat focus, and attack targeting for katana combat.

const DAMAGEABLES_GROUP := "damageables"
const ENEMIES_GROUP := "enemies"

enum LockMode { NONE, SOFT, THREAT, ATTACK }

var lock: Node3D = null
var lock_mode := LockMode.NONE
var threat_until := 0.0

const STICKY_SCORE_BONUS := 2.2
const CROSSHAIR_SCORE_BONUS := 3.0
const NEARBY_SCORE_BONUS := 1.5


func reset() -> void:
	lock = null
	lock_mode = LockMode.NONE
	threat_until = 0.0


func is_lock_valid() -> bool:
	return lock != null and is_instance_valid(lock) \
		and (not lock.has_method("is_alive") or lock.is_alive())


func is_threat_active() -> bool:
	return lock_mode == LockMode.THREAT and Time.get_ticks_msec() / 1000.0 < threat_until


func _lunge_range(player: Player) -> float:
	return maxf(maxf(player.attack_lunge_max_range, player.soft_aim_max_range), 96.0)


func _aim_range(player: Player) -> float:
	return maxf(maxf(player.soft_aim_max_range, player.chain_target_range), 96.0)


func acquire_nearest_enemy(player: Player, exclude: Node3D = null) -> Node3D:
	return _find_nearest(player, 9999.0, false, exclude)


func update(player: Player, camera: CameraController, delta: float) -> void:
	_refresh_soft_lock(player, camera)
	_apply_soft_aim(player, camera, delta)


func on_attack(player: Player, camera: CameraController) -> Node3D:
	var target := acquire_nearest_enemy(player)
	if target != null:
		lock = target
		lock_mode = LockMode.ATTACK
		var aim_dir := player.get_enemy_track_point(target) - player.global_position
		aim_dir.y = 0.0
		if aim_dir.length_squared() < 0.0001:
			aim_dir = _flat_direction(player, target)
		if aim_dir.length_squared() > 0.0001:
			snap_aim_toward(player, camera, aim_dir.normalized(), player.attack_snap_turn_deg)
			camera.sync_camera_from_pivot()
		return target
	return null


func on_threat(player: Player, attacker: Node3D) -> void:
	var threat := attacker
	if not is_instance_valid(threat) or not _is_damageable(player, threat):
		threat = _find_nearest(player, _aim_range(player), false)
	if threat == null:
		return
	lock = threat
	lock_mode = LockMode.THREAT
	threat_until = Time.get_ticks_msec() / 1000.0 + player.threat_focus_duration


func on_kill(player: Player, camera: CameraController, dead: Node3D) -> void:
	threat_until = 0.0
	lock = acquire_nearest_enemy(player, dead)
	if lock != null:
		lock_mode = LockMode.SOFT
		var aim_dir := player.get_enemy_track_point(lock) - player.global_position
		aim_dir.y = 0.0
		if aim_dir.length_squared() > 0.0001:
			snap_aim_instant(player, camera, aim_dir.normalized())
	else:
		lock = null
		lock_mode = LockMode.NONE


func on_enemy_spawned(player: Player, camera: CameraController, enemy: Node3D) -> void:
	if not _is_damageable(player, enemy):
		return
	if is_lock_valid() and _flat_distance(player, lock) <= _flat_distance(player, enemy):
		return
	lock = enemy
	lock_mode = LockMode.SOFT
	var aim_dir := player.get_enemy_track_point(enemy) - player.global_position
	aim_dir.y = 0.0
	if aim_dir.length_squared() > 0.0001:
		snap_aim_instant(player, camera, aim_dir.normalized())


func force_reacquire_lock(player: Player, camera: CameraController) -> void:
	threat_until = 0.0
	lock = acquire_nearest_enemy(player)
	if lock == null:
		lock_mode = LockMode.NONE
		return
	lock_mode = LockMode.SOFT
	var direction := player.get_enemy_track_point(lock) - player.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		snap_aim_instant(player, camera, direction.normalized())


func has_line_of_sight_to(player: Player, body: Node3D) -> bool:
	return _has_line_of_sight(player, body)


func pick_lunge_target(player: Player, camera: CameraController) -> Node3D:
	if is_lock_valid():
		return lock
	return acquire_nearest_enemy(player)


func pick_melee_target(player: Player, camera: CameraController, origin: Vector3, forward: Vector3) -> Node3D:
	if is_lock_valid():
		var to_lock := lock.global_position - origin
		to_lock.y = 0.0
		if to_lock.length_squared() > 0.0001:
			var aim_forward := to_lock.normalized()
			if _is_valid_melee(player, lock, origin, aim_forward, player.chain_melee_half_arc_deg):
				return lock
			if _is_valid_melee(player, lock, origin, forward, player.chain_melee_half_arc_deg):
				return lock

	var crosshair := camera.get_aim_collider()
	if crosshair is Node3D and _is_valid_melee(player, crosshair as Node3D, origin, forward):
		return crosshair as Node3D

	var shape_hit := _query_melee_shape(player, origin, forward)
	if shape_hit != null:
		return shape_hit

	if is_lock_valid() and _flat_distance(player, lock) <= player.katana_melee_range * 1.35:
		return lock

	return _find_best_melee_in_cone(player, origin, forward)


func get_aim_direction(player: Player, camera: CameraController) -> Vector3:
	if is_lock_valid():
		var dir := player.get_enemy_track_point(lock) - player.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			return dir.normalized()
	return camera.get_flat_forward()


func snap_aim_toward(player: Player, camera: CameraController, direction: Vector3, max_deg: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	camera.rotate_toward_direction(direction, deg_to_rad(max_deg))
	player.sync_facing_from_camera()


func snap_aim_instant(player: Player, camera: CameraController, direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	camera.snap_to_direction(direction)
	player.sync_facing_from_camera()
	camera.sync_camera_from_pivot()


func get_nearest_in_range(player: Player, max_range: float) -> Node3D:
	if is_lock_valid() and _flat_distance(player, lock) <= max_range:
		return lock
	return _find_nearest(player, max_range, false)


func facing_dot_to(player: Player, camera: CameraController, body: Node3D) -> float:
	var to_target := player.get_enemy_track_point(body) - player.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return 1.0
	var forward := camera.get_flat_forward()
	if forward.length_squared() < 0.0001:
		forward = player.get_facing_direction()
	if forward.length_squared() < 0.0001:
		return -1.0
	return forward.normalized().dot(to_target.normalized())


func _refresh_soft_lock(player: Player, camera: CameraController) -> void:
	if not is_lock_valid():
		lock = null
		lock_mode = LockMode.NONE
	elif lock.has_method("is_alive") and not lock.is_alive():
		lock = null
		lock_mode = LockMode.NONE

	if lock_mode == LockMode.ATTACK and not player.is_attack_lunge_active():
		lock_mode = LockMode.SOFT if is_lock_valid() else LockMode.NONE

	if is_threat_active() and is_lock_valid():
		return

	var aim_range := _aim_range(player)
	var candidate: Node3D = null
	if lock == null:
		candidate = acquire_nearest_enemy(player)
	if candidate == null and lock == null:
		candidate = _find_best_target(
			player,
			camera,
			player.global_position,
			null,
			aim_range,
			180.0,
			false
		)
	if candidate == null:
		return

	if lock == null:
		lock = candidate
		lock_mode = LockMode.SOFT
		return

	if candidate == lock:
		return

	var current_dist := _flat_distance(player, lock)
	var candidate_dist := _flat_distance(player, candidate)
	if candidate_dist + 2.5 < current_dist:
		lock = candidate
		lock_mode = LockMode.SOFT


func _apply_soft_aim(player: Player, camera: CameraController, delta: float) -> void:
	if not is_lock_valid():
		lock = acquire_nearest_enemy(player)
		if lock == null:
			return
		lock_mode = LockMode.SOFT

	var aim_body := lock
	var direction := player.get_enemy_track_point(aim_body) - player.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()

	var forward := camera.get_flat_forward()
	if forward.length_squared() < 0.0001:
		forward = player.get_facing_direction()
	if forward.length_squared() < 0.0001:
		return

	var facing := forward.dot(direction)
	var angle_deg := rad_to_deg(acos(clampf(facing, -1.0, 1.0)))
	if angle_deg > 28.0:
		snap_aim_instant(player, camera, direction)
		return

	var distance := _flat_distance(player, aim_body)
	var turn_speed_deg := player.soft_aim_turn_deg
	var crosshair := camera.get_aim_collider()
	var on_locked_target := crosshair == aim_body

	if angle_deg > 20.0:
		var misalign := clampf((angle_deg - 20.0) / 160.0, 0.0, 1.0)
		turn_speed_deg = lerpf(player.threat_aim_turn_deg, player.threat_aim_turn_deg * 6.0, misalign)
	elif is_threat_active():
		turn_speed_deg = lerpf(player.soft_aim_turn_deg, player.threat_aim_turn_deg, clampf(1.05 - facing, 0.35, 1.0))
	elif not on_locked_target:
		turn_speed_deg = maxf(turn_speed_deg, player.threat_aim_turn_deg)
	else:
		var edge := clampf(facing, 0.0, 1.0)
		turn_speed_deg *= lerpf(0.85, 1.0, edge)

	var far_t := clampf(distance / _aim_range(player), 0.0, 1.0)
	turn_speed_deg *= lerpf(1.0, player.soft_aim_far_boost, far_t)

	camera.rotate_toward_direction(direction, deg_to_rad(turn_speed_deg) * delta)
	player.sync_facing_from_camera()
	camera.sync_camera_from_pivot()


func _find_best_target(
	player: Player,
	camera: CameraController,
	origin: Vector3,
	exclude: Node3D,
	max_range: float,
	half_angle_deg: float,
	require_front: bool
) -> Node3D:
	var forward := camera.get_flat_forward()
	if forward.length_squared() < 0.0001:
		forward = player.get_facing_direction()
	if forward.length_squared() < 0.0001:
		forward = -player.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0001:
			forward = forward.normalized()

	var crosshair := camera.get_aim_collider()
	var cos_limit := cos(deg_to_rad(half_angle_deg))
	var best: Node3D = null
	var best_score := -INF

	for body in _iter_targets(player):
		if body == player or body == exclude:
			continue
		if not _is_damageable(player, body):
			continue

		var offset := body.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > max_range or distance < 0.05:
			continue

		var facing := offset.normalized().dot(forward)
		if require_front and facing <= 0.0:
			continue
		if facing < cos_limit:
			continue

		var score := facing * 5.0 - distance * 0.1
		if body == lock:
			score += STICKY_SCORE_BONUS
		if body == crosshair:
			score += CROSSHAIR_SCORE_BONUS
		if distance < max_range * 0.35:
			score += NEARBY_SCORE_BONUS
		if score > best_score:
			best_score = score
			best = body

	return best


func _iter_targets(player: Player) -> Array[Node3D]:
	var seen: Dictionary = {}
	var result: Array[Node3D] = []

	for node in player.get_tree().get_nodes_in_group(ENEMIES_GROUP):
		if node is Node3D and not seen.has(node):
			seen[node] = true
			result.append(node as Node3D)

	for node in player.get_tree().get_nodes_in_group(DAMAGEABLES_GROUP):
		if node is Node3D and not seen.has(node):
			seen[node] = true
			result.append(node as Node3D)

	return result


func _find_nearest_in_front(player: Player, camera: CameraController, max_range: float) -> Node3D:
	var forward := camera.get_flat_forward()
	if forward.length_squared() < 0.0001:
		forward = player.get_facing_direction()

	var best: Node3D = null
	var best_distance := max_range
	for body in _iter_targets(player):
		if body == player or not _is_damageable(player, body):
			continue
		var offset := body.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() < 0.0001:
			continue
		if forward.length_squared() > 0.0001 and offset.normalized().dot(forward) <= 0.05:
			continue
		var distance := _flat_distance(player, body)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func _find_nearest(player: Player, max_range: float, front_only: bool, exclude: Node3D = null) -> Node3D:
	var forward := player.get_facing_direction()
	var best: Node3D = null
	var best_distance := max_range

	for body in _iter_targets(player):
		if body == player or body == exclude:
			continue
		if not _is_damageable(player, body):
			continue
		if front_only and forward.length_squared() > 0.0001:
			var offset := body.global_position - player.global_position
			offset.y = 0.0
			if offset.length_squared() > 0.0001 and offset.normalized().dot(forward) <= 0.0:
				continue
		var distance := _flat_distance(player, body)
		if distance < best_distance:
			best_distance = distance
			best = body

	return best


func _find_nearest_with_los(player: Player, max_range: float) -> Node3D:
	var best: Node3D = null
	var best_distance := max_range
	for body in _iter_targets(player):
		if body == player or not _is_damageable(player, body):
			continue
		if not _has_line_of_sight(player, body):
			continue
		var distance := _flat_distance(player, body)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func _find_best_melee_in_cone(player: Player, origin: Vector3, forward: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := -INF
	for body in _iter_targets(player):
		if body == player:
			continue
		if not _is_valid_melee(player, body, origin, forward):
			continue
		var score := _score_melee(player, body, origin, forward)
		if score > best_score:
			best_score = score
			best = body
	return best


func _query_melee_shape(player: Player, origin: Vector3, forward: Vector3) -> Node3D:
	var space_state := player.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.95
	capsule.height = 2.4

	var sweep_center := origin + forward * minf(player.katana_melee_range * 0.55, 1.8)
	var basis := Basis.looking_at(forward, Vector3.UP)
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = capsule
	shape_query.transform = Transform3D(basis, sweep_center)
	shape_query.exclude = [player.get_rid()]
	shape_query.collide_with_bodies = true
	shape_query.collide_with_areas = false

	var best: Node3D = null
	var best_score := -INF
	for hit in space_state.intersect_shape(shape_query, 16):
		if not hit.has("collider") or not hit.collider is Node3D:
			continue
		var body := hit.collider as Node3D
		if not _is_valid_melee(player, body, origin, forward):
			continue
		var score := _score_melee(player, body, origin, forward)
		if score > best_score:
			best_score = score
			best = body
	return best


func _is_valid_melee(
	player: Player,
	body: Node3D,
	origin: Vector3,
	forward: Vector3,
	half_arc_deg: float = -1.0
) -> bool:
	if half_arc_deg < 0.0:
		half_arc_deg = player.katana_hit_half_arc_deg
	if not _is_damageable(player, body):
		return false
	var offset := body.global_position - origin
	offset.y = 0.0
	var distance := offset.length()
	if distance > player.katana_melee_range or distance < 0.05:
		return false
	return offset.normalized().dot(forward) >= cos(deg_to_rad(half_arc_deg))


func _score_melee(player: Player, body: Node3D, origin: Vector3, forward: Vector3) -> float:
	var offset := body.global_position - origin
	offset.y = 0.0
	var distance := offset.length()
	var facing := offset.normalized().dot(forward)
	var score := facing * 3.0 - distance * 0.35
	if body == lock:
		score += STICKY_SCORE_BONUS
	return score


func _is_damageable(player: Player, body: Node3D) -> bool:
	if body == player:
		return false
	if not body.is_in_group(DAMAGEABLES_GROUP) and not body.is_in_group(ENEMIES_GROUP):
		return false
	if body.has_method("is_alive") and not body.is_alive():
		return false
	return true


func _flat_direction(player: Player, body: Node3D) -> Vector3:
	var dir := body.global_position - player.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()


func _flat_distance(player: Player, body: Node3D) -> float:
	return Vector2(
		body.global_position.x - player.global_position.x,
		body.global_position.z - player.global_position.z
	).length()


func _has_line_of_sight(player: Player, body: Node3D) -> bool:
	var space_state := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3.UP * 0.95
	var target := player.get_enemy_track_point(body)
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collision_mask = 1
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return _ray_hit_is_body(hit, body)


func _ray_hit_is_body(hit: Dictionary, body: Node3D) -> bool:
	if not hit.has("collider"):
		return false
	var collider: Object = hit.collider
	if collider == body:
		return true
	if collider is Node:
		var node := collider as Node
		return body == node or body.is_ancestor_of(node)
	return false
