extends Node3D

const DesertProp := preload("res://environment/desert/desert_prop.gd")

@export var prop_count := 52
@export var center := Vector3(0.0, 0.0, 12.0)
@export var half_extent_x := 34.0
@export var half_extent_z := 34.0
@export var clear_radius := 14.0
@export var seed := 20260704


func _ready() -> void:
	_scatter_props()


func _scatter_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var kinds := [
		DesertProp.Kind.ROCK,
		DesertProp.Kind.PILLAR,
		DesertProp.Kind.DUNE,
		DesertProp.Kind.BOULDER,
	]

	for i in prop_count:
		var offset := Vector2(
			rng.randf_range(-half_extent_x, half_extent_x),
			rng.randf_range(-half_extent_z, half_extent_z),
		)
		if offset.length() < clear_radius:
			offset = offset.normalized() * clear_radius

		var prop := DesertProp.new()
		add_child(prop)
		prop.global_position = center + Vector3(offset.x, 0.0, offset.y)
		prop.setup(kinds[rng.randi() % kinds.size()], seed + i * 97)
		prop.rotation.y = rng.randf_range(0.0, TAU)
