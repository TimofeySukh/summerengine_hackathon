class_name Player extends CharacterBody3D

signal weapon_switched(weapon_name: String)
signal health_changed(current: float, maximum: float)
signal player_died

const BULLET_SCENE := preload("bullet.tscn")

enum WEAPON_TYPE { DEFAULT, GRENADE }

## Character maximum run speed on the ground.
@export var move_speed := 20.0
## Speed of shot bullets.
@export var bullet_speed := 10.0
## Max range to lock onto an enemy for a katana lunge.
@export var attack_lunge_max_range := 24.0
## Sprint speed during attack dash (m/s). Feels like an instant burst run, not a teleport.
@export var attack_lunge_speed := 78.0
## How far from the enemy center the lunge stops (melee reach).
@export var attack_lunge_stop_margin := 0.35
## Forward lunge distance when no enemy is targeted.
@export var attack_lunge_fallback_distance := 1.5
## Horizontal reach for katana hit detection.
@export var katana_melee_range := 3.6
## Half-angle of the katana hit cone in degrees.
@export var katana_hit_half_arc_deg := 40.0
## Max range to track an enemy for soft aim assist.
@export var soft_aim_max_range := 52.0
## Legacy alias kept for inspector compatibility; soft aim uses soft_aim_max_range.
@export var chain_target_range := 52.0
## Wider hit arc used for a queued chain target.
@export var chain_melee_half_arc_deg := 52.0
## Cone used only when acquiring a new soft lock (degrees, half-angle).
@export var soft_lock_acquire_half_angle_deg := 115.0
## Camera turn speed during soft aim assist (deg/s).
@export var soft_aim_turn_deg := 480.0
## Extra turn speed multiplier when the locked target is far away.
@export var soft_aim_far_boost := 1.45
## Camera turn speed when reacting to a rear threat (deg/s).
@export var threat_aim_turn_deg := 680.0
## Max camera snap on attack start (deg).
@export var attack_snap_turn_deg := 140.0
## After taking a hit, turn toward the attacker for this many seconds.
@export var threat_focus_duration := 1.35
## Faster camera pull when reacting to a rear threat.
@export var threat_aim_speed_multiplier := 2.8
## Movement acceleration (deceleration when releasing WASD)
@export var acceleration := 16.0
## Quick burst dash on Shift — distance, duration, cooldown.
@export var dash_distance := 10.0
@export var dash_duration := 0.2
@export var dash_cooldown := 0.9
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
## Cooldown for the voice-triggered WAVE superpower.
@export var voice_wave_cooldown := 4.0
## Outward force applied when WAVE clears enemies.
@export var voice_wave_force := 28.0

