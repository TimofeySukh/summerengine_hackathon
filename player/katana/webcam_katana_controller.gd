class_name WebcamKatanaController
extends Node3D

## Single webcam katana driver — two identical WebcamKatana instances.

signal slash_struck

@onready var _camera: Camera3D = get_parent() as Camera3D
@onready var _blade_a: WebcamKatana = $BladeA
@onready var _blade_b: WebcamKatana = $BladeB

var _prev_left := Vector2(-1.0, -1.0)
var _prev_right := Vector2(-1.0, -1.0)


func _ready() -> void:
	_blade_a.setup(_camera, WebcamKatana.HandSlot.RIGHT)
	_blade_b.setup(_camera, WebcamKatana.HandSlot.LEFT)
	disable()


func enable() -> void:
	visible = true
	show()
	for blade in _blades():
		blade.set_active(true)
	# Default to screen center until UDP hands arrive.
	update_from_bridge(0.0, false, Vector2(0.5, 0.5), Vector2(0.5, 0.5))


func disable() -> void:
	visible = false
	_prev_left = Vector2(-1.0, -1.0)
	_prev_right = Vector2(-1.0, -1.0)
	for blade in _blades():
		blade.set_active(false)


func reset_tracking() -> void:
	_prev_left = Vector2(-1.0, -1.0)
	_prev_right = Vector2(-1.0, -1.0)
	for blade in _blades():
		blade.set_tracking(0.5, 0.5, 0.0)


func update_from_bridge(delta: float, has_hands: bool, left: Vector2, right: Vector2) -> void:
	if not has_hands:
		_prev_left = Vector2(-1.0, -1.0)
		_prev_right = Vector2(-1.0, -1.0)
		_blade_a.set_tracking(0.5, 0.5, 0.0)
		_blade_b.set_tracking(0.5, 0.5, 0.0)
		return

	var right_swing := _swing_amount(right, _prev_right, delta)
	var left_swing := _swing_amount(left, _prev_left, delta)
	_prev_left = left
	_prev_right = right
	# Mirror camera: physical right wrist -> blade A, physical left -> blade B.
	_blade_a.set_tracking(right.x, right.y, right_swing)
	_blade_b.set_tracking(left.x, left.y, left_swing)


func slash_camera_hand(hand: String) -> void:
	if hand == "left":
		_blade_b.trigger_hit()
	else:
		_blade_a.trigger_hit()
	slash_struck.emit()


func _blades() -> Array[WebcamKatana]:
	return [_blade_a, _blade_b]


func _swing_amount(current: Vector2, previous: Vector2, delta: float) -> float:
	if previous.x < 0.0 or delta <= 0.0:
		return 0.0
	var vel := (current - previous) / delta
	if vel.length() < 0.45:
		return 0.0
	var down := clampf(vel.y / 2.5, 0.0, 1.0)
	var speed := clampf(vel.length() / 3.2, 0.0, 1.0)
	return speed * (0.25 + 0.75 * down)
