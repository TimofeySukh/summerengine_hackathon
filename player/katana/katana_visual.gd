class_name KatanaVisual
extends Node3D

enum Hand { LEFT, RIGHT }

const SLASH_DURATION := 0.28
const HIT_TIME := 0.10
const SLASH_PEAK := 0.32

const MESH_BASIS := Basis(Vector3(0.0, -0.11, 0.0), Vector3(0.11, 0.0, 0.0), Vector3(0.0, 0.0, 0.11))
const MESH_ORIGIN := Vector3(0.16, 0.0, -0.08)

const HAND_LAYOUT := {
	Hand.LEFT: {
		"idle_pos": Vector3(-0.58, -0.20, -0.50),
		"idle_pivot": Vector3.ZERO,
		"cut_pos": Vector3(-0.18, -0.34, -0.42),
		"cut_pivot": Vector3(0.55, -0.15, 0.35),
		"mirror_mesh": true,
	},
	Hand.RIGHT: {
		"idle_pos": Vector3(-0.38, -0.20, -0.50),
		"idle_pivot": Vector3.ZERO,
		"cut_pos": Vector3(-0.58, -0.34, -0.42),
		"cut_pivot": Vector3(0.55, 0.15, -0.35),
		"mirror_mesh": false,
	},
}

@export var hand: Hand = Hand.RIGHT

signal slash_struck

@onready var _pivot: Node3D = $SlashPivot

var _tween: Tween
var _idle_pos: Vector3
var _idle_pivot: Vector3
var _cut_pos: Vector3
var _cut_pivot: Vector3


func _ready() -> void:
	_setup_hand_pose()
	_setup_mesh()
	reset_pose()
	_boost_materials(_pivot)


func is_slashing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func reset_pose() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_apply_pose(_idle_pos, _idle_pivot)


func play_slash() -> void:
	if is_slashing():
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_apply_slash_progress, 0.0, 1.0, SLASH_DURATION)
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
