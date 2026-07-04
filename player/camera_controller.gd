class_name CameraController extends Node3D

@export var invert_mouse_y := false
@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity := 0.0025
@export var jog_pan_speed := 0.42
@export var yaw_min := -1.35
@export var yaw_max := 1.35
@export var pitch_min := -0.55
@export var pitch_max := 0.35

@onready var camera: Camera3D = $FeedCamera
@onready var _slash_raycast: RayCast3D = $FeedCamera/SlashRayCast

var _pan_yaw := 0.0
var _pan_pitch := 0.0
var _mouse_delta := Vector2.ZERO
var _jog_forward := false


func initialize() -> void:
	_pan_yaw = rotation.y
	_pan_pitch = rotation.x
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta.x -= event.relative.x * mouse_sensitivity
		_mouse_delta.y -= event.relative.y * mouse_sensitivity


func _process(delta: float) -> void:
	_pan_yaw += _mouse_delta.x
	var tilt_delta := _mouse_delta.y
	if invert_mouse_y:
		tilt_delta = -tilt_delta
	_pan_pitch += tilt_delta

	if _jog_forward:
		_pan_yaw += jog_pan_speed * delta

	_pan_yaw = clampf(_pan_yaw, yaw_min, yaw_max)
	_pan_pitch = clampf(_pan_pitch, pitch_min, pitch_max)
	_apply_rotation()

	_mouse_delta = Vector2.ZERO


func start_jog_forward() -> void:
	_jog_forward = true


func stop_jog() -> void:
	_jog_forward = false


func get_aim_target() -> Vector3:
	if _slash_raycast.is_colliding():
		return _slash_raycast.get_collision_point()
	return _slash_raycast.global_transform * _slash_raycast.target_position


func get_aim_collider() -> Node:
	if _slash_raycast.is_colliding():
		return _slash_raycast.get_collider()
	return null


func get_slash_ray() -> Dictionary:
	var origin := camera.global_position
	var direction := -(camera.global_transform.basis.z).normalized()
	return {"origin": origin, "direction": direction}


func _apply_rotation() -> void:
	rotation = Vector3(_pan_pitch, _pan_yaw, 0.0)
