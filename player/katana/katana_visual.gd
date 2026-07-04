class_name KatanaVisual
extends Node3D

enum Hand { LEFT, RIGHT }

const SLASH_DURATION := 0.28
const HIT_TIME := 0.10
const SLASH_PEAK := 0.32

const MESH_SCALE := 0.038
const MESH_BASIS := Basis(
	Vector3(0.0, -MESH_SCALE, 0.0),
	Vector3(MESH_SCALE, 0.0, 0.0),
	Vector3(0.0, 0.0, MESH_SCALE)
)
const MESH_ORIGIN := Vector3(0.16 * MESH_SCALE / 0.11, 0.0, -0.08 * MESH_SCALE / 0.11)
const IDLE_PIVOT_Y := PI
const IDLE_PIVOT_Z := PI * 0.5

const HAND_LAYOUT := {
	Hand.LEFT: {
		"idle_pos": Vector3(-0.23, -0.18, -0.42),
		"idle_pivot": Vector3(0.0, IDLE_PIVOT_Y, IDLE_PIVOT_Z),
		"cut_pos": Vector3(-0.14, -0.29, -0.38),
		"cut_pivot": Vector3(0.0, IDLE_PIVOT_Y, 0.75),
		"mirror_mesh": true,
	},
	Hand.RIGHT: {
		"idle_pos": Vector3(0.25, -0.29, -0.42),
		"idle_pivot": Vector3(0.0, IDLE_PIVOT_Y, IDLE_PIVOT_Z),
		"cut_pos": Vector3(0.16, -0.40, -0.38),
		"cut_pivot": Vector3(0.0, IDLE_PIVOT_Y, 0.75),
		"mirror_mesh": false,
	},
}

@export var hand: Hand = Hand.RIGHT

@export var webcam_pos_scale := Vector2(0.52, 0.62)
@export var webcam_max_offset := 0.38
@export var webcam_smoothing := 18.0

signal slash_struck

@onready var _pivot: Node3D = $SlashPivot

var _tween: Tween
var _idle_pos: Vector3
var _idle_pivot: Vector3
var _cut_pos: Vector3
var _cut_pivot: Vector3
var _webcam_tracking := false
var _webcam_target_pos: Vector3


func _ready() -> void:
	_setup_hand_pose()
	_setup_mesh()
	reset_pose()
	_boost_materials(_pivot)
	set_process(false)


func set_webcam_tracking(enabled: bool) -> void:
	_webcam_tracking = enabled
	set_process(enabled)


func set_webcam_hand_offset(offset_x: float, offset_y: float) -> void:
	var ox := clampf(offset_x * webcam_pos_scale.x, -webcam_max_offset, webcam_max_offset)
	var oy := clampf(offset_y * webcam_pos_scale.y, -webcam_max_offset, webcam_max_offset)
	_webcam_target_pos = _idle_pos + Vector3(ox, oy, 0.0)


func _process(delta: float) -> void:
	if not _webcam_tracking or is_slashing():
		return
	position = position.lerp(_webcam_target_pos, minf(1.0, delta * webcam_smoothing))
	_pivot.rotation = _idle_pivot


func is_slashing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func reset_pose() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _webcam_tracking:
		position = _webcam_target_pos
		_pivot.rotation = _idle_pivot
	else:
		_apply_pose(_idle_pos, _idle_pivot)


func play_slash() -> void:
	if is_slashing():
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	var slash_from := position if _webcam_tracking else _idle_pos
	var slash_from_pivot := _pivot.rotation if _webcam_tracking else _idle_pivot
	var slash_to := _cut_pos if not _webcam_tracking else _webcam_target_pos + (_cut_pos - _idle_pos)
	var slash_to_pivot := _cut_pivot

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(
		func(progress: float) -> void:
			if progress <= SLASH_PEAK:
				var local_t := progress / SLASH_PEAK
				local_t = pow(local_t, 0.70)
				_apply_pose(
					slash_from.lerp(slash_to, local_t),
					slash_from_pivot.lerp(slash_to_pivot, local_t)
				)
			else:
				var local_t := (progress - SLASH_PEAK) / (1.0 - SLASH_PEAK)
				local_t = 1.0 - pow(1.0 - local_t, 2.0)
				var return_pos := _webcam_target_pos if _webcam_tracking else _idle_pos
				var return_pivot := _idle_pivot
				_apply_pose(
					slash_to.lerp(return_pos, local_t),
					slash_to_pivot.lerp(return_pivot, local_t)
				),
		0.0,
		1.0,
		SLASH_DURATION
	)
	_tween.tween_callback(func(): slash_struck.emit()).set_delay(HIT_TIME)


func _setup_hand_pose() -> void:
	var layout: Dictionary = HAND_LAYOUT[hand]
	_idle_pos = layout.idle_pos
	_idle_pivot = layout.idle_pivot
	_cut_pos = layout.cut_pos
	_cut_pivot = layout.cut_pivot


func _setup_mesh() -> void:
	var layout: Dictionary = HAND_LAYOUT[hand]
	var katana := _pivot.get_node("Katana") as Node3D
	var mesh_basis := MESH_BASIS
	var mesh_origin := MESH_ORIGIN
	if layout.mirror_mesh:
		mesh_basis = mesh_basis * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
		mesh_origin.x = -mesh_origin.x
	katana.transform = Transform3D(mesh_basis, mesh_origin)


func _apply_slash_progress(progress: float) -> void:
	if progress <= SLASH_PEAK:
		var local_t := progress / SLASH_PEAK
		local_t = pow(local_t, 0.70)
		_apply_pose(
			_idle_pos.lerp(_cut_pos, local_t),
			_idle_pivot.lerp(_cut_pivot, local_t)
		)
	else:
		var local_t := (progress - SLASH_PEAK) / (1.0 - SLASH_PEAK)
		local_t = 1.0 - pow(1.0 - local_t, 2.0)
		_apply_pose(
			_cut_pos.lerp(_idle_pos, local_t),
			_cut_pivot.lerp(_idle_pivot, local_t)
		)


func _apply_pose(pos: Vector3, pivot_euler: Vector3) -> void:
	position = pos
	_pivot.rotation = pivot_euler


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