@onready var _rotation_root: Node3D = $CharacterRotationRoot
@onready var _camera_controller: CameraController = $CameraController
@onready var _attack_animation_player: AnimationPlayer = $CharacterRotationRoot/MeleeAnchor/AnimationPlayer
@onready var _katana_left: KatanaVisual = $CameraController/PlayerCamera/KatanaVisualLeft
@onready var _katana_right: KatanaVisual = $CameraController/PlayerCamera/KatanaVisualRight
@onready var _webcam_katanas: WebcamKatanaController = $CameraController/PlayerCamera/WebcamKatanaController
@onready var _ground_shapecast: ShapeCast3D = $GroundShapeCast
@onready var _grenade_aim_controller: GrenadeLauncher = $GrenadeLauncher
@onready var _character_skin: CharacterSkin = $CharacterRotationRoot/CharacterSkin
@onready var _ui_aim_recticle: ColorRect = %AimRecticle
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _step_sound: AudioStreamPlayer3D = $StepSound
@onready var _landing_sound: AudioStreamPlayer3D = $LandingSound
@onready var _combat_feel: Node = $CombatFeel
@onready var _shockwave: ShockwaveAbility = $ShockwaveAbility

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
var _lunge_direction := Vector3.ZERO
var _lunge_remaining := 0.0
var _lunge_target: Node3D = null
var _dash_active := false
var _dash_start := Vector3.ZERO
var _dash_end := Vector3.ZERO
var _dash_elapsed := 0.0
var _dash_cooldown_left := 0.0
var _combat_targeting := CombatTargeting.new()
var _is_dead := false
var _webcam_warned := false
var _voice_wave_timer := 0.0
var _webcam_slash_until := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_controller.call_deferred("setup", self)
	if ControlMode.is_webcam():
		CameraInputBridge.reset_session()
		_katana_left.visible = false
		_katana_right.visible = false
		_webcam_katanas.call_deferred("enable")
		_webcam_katanas.slash_struck.connect(perform_katana_hit)
		if not WebcamLauncher.is_running():
			WebcamLauncher.start()
	else:
		_katana_left.visible = true
		_katana_right.visible = true
		_webcam_katanas.disable()
	_grenade_aim_controller.visible = false
	weapon_switched.emit(WEAPON_TYPE.keys()[0])

	if not InputMap.has_action("move_left"):
		_register_input_actions()

	_character_skin.stepped.connect(play_foot_step_sound)
	_katana_left.slash_struck.connect(perform_katana_hit)
	_katana_right.slash_struck.connect(perform_katana_hit)
	_combat_feel.setup(_camera_controller.camera)
	_shockwave.setup(self, _combat_feel)
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

	_voice_wave_timer = maxf(0.0, _voice_wave_timer - delta)
	_is_on_floor_buffer = is_on_floor()
	_move_direction = _get_camera_oriented_input()

	_last_strong_direction = (_camera_controller.global_transform.basis * Vector3.FORWARD)
	_last_strong_direction.y = 0.0
	if _last_strong_direction.length_squared() > 0.0001:
		_last_strong_direction = _last_strong_direction.normalized()
	_combat_targeting.update(self, _camera_controller, delta)

	_orient_character_to_direction(_last_strong_direction, delta)

	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)

	if ControlMode.is_keyboard() \
			and Input.is_action_just_pressed("dash") \
			and is_on_floor() \
			and not _lunge_active \
			and not _dash_active \
			and not _is_katana_slashing():
		_begin_dash()

	var y_velocity := velocity.y
	velocity.y = 0.0
	if _lunge_active:
		_apply_attack_lunge(delta)
		velocity = Vector3.ZERO
	elif _dash_active:
		_apply_dash(delta)
		velocity = Vector3.ZERO
	elif _is_katana_slashing():
		velocity = Vector3.ZERO
	elif _move_direction.length_squared() > 0.01:
		velocity = _move_direction * move_speed
	else:
		velocity = velocity.move_toward(Vector3.ZERO, move_speed * acceleration * delta)
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

	if is_attacking and is_just_attacking and ControlMode.is_keyboard():
		attack()

	if ControlMode.is_keyboard():
		if Input.is_action_just_pressed("katana_slash_left"):
			_slash_with_katana(_katana_left)
		if Input.is_action_just_pressed("katana_slash_right"):
			_slash_with_katana(_katana_right)

	if Input.is_action_just_pressed("shockwave"):
		_shockwave.try_trigger()

	if ControlMode.is_webcam():
		_poll_webcam_slash()
		_poll_webcam_shockwave()
		_poll_voice_wave()
		_update_webcam_katanas(delta)
		if not _webcam_warned and not CameraInputBridge.is_stream_active():
			_webcam_warned = true
			push_warning("Webcam mode: waiting for pose_stream camera feed...")

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
		if _lunge_active or xz_velocity.length() > stopping_speed:
			_character_skin.set_moving(true)
			var speed_ref := attack_lunge_speed if _lunge_active else move_speed
			_character_skin.set_moving_speed(inverse_lerp(0.0, speed_ref, xz_velocity.length()))
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
	if ControlMode.is_webcam():
		return
	_slash_with_katana(_katana_right)


