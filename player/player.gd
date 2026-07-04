class_name Player extends CharacterBody3D

signal weapon_switched(weapon_name: String)
signal health_changed(current: float, maximum: float)
signal player_died

const BULLET_SCENE := preload("bullet.tscn")

enum WEAPON_TYPE { DEFAULT, GRENADE }

## Character maximum run speed on the ground.
@export var move_speed := 8.0
## Speed of shot bullets.
@export var bullet_speed := 10.0
## Max range to lock onto an enemy for a katana lunge.
@export var attack_lunge_target_range := 10.0
## How far from the enemy center the lunge stops (melee reach).
@export var attack_lunge_stop_margin := 0.35
## Forward lunge distance when no enemy is targeted.
@export var attack_lunge_fallback_distance := 1.5
## Movement acceleration (how fast character achieve maximum speed)
@export var acceleration := 4.0
## Jump impulse
@export var jump_initial_impulse := 12.0
## Jump impulse when player keeps pressing jump
@export var jump_additional_force := 4.5
## Player model rotation speed
@export var rotation_speed := 12.0
## Minimum horizontal speed on the ground. This controls when the character's animation tree changes
## between the idle and running states.
@export var stopping_speed := 1.0
## Max throwback force after player takes a hit
@export var max_throwback_force := 15.0
## Projectile cooldown
@export var shoot_cooldown := 0.5
## Grenade cooldown
@export var grenade_cooldown := 0.5
@export var max_health := 100.0
## Fraction of max health restored when the player kills an enemy.
@export_range(0.0, 1.0, 0.01) var kill_heal_percent := 0.25

@onready var _rotation_root: Node3D = $CharacterRotationRoot
@onready var _camera_controller: CameraController = $CameraController
@onready var _attack_animation_player: AnimationPlayer = $CharacterRotationRoot/MeleeAnchor/AnimationPlayer
@onready var _katana_left: KatanaVisual = $CameraController/PlayerCamera/KatanaVisualLeft
@onready var _katana_right: KatanaVisual = $CameraController/PlayerCamera/KatanaVisualRight
@onready var _ground_shapecast: ShapeCast3D = $GroundShapeCast
@onready var _grenade_aim_controller: GrenadeLauncher = $GrenadeLauncher
@onready var _character_skin: CharacterSkin = $CharacterRotationRoot/CharacterSkin
@onready var _ui_aim_recticle: ColorRect = %AimRecticle
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _step_sound: AudioStreamPlayer3D = $StepSound
@onready var _landing_sound: AudioStreamPlayer3D = $LandingSound

@onready var _equipped_weapon: WEAPON_TYPE = WEAPON_TYPE.DEFAULT
@onready var _move_direction := Vector3.ZERO
@onready var _last_strong_direction := Vector3.FORWARD
@onready var _gravity: float = -30.0
@onready var _ground_height: float = 0.0
@onready var _start_position := global_transform.origin
@onready var _is_on_floor_buffer := false
@onready var _health := max_health

@onready var _shoot_cooldown_tick := shoot_cooldown
@onready var _grenade_cooldown_tick := grenade_cooldown

