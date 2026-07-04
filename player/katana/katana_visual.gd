extends Node3D

const IDLE_ROTATION := Vector3(0.06, 0.1, 0.0)
const IDLE_POSITION := Vector3(0.14, -0.22, -0.52)

@export var slash_color := Color(0.85, 0.95, 1.0, 0.72)

var _thrust_trail: MeshInstance3D
var _slash_material: StandardMaterial3D
var _slash_tween: Tween


func _ready() -> void:
	rotation = IDLE_ROTATION
	position = IDLE_POSITION
	_boost_materials(self)
	_create_thrust_trail()


func play_slash() -> void:
	if _thrust_trail == null:
		return

	if _slash_tween and _slash_tween.is_valid():
		_slash_tween.kill()

	_thrust_trail.visible = true
	_thrust_trail.scale = Vector3(0.6, 0.6, 0.55)
	_slash_material.albedo_color = slash_color
	_slash_material.emission = Color(slash_color.r, slash_color.g, slash_color.b, 1.0)

	var fade_color := slash_color
	fade_color.a = 0.0

	_slash_tween = create_tween().set_parallel(true)
	_slash_tween.tween_property(_thrust_trail, "scale", Vector3(1.05, 1.05, 1.35), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slash_tween.tween_property(_slash_material, "albedo_color", fade_color, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_slash_tween.chain().tween_callback(func() -> void: _thrust_trail.visible = false)


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


func _create_thrust_trail() -> void:
	_thrust_trail = MeshInstance3D.new()
	_thrust_trail.name = "ThrustTrail"
	_thrust_trail.mesh = _build_thrust_mesh()
	_thrust_trail.position = Vector3(0.0, 0.03, -0.16)
	_thrust_trail.visible = false
	_thrust_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_thrust_trail)

	_slash_material = StandardMaterial3D.new()
	_slash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_material.vertex_color_use_as_albedo = true
	_slash_material.albedo_color = slash_color
	_slash_material.emission_enabled = true
	_slash_material.emission = Color(slash_color.r, slash_color.g, slash_color.b, 1.0)
	_slash_material.emission_energy_multiplier = 1.8
	_slash_material.no_depth_test = true
	_thrust_trail.material_override = _slash_material


func _build_thrust_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-0.06, -0.03, -0.18),
		Vector3(0.06, -0.03, -0.18),
		Vector3(-0.1, 0.02, -0.75),
		Vector3(0.1, 0.02, -0.75),
		Vector3(0.0, 0.1, -1.45),
	])
	var colors := PackedColorArray([
		Color(slash_color.r, slash_color.g, slash_color.b, 0.0),
		Color(slash_color.r, slash_color.g, slash_color.b, 0.0),
		Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a),
		Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a),
		Color(slash_color.r, slash_color.g, slash_color.b, 0.0),
	])
	var indices := PackedInt32Array([
		0, 1, 2,
		1, 3, 2,
		2, 3, 4,
	])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
