class_name CameraController extends Node3D

enum CAMERA_PIVOT { OVER_SHOULDER, THIRD_PERSON }

@export var invert_mouse_y := false
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export_range(0.0, 8.0) var joystick_sensitivity := 2.0

@onready var camera: Camera3D = $PlayerCamera
@onready var _over_shoulder_pivot: Node3D = $CameraOverShoulderPivot
@onready var _camera_spring_arm: SpringArm3D = $CameraSpringArm
@onready var _third_person_pivot: Node3D = $CameraSpringArm/CameraThirdPersonPivot
@onready var _camera_raycast: RayCast3D = $PlayerCamera/CameraRayCast

var _aim_target: Vector3
var _aim_collider: Node
var _pivot: Node3D
var _current_pivot_type: CAMERA_PIVOT
var _rotation_input: float
var _mouse_input := false
var _offset: Vector3
var _anchor: CharacterBody3D
var _euler_rotation: Vector3


func _unhandled_input(event: InputEvent) -> void:
	if ControlMode.is_webcam():
		return
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * mouse_sensitivity


func _process(delta: float) -> void:
	if not _anchor:
		return

	if ControlMode.is_keyboard():
		_rotation_input += Input.get_action_raw_strength("camera_left") - Input.get_action_raw_strength("camera_right")

	if _camera_raycast.is_colliding():
		_aim_target = _camera_raycast.get_collision_point()
		_aim_collider = _camera_raycast.get_collider()
	else:
		_aim_target = _camera_raycast.global_transform * _camera_raycast.target_position
		_aim_collider = null

	# First-person camera follows the character directly, including jumps.
	global_position = _anchor.global_position + _offset

	# Horizontal look only — pitch is locked.
	_euler_rotation.x = 0.0
	if ControlMode.is_keyboard():
		_euler_rotation.y += _rotation_input * delta

	transform.basis = Basis.from_euler(_euler_rotation)

	camera.global_transform = _pivot.global_transform
	camera.rotation.z = 0
	if camera.has_method("update_shake"):
		camera.update_shake(delta)
		camera.apply_shake_offset()

	_rotation_input = 0.0


func setup(anchor: CharacterBody3D) -> void:
	if camera == null:
		camera = $PlayerCamera
	_anchor = anchor
	global_transform = _anchor.global_transform
	_offset = global_transform.origin - anchor.global_transform.origin
	set_pivot(CAMERA_PIVOT.THIRD_PERSON)
	camera.current = true
	camera.global_transform = camera.global_transform.interpolate_with(_pivot.global_transform, 0.1)
	_camera_spring_arm.add_excluded_object(_anchor.get_rid())
	_camera_raycast.add_exception_rid(_anchor.get_rid())


func set_pivot(pivot_type: CAMERA_PIVOT) -> void:
	if pivot_type == _current_pivot_type:
		return

	match (pivot_type):
		CAMERA_PIVOT.OVER_SHOULDER:
			_over_shoulder_pivot.look_at(_aim_target)
			_pivot = _over_shoulder_pivot
		CAMERA_PIVOT.THIRD_PERSON:
			_pivot = _third_person_pivot

	_current_pivot_type = pivot_type


func get_aim_target() -> Vector3:
	return _aim_target


func get_aim_collider() -> Node:
	if is_instance_valid(_aim_collider):
		return _aim_collider
	else:
		return null


func get_yaw() -> float:
	return _euler_rotation.y


func set_yaw(yaw: float) -> void:
	_euler_rotation.x = 0.0
	_euler_rotation.y = yaw
	transform.basis = Basis.from_euler(_euler_rotation)


func get_flat_forward() -> Vector3:
	var forward := global_transform.basis * Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.ZERO
	return forward.normalized()


func rotate_toward_direction(direction: Vector3, max_radians: float) -> void:
	var flat := direction
	flat.y = 0.0
	if flat.length_squared() < 0.0001 or max_radians <= 0.0:
		return
	flat = flat.normalized()
	var target_yaw := atan2(-flat.x, -flat.z)
	var new_yaw := rotate_toward(_euler_rotation.y, target_yaw, max_radians)
	set_yaw(new_yaw)