func _poll_webcam_slash() -> void:
	var hand := CameraInputBridge.poll_slash()
	if hand.is_empty() or _is_katana_slashing():
		return
	_combat_targeting.on_attack(self, _camera_controller)
	_begin_attack_lunge()
	_webcam_slash_until = Time.get_ticks_msec() / 1000.0 + KatanaVisual.SLASH_DURATION
	_webcam_katanas.slash_camera_hand(hand)
	_character_skin.punch()


func _poll_webcam_shockwave() -> void:
	if CameraInputBridge.poll_shockwave():
		_shockwave.try_trigger()


func _update_webcam_katanas(delta: float) -> void:
	_webcam_katanas.update_from_bridge(
		delta,
		CameraInputBridge.has_hands(),
		CameraInputBridge.get_left_hand_screen(),
		CameraInputBridge.get_right_hand_screen(),
	)


func _poll_voice_wave() -> void:
	if CameraInputBridge.poll_voice_wave():
		_trigger_voice_wave()


func _trigger_voice_wave() -> void:
	if _voice_wave_timer > 0.0:
		return
	_voice_wave_timer = voice_wave_cooldown

	var killed_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node3D:
			continue
		var body := node as Node3D
		if body.has_method("is_alive") and not body.is_alive():
			continue
		if not body.has_method("damage"):
			continue

		var direction := body.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() < 0.0001:
			direction = -_camera_controller.get_flat_forward()
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		direction = direction.normalized()
		body.damage(Vector3.ZERO, direction * voice_wave_force)
		killed_any = true

	if killed_any:
		_combat_feel.play_kill_feedback()


func _slash_with_katana(katana: KatanaVisual) -> void:
	if katana.is_slashing():
		return
	_combat_targeting.on_attack(self, _camera_controller)
	_begin_attack_lunge()
	katana.play_slash()
	_character_skin.punch()


func is_katana_slashing() -> bool:
	return _is_katana_slashing()


func is_attack_lunge_active() -> bool:
	return _lunge_active


func sync_facing_from_camera() -> void:
	_last_strong_direction = _camera_controller.get_flat_forward()
	if _last_strong_direction.length_squared() < 0.0001:
		_last_strong_direction = _camera_controller.global_transform.basis * Vector3.FORWARD
		_last_strong_direction.y = 0.0
	if _last_strong_direction.length_squared() > 0.0001:
		_last_strong_direction = _last_strong_direction.normalized()


func get_facing_direction() -> Vector3:
	var forward := _last_strong_direction
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		return forward.normalized()
	return _camera_controller.get_flat_forward()


func _is_katana_slashing() -> bool:
	if ControlMode.is_webcam():
		return Time.get_ticks_msec() / 1000.0 < _webcam_slash_until
	return _katana_left.is_slashing() or _katana_right.is_slashing()


func perform_katana_hit() -> void:
	_hit_with_katana()


func _begin_attack_lunge() -> void:
	_lunge_active = false
	_lunge_remaining = 0.0
	_lunge_target = null
	_lunge_direction = Vector3.ZERO

	var lunge := _compute_attack_lunge()
	if lunge.distance < 0.05:
		return

	_lunge_target = lunge.get("target")
	_lunge_direction = lunge.direction
	_lunge_remaining = lunge.distance
	_lunge_active = true


func _apply_attack_lunge(delta: float) -> void:
	if not _lunge_active:
		return
	if not _is_katana_slashing():
		_end_lunge()
		return

	if _lunge_target != null and is_instance_valid(_lunge_target):
		var to_target := _lunge_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			var stop_distance := attack_lunge_stop_margin + _get_body_collision_radius(_lunge_target)
			if to_target.length() <= stop_distance + 0.15:
				_end_lunge()
				return
			_lunge_direction = to_target.normalized()
			_camera_controller.rotate_toward_direction(
				_lunge_direction,
				deg_to_rad(threat_aim_turn_deg) * delta
			)
			sync_facing_from_camera()

	var step := attack_lunge_speed * delta
	if step >= _lunge_remaining:
		step = _lunge_remaining
		_end_lunge()
	else:
		_lunge_remaining -= step

	velocity.x = _lunge_direction.x * attack_lunge_speed
	velocity.z = _lunge_direction.z * attack_lunge_speed