var _lunge_active := false
var _lunge_start := Vector3.ZERO
var _lunge_end := Vector3.ZERO
var _lunge_elapsed := 0.0
var _is_dead := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_controller.call_deferred("setup", self)
	_grenade_aim_controller.visible = false
	weapon_switched.emit(WEAPON_TYPE.keys()[0])

	if not InputMap.has_action("move_left"):
		_register_input_actions()

	_character_skin.stepped.connect(play_foot_step_sound)
	_katana_left.slash_struck.connect(perform_katana_hit)
	_katana_right.slash_struck.connect(perform_katana_hit)
	_update_health_ui()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _ground_shapecast.get_collision_count() > 0:
		for collision_result in _ground_shapecast.collision_result:
			_ground_height = max(_ground_height, collision_result.point.y)
	else:
		_ground_height = global_position.y + _ground_shapecast.target_position.y
	if global_position.y < _ground_height:
		_ground_height = global_position.y

	var is_attacking := Input.is_action_just_pressed("attack") and not _is_katana_slashing()
	var is_just_attacking := Input.is_action_just_pressed("attack")
	var is_just_jumping := Input.is_action_just_pressed("jump") and is_on_floor()
	var is_aiming := false
	var is_air_boosting := Input.is_action_pressed("jump") and not is_on_floor() and velocity.y > 0.0
	var is_just_on_floor := is_on_floor() and not _is_on_floor_buffer

	_is_on_floor_buffer = is_on_floor()
	_move_direction = _get_camera_oriented_input()

	_last_strong_direction = (_camera_controller.global_transform.basis * Vector3.FORWARD).normalized()

	_orient_character_to_direction(_last_strong_direction, delta)

	var y_velocity := velocity.y
	velocity.y = 0.0
	if _lunge_active:
		_apply_attack_lunge(delta)
		velocity = Vector3.ZERO
	elif _is_katana_slashing():
		velocity = Vector3.ZERO
	else:
		velocity = velocity.lerp(_move_direction * move_speed, acceleration * delta)
		if _move_direction.length() == 0 and velocity.length() < stopping_speed:
			velocity = Vector3.ZERO
	velocity.y = y_velocity

	if is_aiming:
		_camera_controller.set_pivot(_camera_controller.CAMERA_PIVOT.OVER_SHOULDER)
		_grenade_aim_controller.throw_direction = _camera_controller.camera.quaternion * Vector3.FORWARD
		_grenade_aim_controller.from_look_position = _camera_controller.camera.global_position
		_ui_aim_recticle.visible = true
	else:
		_camera_controller.set_pivot(_camera_controller.CAMERA_PIVOT.THIRD_PERSON)
		_grenade_aim_controller.throw_direction = _last_strong_direction
		_grenade_aim_controller.from_look_position = global_position
		_ui_aim_recticle.visible = false

	if is_attacking and is_just_attacking:
		attack()

	if Input.is_action_just_pressed("katana_slash_left"):
		_slash_with_katana(_katana_left)
	if Input.is_action_just_pressed("katana_slash_right"):
		_slash_with_katana(_katana_right)

	velocity.y += _gravity * delta

	if is_just_jumping:
		velocity.y += jump_initial_impulse
	elif is_air_boosting:
		velocity.y += jump_additional_force * delta

	if is_just_jumping:
		_character_skin.jump()
	elif not is_on_floor() and velocity.y < 0:
		_character_skin.fall()
	elif is_on_floor():
		var xz_velocity := Vector3(velocity.x, 0, velocity.z)
		if xz_velocity.length() > stopping_speed:
			_character_skin.set_moving(true)
			_character_skin.set_moving_speed(inverse_lerp(0.0, move_speed, xz_velocity.length()))
		else:
			_character_skin.set_moving(false)

	if is_just_on_floor:
		_landing_sound.play()

	var position_before := global_position
	move_and_slide()
	var position_after := global_position

	var delta_position := position_after - position_before
	var epsilon := 0.001
	if delta_position.length() < epsilon and velocity.length() > epsilon:
		global_position += get_wall_normal() * 0.1


func attack() -> void:
	_slash_with_katana(_katana_right)


func _slash_with_katana(katana: KatanaVisual) -> void:
	if katana.is_slashing():
		return
	_begin_attack_lunge()
	katana.play_slash()
	_character_skin.punch()


func _is_katana_slashing() -> bool:
	return _katana_left.is_slashing() or _katana_right.is_slashing()


func perform_katana_hit() -> void:
	_hit_with_katana()


func _begin_attack_lunge() -> void:
	_lunge_active = false
	_lunge_elapsed = 0.0

	var lunge := _compute_attack_lunge()
	if lunge.distance < 0.05:
		return

	_lunge_start = global_position
	_lunge_end = global_position + lunge.direction * lunge.distance
	_lunge_active = true


