extends Node3D

const SLASH_DURATION := 0.34

const IDLE_POSITION := Vector3(0.14, -0.22, -0.52)
const IDLE_PIVOT := Vector3(0.04, 0.10, -0.08)
const CUT_OFFSET := Vector3(0.05, -0.07, -0.05)

const CHAMBER_PIVOT := Vector3(-0.22, 0.08, 0.38)
const CUT_PIVOT := Vector3(0.26, 0.10, -0.68)

const CUT_END_T := 0.62

@onready var _slash_pivot: Node3D = $SlashPivot

var _attack_tween: Tween


func _ready() -> void:
	reset_pose()
	_boost_materials(_slash_pivot)


func reset_pose() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	position = IDLE_POSITION
	_slash_pivot.rotation = IDLE_PIVOT


func play_slash() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()

	_attack_tween = create_tween()
	_attack_tween.tween_method(_apply_cut, 0.0, 1.0, SLASH_DURATION)


func _apply_cut(t: float) -> void:
	if t <= CUT_END_T:
		var cut_t := pow(t / CUT_END_T, 1.35)
		position = IDLE_POSITION.lerp(IDLE_POSITION + CUT_OFFSET, cut_t)
		_slash_pivot.rotation = CHAMBER_PIVOT.lerp(CUT_PIVOT, cut_t)
		return

	var return_t := (t - CUT_END_T) / (1.0 - CUT_END_T)
	return_t = 1.0 - pow(1.0 - return_t, 2.0)
	position = (IDLE_POSITION + CUT_OFFSET).lerp(IDLE_POSITION, return_t)
	_slash_pivot.rotation = CUT_PIVOT.lerp(IDLE_PIVOT, return_t)


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
