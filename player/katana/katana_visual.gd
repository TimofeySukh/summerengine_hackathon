extends Node3D

func _ready() -> void:
	_boost_materials(self)


func _boost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			return

		for surface_idx in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_idx)
			if material is StandardMaterial3D:
				var tuned := material.duplicate() as StandardMaterial3D
				tuned.albedo_color = tuned.albedo_color.lerp(Color(0.08, 0.08, 0.12), 0.4)
				tuned.metallic = clampf(tuned.metallic + 0.25, 0.0, 1.0)
				tuned.roughness = clampf(tuned.roughness - 0.15, 0.08, 1.0)
				mesh_instance.set_surface_override_material(surface_idx, tuned)

	for child in node.get_children():
		_boost_materials(child)
