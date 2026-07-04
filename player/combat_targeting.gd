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


func _aim_range(player: Player) -> float:
	return maxf(player.soft_aim_max_range, player.chain_target_range)


func update(player: Player, camera: CameraController, delta: float) -> void:
	_refresh_soft_lock(player, camera)

	if player.is_katana_slashing():
		return

	_apply_soft_aim(player, camera, delta)


func on_attack(player: Player, camera: CameraController) -> Node3D:
	var target := pick_lunge_target(player, camera)
	if target == null:
		target = _find_nearest(player, player.attack_lunge_max_range, false)
	if target != null:
		lock = target
		lock_mode = LockMode.ATTACK
		snap_aim_toward(player, camera, _flat_direction(player, target), player.attack_snap_turn_deg)
	return target


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
	lock_mode = LockMode.SOFT
	threat_until = 0.0
	lock = _find_best_target(
		player,
		camera,
		player.global_position,
		dead,
		_aim_range(player),
		player.soft_lock_acquire_half_angle_deg,
		false
	)
	if lock == null:
		lock = _find_nearest(player, _aim_range(player), false)


func pick_lunge_target(player: Player, camera: CameraController) -> Node3D:
	if is_lock_valid() and _flat_distance(player, lock) <= player.attack_lunge_max_range:
		return lock

	var crosshair := camera.get_aim_collider()
	if crosshair is Node3D:
		var body := crosshair as Node3D
		if _is_damageable(player, body) and _flat_distance(player, body) <= player.attack_lunge_max_range:
			return body

	var in_cone := _find_best_target(
		player,
		camera,
		player.global_position,
		null,
		player.attack_lunge_max_range,
		100.0,
		false
	)
	if in_cone != null:
		return in_cone

	return _find_nearest(player, player.attack_lunge_max_range, false)


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
		var dir := lock.global_position - player.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			return dir.normalized()
	return camera.get_flat_forward()


func snap_aim_toward(player: Player, camera: CameraController, direction: Vector3, max_deg: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	camera.rotate_toward_direction(direction, deg_to_rad(max_deg))
	player.sync_facing_from_camera()


func _refresh_soft_lock(player: Player, camera: CameraController) -> void:
	if is_threat_active() and is_lock_valid():
		return

	if not is_lock_valid():
		lock = null
		lock_mode = LockMode.NONE
	elif lock.has_method("is_alive") and not lock.is_alive():
		lock = null
		lock_mode = LockMode.NONE
	elif not is_threat_active():
		if _flat_distance(player, lock) > _aim_range(player) * 1.12:
			lock = null
			lock_mode = LockMode.NONE

	if lock_mode == LockMode.ATTACK and not player.is_katana_slashing():
		lock_mode = LockMode.SOFT if is_lock_valid() else LockMode.NONE

	var aim_range := _aim_range(player)
	var candidate := _find_best_target(
		player,
		camera,
		player.global_position,
		null,
		aim_range,
		player.soft_lock_acquire_half_angle_deg,
		false
	)
	if candidate == null:
		candidate = _find_nearest_in_front(player, camera, aim_range)
	if candidate == null:
		candidate = _find_nearest(player, aim_range, false)
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
	if candidate_dist + 1.0 < current_dist:
		lock = candidate
		lock_mode = LockMode.SOFT


func _apply_soft_aim(player: Player, camera: CameraController, delta: float) -> void:
	if not is_lock_valid():
		return

	var direction := lock.global_position - player.global_position
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
	var distance := _flat_distance(player, lock)
	var turn_speed_deg := player.soft_aim_turn_deg

	if is_threat_active():
		turn_speed_deg = lerpf(player.soft_aim_turn_deg, player.threat_aim_turn_deg, clampf(1.05 - facing, 0.35, 1.0))
	elif facing <= -0.2:
		turn_speed_deg *= 0.3
	else:
		var edge := clampf(facing, 0.0, 1.0)
		turn_speed_deg *= lerpf(0.55, 1.0, edge)

	var far_t := clampf(distance / _aim_range(player), 0.0, 1.0)
	turn_speed_deg *= lerpf(1.0, player.soft_aim_far_boost, far_t)

	turn_speed_deg = maxf(turn_speed_deg, player.soft_aim_turn_deg * 0.4)
	camera.rotate_toward_direction(direction, deg_to_rad(turn_speed_deg) * delta)
	player.sync_facing_from_camera()


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


func _find_nearest(player: Player, max_range: float, front_only: bool) -> Node3D:
	var forward := player.get_facing_direction()
	var best: Node3D = null
	var best_distance := max_range

	for body in _iter_targets(player):
		if body == player:
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
