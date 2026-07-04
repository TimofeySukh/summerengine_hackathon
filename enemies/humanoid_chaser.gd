extends CharacterBody3D

const SMOKE_PUFF_SCENE := preload("res://enemies/smoke_puff/smoke_puff.tscn")

@export var move_speed := 3.2
@export var stop_distance := 1.6
@export var gravity := 30.0
@export var contact_damage := 10.0
@export var damage_cooldown := 0.8

@onready var _visual_root: Node3D = $VisualRoot

var _alive := true
var _damage_timer := 0.0


func is_alive() -> bool:
	return _alive


func _physics_process(delta: float) -> void:
	if not _alive:
		return

	_damage_timer = maxf(0.0, _damage_timer - delta)
	var target := get_tree().get_first_node_in_group("player") as Node3D
	if target != null:
		var to_target := target.global_position - global_position
		to_target.y = 0.0

		if to_target.length() > stop_distance:
			var direction := to_target.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			look_at(global_position + direction, Vector3.UP)
			_visual_root.rotation.z = sin(Time.get_ticks_msec() * 0.012) * 0.035
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			_try_damage_player(target)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()


func _try_damage_player(target: Node3D) -> void:
	if _damage_timer > 0.0:
		return

	if target.has_method("take_damage"):
		target.take_damage(contact_damage)
		_damage_timer = damage_cooldown


func damage(_impact_point: Vector3, _force: Vector3) -> void:
	if not _alive:
		return

	_alive = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_spawn_death_puff()
	_flash_death_materials(_visual_root)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual_root, "scale", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual_root, "rotation:x", randf_range(-0.45, 0.45), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual_root, "rotation:z", randf_range(-0.7, 0.7), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func _spawn_death_puff() -> void:
	var puff := SMOKE_PUFF_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(puff)
	puff.global_position = global_position + Vector3.UP * 0.85
	puff.scale = Vector3.ONE * 0.78


func _flash_death_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.12, 0.05, 1.0)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.08, 0.03, 1.0)
		material.emission_energy_multiplier = 2.8
		material.roughness = 0.4
		mesh.material_override = material

	for child in node.get_children():
		_flash_death_materials(child)
