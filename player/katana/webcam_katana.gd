class_name WebcamKatana
extends Node3D

## Identical webcam katana blade — same mesh/pivot; mirror is fixed per hand slot.

enum HandSlot { LEFT, RIGHT }

const MESH_SCALE := 0.038
const MESH_BASIS := Basis(
	Vector3(0.0, -MESH_SCALE, 0.0),
	Vector3(MESH_SCALE, 0.0, 0.0),
	Vector3(0.0, 0.0, MESH_SCALE)
)
const MESH_ORIGIN := Vector3(0.16 * MESH_SCALE / 0.11, 0.0, -0.08 * MESH_SCALE / 0.11)
const IDLE_PIVOT := Vector3(0.0, PI, PI * 0.5)
const SWING_PIVOT := Vector3(0.0, PI, 0.75)
const SLASH_DURATION := 0.28
const HIT_TIME := 0.10
const HANDLE_PLANE_Z := -0.42

signal slash_struck

@export var hand_slot: HandSlot = HandSlot.RIGHT
@export var smoothing := 28.0
@export var swing_rise := 22.0
@export var swing_fall := 14.0
@export var max_side_tilt := 0.72
@export var tilt_smoothing := 22.0
@export var screen_reach := 1.18

@onready var _pivot: Node3D = $SlashPivot
@onready var _katana_mesh: Node3D = $SlashPivot/Katana

var _camera: Camera3D
var _target_pos := Vector3.ZERO
var _swing_target := 0.0
var _swing_current := 0.0
var _tilt_target := 0.0
var _tilt_current := 0.0
var _slash_tween: Tween


func setup(camera: Camera3D, slot: HandSlot = HandSlot.RIGHT) -> void:
	_camera = camera
	hand_slot = slot
	_boost_materials(_pivot)
	_apply_mesh_mirror(hand_slot == HandSlot.LEFT)
	set_process(false)


func set_active(active: bool) -> void:
	set_process(active)
	visible = active
	if active:
		set_tracking(0.5, 0.5, 0.0)
		position = _target_pos
	else:
		_swing_target = 0.0
		_swing_current = 0.0
		_tilt_target = 0.0
		_tilt_current = 0.0
		_pivot.rotation = IDLE_PIVOT
		if _slash_tween and _slash_tween.is_valid():
			_slash_tween.kill()


func is_slashing() -> bool:
	return _slash_tween != null and _slash_tween.is_valid() and _slash_tween.is_running()


func set_tracking(norm_x: float, norm_y: float, swing: float, side_tilt: float = 0.0) -> void:
	_swing_target = clampf(swing, 0.0, 1.0)
	_tilt_target = clampf(side_tilt, -max_side_tilt, max_side_tilt)
	if _camera == null:
		return
	_target_pos = _screen_to_local(clampf(norm_x, 0.0, 1.0), clampf(norm_y, 0.0, 1.0))


func trigger_hit() -> void:
	if is_slashing():
		return
	if _slash_tween and _slash_tween.is_valid():
		_slash_tween.kill()

	_swing_target = 1.0
	_slash_tween = create_tween()
	_slash_tween.tween_callback(func(): slash_struck.emit()).set_delay(HIT_TIME)
	_slash_tween.tween_interval(maxf(0.0, SLASH_DURATION - HIT_TIME))
	_slash_tween.tween_callback(func(): _swing_target = 0.0)


func _process(delta: float) -> void:
	position = position.lerp(_target_pos, minf(1.0, delta * smoothing))

	var swing_rate := swing_rise if _swing_target > _swing_current else swing_fall
	_swing_current = lerpf(_swing_current, _swing_target, minf(1.0, delta * swing_rate))
	_tilt_current = lerpf(_tilt_current, _tilt_target, minf(1.0, delta * tilt_smoothing))
	var base_pivot := IDLE_PIVOT.lerp(SWING_PIVOT, _swing_current)
	_pivot.rotation = base_pivot + Vector3(0.0, 0.0, _tilt_current)


func _screen_to_local(norm_x: float, norm_y: float) -> Vector3:
	# Linear 1:1 map: same camera Y always -> same handle height, independent of X.
	var depth := absf(HANDLE_PLANE_Z)
	var fov_rad := deg_to_rad(_camera.fov)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_h := tan(fov_rad * 0.5) * depth * screen_reach
	var half_w := half_h * aspect
	var x := (norm_x - 0.5) * 2.0 * half_w
	var y := (0.5 - norm_y) * 2.0 * half_h
	return Vector3(x, y, HANDLE_PLANE_Z)


func _apply_mesh_mirror(mirror: bool) -> void:
	var mesh_basis := MESH_BASIS
	var mesh_origin := MESH_ORIGIN
	if mirror:
		mesh_basis = mesh_basis * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
		mesh_origin.x = -mesh_origin.x
	_katana_mesh.transform = Transform3D(mesh_basis, mesh_origin)


func _boost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			return
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface_idx in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_idx)
			var tuned: Material
			if material is StandardMaterial3D:
				tuned = _tune_standard(material as StandardMaterial3D)
			elif material != null:
				tuned = material.duplicate()
			else:
				tuned = StandardMaterial3D.new()
				(tuned as StandardMaterial3D).albedo_color = Color(0.15, 0.15, 0.2)
				(tuned as StandardMaterial3D).metallic = 0.6
				(tuned as StandardMaterial3D).roughness = 0.35
			mesh_instance.set_surface_override_material(surface_idx, tuned)
	for child in node.get_children():
		_boost_materials(child)


func _tune_standard(material: StandardMaterial3D) -> StandardMaterial3D:
	var tuned := material.duplicate() as StandardMaterial3D
	tuned.albedo_color = tuned.albedo_color.lerp(Color(0.12, 0.12, 0.18), 0.35)
	tuned.metallic = clampf(tuned.metallic + 0.25, 0.0, 1.0)
	tuned.roughness = clampf(tuned.roughness - 0.15, 0.08, 1.0)
	return tuned