func _end_lunge() -> void:
	_lunge_active = false
	_lunge_remaining = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _begin_dash() -> void:
	var direction := _move_direction
	if direction.length_squared() < 0.01:
		direction = _get_flat_forward()
	if direction.length_squared() < 0.01:
		return

	direction = direction.normalized()
	var travel := _clamp_lunge_travel(global_position, direction, dash_distance)
	if travel < 0.05:
		return

	_dash_start = global_position
	_dash_end = global_position + direction * travel
	_dash_active = true
	_dash_elapsed = 0.0
	_dash_cooldown_left = dash_cooldown


func _apply_dash(delta: float) -> void:
	if not _dash_active:
		return

	_dash_elapsed += delta
	var t := clampf(_dash_elapsed / dash_duration, 0.0, 1.0)
	t = 1.0 - pow(1.0 - t, 3.0)
	global_position = _dash_start.lerp(_dash_end, t)

	if _dash_elapsed >= dash_duration:
		global_position = _dash_end
		_dash_active = false


func _compute_attack_lunge() -> Dictionary:
	var origin := global_position
	var target := _combat_targeting.pick_lunge_target(self, _camera_controller)
	if target != null:
		return _lunge_toward_node(target, origin, attack_lunge_max_range)
	return _lunge_forward(origin, attack_lunge_fallback_distance)


func _lunge_forward(origin: Vector3, distance: float) -> Dictionary:
	var forward := _combat_targeting.get_aim_direction(self, _camera_controller)
	if forward.length_squared() < 0.0001:
		forward = get_facing_direction()
	if forward.length_squared() < 0.0001:
		return {"direction": Vector3.ZERO, "distance": 0.0, "target": null}

	var travel := _clamp_lunge_travel(origin, forward, distance)
	return {"direction": forward, "distance": travel, "target": null}


func _lunge_toward_node(target: Node3D, origin: Vector3, max_travel: float = -1.0) -> Dictionary:
	if max_travel < 0.0:
		max_travel = attack_lunge_max_range
	var target_pos := _get_body_aim_point(target, origin.y)
	if _camera_controller.get_aim_collider() == target:
		target_pos = _camera_controller.get_aim_target()
		target_pos.y = origin.y

	var to_target := target_pos - origin
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.05:
		return {"direction": Vector3.ZERO, "distance": 0.0, "target": null}

	var direction := to_target / distance
	var stop_distance := attack_lunge_stop_margin + _get_body_collision_radius(target)
	var travel := maxf(0.0, distance - stop_distance)
	travel = minf(travel, max_travel)
	travel = _clamp_lunge_travel(origin, direction, travel)
	return {"direction": direction, "distance": travel, "target": target}


func _clamp_lunge_travel(origin: Vector3, direction: Vector3, max_travel: float) -> float:
	if max_travel <= 0.0:
		return 0.0
	return _raycast_lunge_distance(origin, direction, max_travel, [get_rid()])


func _raycast_lunge_distance(origin: Vector3, direction: Vector3, max_distance: float, exclude: Array[RID] = []) -> float:
	var space_state := get_world_3d().direct_space_state
	var ray_origin := origin + Vector3.UP * 0.85
	var ray_target := ray_origin + direction * max_distance
	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	ray_query.exclude = exclude
	ray_query.collision_mask = 0xFFFFFFFF
	var hit := space_state.intersect_ray(ray_query)
	if hit.is_empty():
		return max_distance

	var body_radius := 0.0
	if hit.collider is Node3D:
		body_radius = _get_body_collision_radius(hit.collider as Node3D)

	var hit_distance := ray_origin.distance_to(hit.position) - body_radius - 0.15
	return clampf(hit_distance, 0.0, max_distance)


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


