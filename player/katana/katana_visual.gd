extends Node3D

const SLASH_DURATION := 0.52

const IDLE_POSITION := Vector3(0.14, -0.22, -0.52)
const IDLE_ROTATION := Vector3(0.04, 0.12, -0.12)

const SWING_KEYFRAMES := [
	{
		"time": 0.00,
		"pos": IDLE_POSITION,
		"rot": IDLE_ROTATION,
	},
	{
		"time": 0.09,
		"pos": Vector3(0.07, -0.08, -0.44),
		"rot": Vector3(-0.48, 0.04, 0.62),
	},
	{
		"time": 0.24,
		"pos": Vector3(0.21, -0.31, -0.54),
		"rot": Vector3(0.18, 0.14, -0.82),
	},
	{
		"time": 0.33,
		"pos": Vector3(0.23, -0.34, -0.56),
		"rot": Vector3(0.24, 0.12, -0.98),
	},
	{
		"time": SLASH_DURATION,
		"pos": IDLE_POSITION,
		"rot": IDLE_ROTATION,
	},
]

@export var slash_color := Color(0.85, 0.95, 1.0, 0.72)

@onready var _slash_pivot: Node3D = $SlashPivot

var _slash_trail: MeshInstance3D
var _slash_material: StandardMaterial3D
var _attack_tween: Tween
var _vfx_tween: Tween
var _trail_started := false


func _ready() -> void:
	reset_pose()
	_boost_materials(_slash_pivot)
	_create_slash_trail()


func reset_pose() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	if _vfx_tween and _vfx_tween.is_valid():
		_vfx_tween.kill()
	_apply_pose(SWING_KEYFRAMES[0])


func play_slash() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()

	_trail_started = false
	_attack_tween = create_tween()
	_attack_tween.tween_method(_apply_swing, 0.0, SLASH_DURATION, SLASH_DURATION)


func _apply_swing(elapsed: float) -> void:
	_sample_swing(elapsed)
	if not _trail_started and elapsed >= 0.09:
		_trail_started = true
		_play_slash_trail()


func _sample_swing(elapsed: float) -> void:
	var clamped := clampf(elapsed, 0.0, SLASH_DURATION)

	for index in range(SWING_KEYFRAMES.size() - 1):
		var start_frame: Dictionary = SWING_KEYFRAMES[index]
		var end_frame: Dictionary = SWING_KEYFRAMES[index + 1]
		var end_time: float = end_frame["time"]

		if clamped > end_time:
			continue

		var start_time: float = start_frame["time"]
		var span := maxf(end_time - start_time, 0.0001)
		var raw_t := (clamped - start_time) / span
		_apply_pose_interpolated(start_frame, end_frame, _segment_ease(index, raw_t))
		return

	_apply_pose(SWING_KEYFRAMES[-1])


func _segment_ease(segment_index: int, t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	match segment_index:
		0:
			return clamped * clamped * (3.0 - 2.0 * clamped)
		1:
			return pow(clamped, 0.72)
		2:
			return 1.0 - pow(1.0 - clamped, 2.0)
		_:
			return clamped * clamped * (3.0 - 2.0 * clamped)


func _apply_pose(frame: Dictionary) -> void:
	position = frame["pos"]
	_slash_pivot.rotation = frame["rot"]


func _apply_pose_interpolated(start_frame: Dictionary, end_frame: Dictionary, t: float) -> void:
	position = start_frame["pos"].lerp(end_frame["pos"], t)

	var start_quat := Quaternion.from_euler(start_frame["rot"])
	var end_quat := Quaternion.from_euler(end_frame["rot"])
	_slash_pivot.quaternion = start_quat.slerp(end_quat, t)


func _play_slash_trail() -> void:
	if _slash_trail == null:
		return

	if _vfx_tween and _vfx_tween.is_valid():
		_vfx_tween.kill()

	_slash_trail.visible = true
	_slash_trail.scale = Vector3(0.35, 0.35, 0.35)
	_slash_material.albedo_color = slash_color
	_slash_material.emission = Color(slash_color.r, slash_color.g, slash_color.b, 1.0)

	var fade_color := slash_color
	fade_color.a = 0.0

	_vfx_tween = create_tween().set_parallel(true)
	_vfx_tween.tween_property(_slash_trail, "scale", Vector3(1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_vfx_tween.tween_property(_slash_material, "albedo_color", fade_color, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_vfx_tween.chain().tween_callback(func() -> void: _slash_trail.visible = false)


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


func _create_slash_trail() -> void:
	_slash_trail = MeshInstance3D.new()
	_slash_trail.name = "SlashTrail"
	_slash_trail.mesh = _build_blade_trail_mesh()
	_slash_trail.position = Vector3(0.08, 0.0, 0.0)
	_slash_trail.visible = false
	_slash_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slash_pivot.add_child(_slash_trail)

	_slash_material = StandardMaterial3D.new()
	_slash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_material.vertex_color_use_as_albedo = true
	_slash_material.albedo_color = slash_color
	_slash_material.emission_enabled = true
	_slash_material.emission = Color(slash_color.r, slash_color.g, slash_color.b, 1.0)
	_slash_material.emission_energy_multiplier = 1.9
	_slash_material.no_depth_test = true
	_slash_trail.material_override = _slash_material


func _build_blade_trail_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(0.0, -0.04, 0.0),
		Vector3(0.0, 0.04, 0.0),
		Vector3(0.55, -0.08, -0.02),
		Vector3(0.55, 0.08, -0.02),
		Vector3(1.05, -0.03, -0.04),
		Vector3(1.05, 0.03, -0.04),
	])
	var colors := PackedColorArray([
		Color(slash_color.r, slash_color.g, slash_color.b, 0.0),
		Color(slash_color.r, slash_color.g, slash_color.b, 0.0),
		Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a * 0.85),
		Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a * 0.85),
		Color(slash_color.r, slash_color.g, slash_color.b, 0.0),
		Color(slash_color.r, slash_color.g, slash_color.b, 0.0),
	])
	var indices := PackedInt32Array([
		0, 1, 2,
		1, 3, 2,
		2, 3, 4,
		3, 5, 4,
	])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
