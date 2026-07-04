class_name CameraShake
extends Camera3D

@export var trauma_decay := 2.4
@export var max_shake_offset := 0.11
@export var max_shake_roll := 0.035

var _trauma := 0.0
var _shake_offset := Vector3.ZERO


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func reset_trauma() -> void:
	_trauma = 0.0
	_shake_offset = Vector3.ZERO


func update_shake(delta: float) -> void:
	if _trauma <= 0.001:
		_shake_offset = Vector3.ZERO
		return

	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	var shake_amount := _trauma * _trauma
	_shake_offset = Vector3(
		randf_range(-1.0, 1.0) * max_shake_offset * shake_amount,
		0.0,
		randf_range(-1.0, 1.0) * max_shake_roll * shake_amount
	)


func apply_shake_offset() -> void:
	if _shake_offset == Vector3.ZERO:
		return
	rotate_object_local(Vector3.RIGHT, _shake_offset.x)
	rotate_object_local(Vector3.FORWARD, _shake_offset.z)
