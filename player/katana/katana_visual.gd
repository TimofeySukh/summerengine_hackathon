extends Node3D

const IDLE_ROTATION := Vector3(0.06, 0.1, 0.0)
const SLASH_SEGMENTS := 18

@export var slash_color := Color(0.85, 0.95, 1.0, 0.72)
@export var slash_trigger_angle := 0.22
@export var slash_cooldown := 0.12

var _slash_arc: MeshInstance3D
var _slash_material: StandardMaterial3D
var _slash_tween: Tween
var _last_rotation := IDLE_ROTATION
var _cooldown := 0.0
var _armed := false

func _ready() -> void:
	rotation = IDLE_ROTATION
	_boost_materials(self)
	_create_slash_arc()
	_last_rotation = rotation


func _process(delta: float) -> void:
	if not _armed:
		_last_rotation = rotation
		_armed = true
		return

	_cooldown = maxf(0.0, _cooldown - delta)

	var angular_delta := (rotation - _last_rotation).length()
	if angular_delta >= slash_trigger_angle and _cooldown <= 0.0:
		play_slash()
		_cooldown = slash_cooldown

	_last_rotation = rotation


func play_slash() -> void:
	if _slash_arc == null:
		return

	if _slash_tween and _slash_tween.is_valid():
		_slash_tween.kill()

	_slash_arc.visible = true
	_slash_arc.scale = Vector3(0.55, 0.55, 0.55)
	_slash_arc.rotation = Vector3(-0.62, 0.28, randf_range(-0.08, 0.08))
	_slash_material.albedo_color = slash_color
	_slash_material.emission = Color(slash_color.r, slash_color.g, slash_color.b, 1.0)

	var fade_color := slash_color
	fade_color.a = 0.0

	_slash_tween = create_tween().set_parallel(true)
	_slash_tween.tween_property(_slash_arc, "scale", Vector3(1.08, 1.08, 1.08), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slash_tween.tween_property(_slash_arc, "rotation:z", _slash_arc.rotation.z - 0.34, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slash_tween.tween_property(_slash_material, "albedo_color", fade_color, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_slash_tween.chain().tween_callback(func() -> void: _slash_arc.visible = false)


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
	_slash_arc.mesh = _build_slash_mesh()
	_slash_arc.position = Vector3(0.0, 0.03, -0.58)
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
	_slash_material.emission_energy_multiplier = 1.8
	_slash_material.no_depth_test = true
	_slash_arc.material_override = _slash_material


func _build_slash_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var start_angle := deg_to_rad(-68.0)
	var end_angle := deg_to_rad(68.0)
	var inner_radius := 0.42
	var outer_radius := 1.2

	for i in SLASH_SEGMENTS + 1:
		var t := float(i) / float(SLASH_SEGMENTS)
		var angle := lerpf(start_angle, end_angle, t)
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		var alpha := sin(t * PI) * slash_color.a
		vertices.append(direction * inner_radius)
		vertices.append(direction * outer_radius)
		colors.append(Color(slash_color.r, slash_color.g, slash_color.b, alpha * 0.25))
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
