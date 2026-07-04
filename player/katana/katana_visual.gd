extends Node3D

const SLASH_DURATION := 0.32
const IDLE_POSITION := Vector3(0.14, -0.22, -0.52)
const IDLE_EULER := Vector3(0.0, 0.08, 0.0)

const REST_TIP_DIR := Vector3(0.0, 0.0, -1.0)
const CHAMBER_TIP_RAW := Vector3(-0.34, 0.44, -0.83)
const CUT_TIP_RAW := Vector3(0.34, -0.44, -0.83)

const CHAMBER_END := 0.11
const CUT_END := 0.24

@onready var _slash_pivot: Node3D = $SlashPivot

var _attack_tween: Tween
var _slash_axis: Vector3
var _chamber_angle: float
var _cut_angle: float
var _chamber_tip_dir: Vector3
var _cut_tip_dir: Vector3


func _ready() -> void:
	_chamber_tip_dir = CHAMBER_TIP_RAW.normalized()
	_cut_tip_dir = CUT_TIP_RAW.normalized()
	_slash_axis = _chamber_tip_dir.cross(_cut_tip_dir).normalized()
	_chamber_angle = REST_TIP_DIR.signed_angle_to(_chamber_tip_dir, _slash_axis)
	_cut_angle = REST_TIP_DIR.signed_angle_to(_cut_tip_dir, _slash_axis)
	reset_pose()
	_boost_materials(_slash_pivot)


func reset_pose() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	position = IDLE_POSITION
	_apply_slash_angle(0.0)


func play_slash() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()

	_attack_tween = create_tween()
	_attack_tween.tween_method(_apply_slash_progress, 0.0, 1.0, SLASH_DURATION)


func _apply_slash_progress(progress: float) -> void:
	var angle := 0.0

	if progress <= CHAMBER_END:
		var local_t := progress / CHAMBER_END
		local_t = local_t * local_t * (3.0 - 2.0 * local_t)
		angle = lerpf(0.0, _chamber_angle, local_t)
	elif progress <= CUT_END:
		var local_t := (progress - CHAMBER_END) / (CUT_END - CHAMBER_END)
		local_t = pow(local_t, 0.7)
		angle = lerpf(_chamber_angle, _cut_angle, local_t)
	else:
		var local_t := (progress - CUT_END) / (1.0 - CUT_END)
		local_t = 1.0 - pow(1.0 - local_t, 2.0)
		angle = lerpf(_cut_angle, 0.0, local_t)

	_apply_slash_angle(angle)


func _apply_slash_angle(angle: float) -> void:
	var idle_basis := Basis.from_euler(IDLE_EULER)
	_slash_pivot.basis = Basis(_slash_axis, angle) * idle_basis


func _boost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			return

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