func _apply_attack_lunge(delta: float) -> void:
	if not _lunge_active:
		return

	_lunge_elapsed += delta
	var duration := KatanaVisual.HIT_TIME
	var t := clampf(_lunge_elapsed / duration, 0.0, 1.0)
	t = 1.0 - pow(1.0 - t, 2.0)
	global_position = _lunge_start.lerp(_lunge_end, t)

	if _lunge_elapsed >= duration:
		global_position = _lunge_end
		_lunge_active = false


func _compute_attack_lunge() -> Dictionary:
	var origin := global_position
	var aim_collider := _camera_controller.get_aim_collider()
	if aim_collider is Node3D:
		var body := aim_collider as Node3D
		if body.is_in_group("damageables") and body != self:
			return _lunge_toward_node(body, origin)

	var nearest := _find_nearest_damageable(origin, attack_lunge_target_range)
	if nearest != null:
		return _lunge_toward_node(nearest, origin)

	return _lunge_forward(origin, attack_lunge_fallback_distance)


func _lunge_toward_node(target: Node3D, origin: Vector3) -> Dictionary:
	var target_pos := target.global_position
	if _camera_controller.get_aim_collider() == target:
		target_pos = _camera_controller.get_aim_target()
	target_pos.y = origin.y

	var to_target := target_pos - origin
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.05:
		return {"direction": Vector3.ZERO, "distance": 0.0}

	var direction := to_target / distance
	var travel := maxf(0.0, distance - attack_lunge_stop_margin)
	return {"direction": direction, "distance": travel}


func _lunge_forward(origin: Vector3, distance: float) -> Dictionary:
	var forward := _camera_controller.global_transform.basis * Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return {"direction": Vector3.ZERO, "distance": 0.0}

	forward = forward.normalized()
	var travel := _raycast_lunge_distance(origin, forward, distance, [get_rid()])
	return {"direction": forward, "distance": travel}


func _raycast_lunge_distance(origin: Vector3, direction: Vector3, max_distance: float, exclude: Array[RID] = []) -> float:
	var space_state := get_world_3d().direct_space_state
	var ray_origin := origin + Vector3.UP * 0.6
	var ray_target := ray_origin + direction * max_distance
	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	ray_query.exclude = exclude
	var hit := space_state.intersect_ray(ray_query)
	if hit.is_empty():
		return max_distance

	var hit_distance := ray_origin.distance_to(hit.position) - 0.35
	return clampf(hit_distance, 0.0, max_distance)


func _find_nearest_damageable(origin: Vector3, max_range: float) -> Node3D:
	var forward := _camera_controller.global_transform.basis * Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return null
	forward = forward.normalized()

	var best: Node3D = null
	var best_distance := max_range
	var cos_limit := cos(deg_to_rad(55.0))

	for node in get_tree().get_nodes_in_group("damageables"):
		if node == self or not node is Node3D:
			continue

		var body := node as Node3D
		var offset := body.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > max_range or distance < 0.05:
			continue

		if offset.normalized().dot(forward) < cos_limit:
			continue

		if distance < best_distance:
			best = body
			best_distance = distance

	return best


func shoot() -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.shooter = self
	var origin := global_position + Vector3.UP
	var aim_target := _camera_controller.get_aim_target()
	var aim_direction := (aim_target - origin).normalized()
	bullet.velocity = aim_direction * bullet_speed
	bullet.distance_limit = 14.0
	get_parent().add_child(bullet)
	bullet.global_position = origin


func reset_position() -> void:
	transform.origin = _start_position


func _get_camera_oriented_input() -> Vector3:
	if _is_katana_slashing():
		return Vector3.ZERO

	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var input := Vector3.ZERO
	input.x = raw_input.x * sqrt(1.0 - raw_input.y * raw_input.y / 2.0)
	input.z = raw_input.y * sqrt(1.0 - raw_input.x * raw_input.x / 2.0)

	input = _camera_controller.global_transform.basis * input
	input.y = 0.0
	return input


func play_foot_step_sound() -> void:
	_step_sound.pitch_scale = randfn(1.2, 0.2)
	_step_sound.play()


