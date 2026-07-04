extends Node3D

const IDLE_ROTATION := Vector3(0.06, 0.1, 0.0)
const IDLE_POSITION := Vector3(0.14, -0.22, -0.52)
const WIND_ROTATION := Vector3(-0.08, 0.1, -0.28)
const WIND_POSITION := Vector3(0.2, -0.1, -0.44)
const SLASH_ROTATION := Vector3(0.48, 0.1, 0.52)
const SLASH_POSITION := Vector3(0.06, -0.3, -0.56)
const SLASH_SEGMENTS := 16

@export var slash_color := Color(0.85, 0.95, 1.0, 0.78)

var _slash_arc: MeshInstance3D
var _slash_material: StandardMaterial3D
var _attack_tween: Tween
var _vfx_tween: Tween


func _ready() -> void:
	reset_pose()
	_boost_materials(self)
	_create_slash_arc()


func reset_pose() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	if _vfx_tween and _vfx_tween.is_valid():
		_vfx_tween.kill()
	rotation = IDLE_ROTATION
	position = IDLE_POSITION


func play_slash() -> void:
	reset_pose()

	_attack_tween = create_tween()
	_attack_tween.tween_property(self, "rotation", WIND_ROTATION, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(self, "position", WIND_POSITION, 0.045)
	_attack_tween.chain().tween_callback(_play_slash_vfx)
	_attack_tween.chain().tween_property(self, "rotation", SLASH_ROTATION, 0.075).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_attack_tween.parallel().tween_property(self, "position", SLASH_POSITION, 0.075)
	_attack_tween.chain().tween_property(self, "rotation", IDLE_ROTATION, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(self, "position", IDLE_POSITION, 0.1)


func _play_slash_vfx() -> void:
	if _slash_arc == null:
		return

	if _vfx_tween and _vfx_tween.is_valid():
		_vfx_tween.kill()

	_slash_arc.visible = true
	_slash_arc.scale = Vector3(0.4, 0.4, 0.4)
	_slash_arc.rotation = Vector3(-0.1, 0.0, -0.48)
	_slash_material.albedo_color = slash_color
	_slash_material.emission = Color(slash_color.r, slash_color.g, slash_color.b, 1.0)

	var fade_color := slash_color
	fade_color.a = 0.0

	_vfx_tween = create_tween().set_parallel(true)
	_vfx_tween.tween_property(_slash_arc, "scale", Vector3(1.05, 1.05, 1.05), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_vfx_tween.tween_property(_slash_material, "albedo_color", fade_color, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_vfx_tween.chain().tween_callback(func() -> void: _slash_arc.visible = false)


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


func _create_slash_arc() -> void:
	_slash_arc = MeshInstance3D.new()
	_slash_arc.name = "SlashArc"
	_slash_arc.mesh = _build_diagonal_slash_mesh()
	_slash_arc.position = Vector3(0.0, 0.02, -0.52)
	_slash_arc.visible = false
	_slash_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_slash_arc)

	_slash_material = StandardMaterial3D.new()
	_slash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_material.vertex_color_use_as_albedo = true
	_slash_material.albedo_color = slash_color
	_slash_material.emission_enabled = true
	_slash_material.emission = Color(slash_color.r, slash_color.g, slash_color.b, 1.0)
	_slash_material.emission_energy_multiplier = 2.0
	_slash_material.no_depth_test = true
	_slash_arc.material_override = _slash_material


func _build_diagonal_slash_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var start_angle := deg_to_rad(52.0)
	var end_angle := deg_to_rad(-42.0)
	var inner_radius := 0.32
	var outer_radius := 1.1

	for i in SLASH_SEGMENTS + 1:
		var t := float(i) / float(SLASH_SEGMENTS)
		var angle := lerpf(start_angle, end_angle, t)
		var direction := Vector3(cos(angle), sin(angle), -0.05)
		var alpha := sin(t * PI) * slash_color.a
		vertices.append(direction * inner_radius)
		vertices.append(direction * outer_radius)
		colors.append(Color(slash_color.r, slash_color.g, slash_color.b, alpha * 0.15))
		colors.append(Color(slash_color.r, slash_color.g, slash_color.b, alpha))

	for i in SLASH_SEGMENTS:
		var base := i * 2
		indices.append_array([
			base,
			base + 1,
			base + 2,
			base + 1,
			base + 3,
			base + 2,
		])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