func take_damage(amount: float, attacker: Node3D = null) -> void:
	if _is_dead:
		return

	_combat_targeting.on_threat(self, attacker)
	_health = maxf(0.0, _health - amount)
	_update_health_ui()
	if _health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	_lunge_active = false
	_lunge_target = null
	_dash_active = false
	_dash_elapsed = 0.0
	_webcam_slash_until = 0.0
	_combat_targeting.reset()
	velocity = Vector3.ZERO
	player_died.emit()


func is_dead() -> bool:
	return _is_dead


func respawn() -> void:
	_is_dead = false
	global_position = _start_position
	velocity = Vector3.ZERO
	_lunge_active = false
	_lunge_remaining = 0.0
	_lunge_target = null
	_dash_active = false
	_dash_elapsed = 0.0
	_dash_cooldown_left = 0.0
	_webcam_slash_until = 0.0
	_combat_targeting.reset()
	_katana_left.reset_pose()
	_katana_right.reset_pose()
	_webcam_katanas.reset_tracking()
	_health = max_health
	_update_health_ui()
	_combat_feel.reset_feedback()


func _heal_from_kill() -> void:
	if _is_dead:
		return

	var heal_amount := max_health * kill_heal_percent
	_health = minf(max_health, _health + heal_amount)
	_update_health_ui()


func register_kill() -> void:
	_heal_from_kill()
	_combat_feel.play_kill_feedback()


func _update_health_ui() -> void:
	_health_bar.max_value = max_health
	_health_bar.value = _health
	health_changed.emit(_health, max_health)


func _hit_with_katana() -> void:
	var forward := _combat_targeting.get_aim_direction(self, _camera_controller)
	if forward.length_squared() < 0.0001:
		forward = _get_flat_forward()
	if forward.length_squared() < 0.0001:
		return

	var origin := global_position + Vector3.UP * 0.95
	var hit_target := _combat_targeting.pick_melee_target(self, _camera_controller, origin, forward)
	if hit_target == null and _lunge_target != null and is_instance_valid(_lunge_target):
		if _is_valid_melee_target(_lunge_target, origin, forward):
			hit_target = _lunge_target
	if hit_target == null:
		return

	var hit_position := _get_body_aim_point(hit_target, origin.y)
	_damage_katana_target(hit_target, hit_position, forward)


func _is_valid_melee_target(body: Node3D, origin: Vector3, forward: Vector3, half_arc_deg: float = -1.0) -> bool:
	if half_arc_deg < 0.0:
		half_arc_deg = katana_hit_half_arc_deg
	if not body.is_in_group("damageables") or body == self:
		return false
	if body.has_method("is_alive") and not body.is_alive():
		return false

	var offset := body.global_position - origin
	offset.y = 0.0
	var distance := offset.length()
	if distance > katana_melee_range or distance < 0.05:
		return false

	var facing := offset.normalized().dot(forward)
	return facing >= cos(deg_to_rad(half_arc_deg))


func _get_flat_forward() -> Vector3:
	var forward := _camera_controller.global_transform.basis * Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.ZERO
	return forward.normalized()


func _get_body_aim_point(body: Node3D, flat_y: float) -> Vector3:
	return Vector3(body.global_position.x, flat_y, body.global_position.z)


func _get_body_collision_radius(body: Node3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D:
			var shape := (child as CollisionShape3D).shape
			if shape is CapsuleShape3D:
				return (shape as CapsuleShape3D).radius
			if shape is SphereShape3D:
				return (shape as SphereShape3D).radius
			if shape is CylinderShape3D:
				return (shape as CylinderShape3D).radius
	return 0.45


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
	var killed: bool = was_alive and body.has_method("is_alive") and not body.is_alive()
	if killed:
		register_kill()
		_combat_targeting.on_kill(self, _camera_controller, body)
	elif was_alive:
		_combat_feel.play_slash_feedback()
	return killed


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
		"shockwave": KEY_G,
		"dash": KEY_SHIFT,
	}
	for action in INPUT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var input_key = InputEventKey.new()
		input_key.keycode = INPUT_ACTIONS[action]
		InputMap.action_add_event(action, input_key)
