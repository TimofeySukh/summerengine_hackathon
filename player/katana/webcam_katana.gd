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
const HANDLE_PLANE_Z := -0.42

@export var hand_slot: HandSlot = HandSlot.RIGHT
@export var hand_screen_y_bias := 0.10
@export var hand_local_y_offset := -0.06
@export var smoothing := 18.0
@export var swing_rise := 16.0
@export var swing_fall := 10.0
@export var handle_screen_margin := 52.0
@export var max_side_tilt := 0.55
@export var tilt_smoothing := 16.0

@onready var _pivot: Node3D = $SlashPivot
@onready var _katana_mesh: Node3D = $SlashPivot/Katana

var _camera: Camera3D
var _target_pos := Vector3.ZERO
var _swing_target := 0.0
var _swing_current := 0.0
var _tilt_target := 0.0
var _tilt_current := 0.0


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


func set_tracking(norm_x: float, norm_y: float, swing: float, side_tilt: float = 0.0) -> void:
	_swing_target = clampf(swing, 0.0, 1.0)
	_tilt_target = clampf(side_tilt, -max_side_tilt, max_side_tilt)
	if _camera == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var margin := handle_screen_margin
	var biased_y := clampf(norm_y + hand_screen_y_bias, 0.0, 1.0)
	var screen := Vector2(
		clampf(norm_x * viewport_size.x, margin, viewport_size.x - margin),
		clampf(biased_y * viewport_size.y, margin, viewport_size.y - margin)
	)
	_target_pos = _screen_to_handle_local(screen)
	_target_pos.y += hand_local_y_offset


func trigger_hit() -> void:
	pass


func _process(delta: float) -> void:
	position = position.lerp(_target_pos, minf(1.0, delta * smoothing))

	var swing_rate := swing_rise if _swing_target > _swing_current else swing_fall
	_swing_current = lerpf(_swing_current, _swing_target, minf(1.0, delta * swing_rate))
	_tilt_current = lerpf(_tilt_current, _tilt_target, minf(1.0, delta * tilt_smoothing))
	var base_pivot := IDLE_PIVOT.lerp(SWING_PIVOT, _swing_current)
	_pivot.rotation = base_pivot + Vector3(0.0, 0.0, _tilt_current)


func _screen_to_handle_local(screen: Vector2) -> Vector3:
	var ray_origin := _camera.project_ray_origin(screen)
	var ray_dir := _camera.project_ray_normal(screen)
	var anchor := _camera.to_global(Vector3(0.0, 0.0, HANDLE_PLANE_Z))
	var plane_normal := -_camera.global_transform.basis.z
	var denom := ray_dir.dot(plane_normal)
	if absf(denom) < 0.0001:
		return Vector3(0.0, 0.0, HANDLE_PLANE_Z)
	var t := (anchor - ray_origin).dot(plane_normal) / denom
	return _camera.to_local(ray_origin + ray_dir * t)


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
