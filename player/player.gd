class_name Player extends CharacterBody3D

signal weapon_switched(weapon_name: String)
signal health_changed(current: float, maximum: float)

enum WEAPON_TYPE { DEFAULT, GRENADE }

@export var max_health := 100.0
@export var slash_range := 14.0

@onready var _surveillance: CameraController = $SurveillanceMount
@onready var _attack_animation_player: AnimationPlayer = $CharacterRotationRoot/MeleeAnchor/AnimationPlayer
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _voice_jog: Node = $VoiceJogListener

var _start_position := Vector3.ZERO
var _health := max_health


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_position = global_position
	_surveillance.initialize()
	weapon_switched.emit(WEAPON_TYPE.keys()[0])
	_voice_jog.jog_forward.connect(_surveillance.start_jog_forward)
	_voice_jog.jog_stop.connect(_surveillance.stop_jog)
	_update_health_ui()

	if not InputMap.has_action("camera_jog_forward"):
		_register_surveillance_input_actions()


func _physics_process(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

	if Input.is_action_just_pressed("attack") and not _attack_animation_player.is_playing():
		attack()


func attack() -> void:
	_attack_animation_player.play("Attack")
	_hit_with_katana()


func take_damage(amount: float) -> void:
	_health = maxf(0.0, _health - amount)
	_update_health_ui()
	if _health <= 0.0:
		_respawn()


func damage(_impact_point: Vector3, _force: Vector3) -> void:
	take_damage(12.0)


func _respawn() -> void:
	global_position = _start_position
	_health = max_health
	_update_health_ui()


func _update_health_ui() -> void:
	_health_bar.max_value = max_health
	_health_bar.value = _health
	health_changed.emit(_health, max_health)


func _hit_with_katana() -> void:
	var ray := _surveillance.get_slash_ray()
	var origin: Vector3 = ray.origin
	var direction: Vector3 = ray.direction
	var ray_target := origin + direction * slash_range
	var space_state := get_world_3d().direct_space_state

	var ray_query := PhysicsRayQueryParameters3D.create(origin, ray_target)
	ray_query.exclude = [get_rid()]
	var ray_hit := space_state.intersect_ray(ray_query)
	if ray_hit.has("collider") and _damage_katana_target(ray_hit.collider, ray_hit.position, direction):
		return

	var shape := SphereShape3D.new()
	shape.radius = 0.65
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(Basis(), origin + direction * 2.4)
	shape_query.exclude = [get_rid()]

	for hit in space_state.intersect_shape(shape_query, 8):
		if hit.has("collider") and _damage_katana_target(hit.collider, origin + direction * 2.4, direction):
			return


func _damage_katana_target(target: Object, hit_position: Vector3, direction: Vector3) -> bool:
	if not target is Node3D:
		return false

	var body := target as Node3D
	if not body.is_in_group("damageables"):
		return false

	var impact_point := hit_position - body.global_position
	body.damage(impact_point, direction * 14.0)
	return true


func _register_surveillance_input_actions() -> void:
	const INPUT_ACTIONS := {
		"attack": MOUSE_BUTTON_LEFT,
		"pause": KEY_ESCAPE,
		"camera_jog_forward": KEY_M,
		"camera_jog_stop": KEY_N,
	}
	for action in INPUT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var input_key := InputEventKey.new()
		input_key.keycode = INPUT_ACTIONS[action]
		InputMap.action_add_event(action, input_key)