func damage(_impact_point: Vector3, force: Vector3) -> void:
	force.y = abs(force.y)
	velocity = force.limit_length(max_throwback_force)
	take_damage(12.0)


func take_damage(amount: float) -> void:
	if _is_dead:
		return

	_health = maxf(0.0, _health - amount)
	_update_health_ui()
	if _health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	_lunge_active = false
	velocity = Vector3.ZERO
	player_died.emit()


func is_dead() -> bool:
	return _is_dead


func respawn() -> void:
	_is_dead = false
	global_position = _start_position
	velocity = Vector3.ZERO
	_lunge_active = false
	_lunge_elapsed = 0.0
	_katana_left.reset_pose()
	_katana_right.reset_pose()
	_health = max_health
	_update_health_ui()


func _heal_from_kill() -> void:
	if _is_dead:
		return

	var heal_amount := max_health * kill_heal_percent
	_health = minf(max_health, _health + heal_amount)
	_update_health_ui()


func _update_health_ui() -> void:
	_health_bar.max_value = max_health
	_health_bar.value = _health
	health_changed.emit(_health, max_health)


func _hit_with_katana() -> void:
	var camera := _camera_controller.camera
	var direction := (camera.global_transform.basis * Vector3.FORWARD).normalized()
	var aim_target := _camera_controller.get_aim_target()
	var aim_collider := _camera_controller.get_aim_collider()

	if aim_collider != null and _damage_katana_target(aim_collider, aim_target, direction):
		return

	var origin := camera.global_position
	var ray_target := origin + direction * 8.0
	var space_state := get_world_3d().direct_space_state

	var ray_query := PhysicsRayQueryParameters3D.create(origin, ray_target)
	ray_query.exclude = [get_rid()]
	var ray_hit := space_state.intersect_ray(ray_query)
	if ray_hit.has("collider") and _damage_katana_target(ray_hit.collider, ray_hit.position, direction):
		return

	var shape := SphereShape3D.new()
	shape.radius = 1.4
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(Basis(), aim_target)
	shape_query.exclude = [get_rid()]

	for hit in space_state.intersect_shape(shape_query, 16):
		if hit.has("collider") and _damage_katana_target(hit.collider, aim_target, direction):
			return


func _damage_katana_target(target: Object, hit_position: Vector3, direction: Vector3) -> bool:
	if not target is Node3D:
		return false

	var body := target as Node3D
	if not body.is_in_group("damageables"):
		return false

	var impact_point := hit_position - body.global_position
	var force := direction * 14.0
	var was_alive: bool = body.has_method("is_alive") and body.is_alive()
	body.damage(impact_point, force)
	if was_alive and body.has_method("is_alive") and not body.is_alive():
		_heal_from_kill()
	return true


func _orient_character_to_direction(direction: Vector3, delta: float) -> void:
	var left_axis := Vector3.UP.cross(direction)
	var rotation_basis := Basis(left_axis, Vector3.UP, direction).get_rotation_quaternion()
	var model_scale := _rotation_root.transform.basis.get_scale()
	_rotation_root.transform.basis = Basis(_rotation_root.transform.basis.get_rotation_quaternion().slerp(rotation_basis, delta * rotation_speed)).scaled(
		model_scale,
	)


func _register_input_actions() -> void:
	const INPUT_ACTIONS := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S,
		"jump": KEY_SPACE,
		"attack": MOUSE_BUTTON_LEFT,
		"aim": MOUSE_BUTTON_RIGHT,
		"swap_weapons": KEY_TAB,
		"pause": KEY_ESCAPE,
		"camera_left": KEY_Q,
		"camera_right": KEY_E,
		"camera_up": KEY_R,
		"camera_down": KEY_F,
		"katana_slash_left": KEY_LEFT,
		"katana_slash_right": KEY_RIGHT,
	}
	for action in INPUT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var input_key = InputEventKey.new()
		input_key.keycode = INPUT_ACTIONS[action]
		InputMap.action_add_event(action, input_key)
