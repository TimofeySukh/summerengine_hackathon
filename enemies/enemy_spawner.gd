extends Node3D

const ENEMY_SCENE := preload("res://enemies/humanoid_chaser.tscn")

@export var spawn_interval := 1.0
@export var max_alive := 14
@export var spawn_radius := 24.0
@export var spawn_y := 0.2
@export var spawn_fov := 75.0
@export var min_spawn_distance := 10.0

var _spawn_timer := 0.0
var _spawn_index := 0


func _ready() -> void:
	for i in 5:
		_spawn_enemy()


func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer < spawn_interval:
		return

	_spawn_timer = 0.0
	if get_child_count() < max_alive:
		_spawn_enemy()


func _spawn_enemy() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var origin := Vector3.ZERO
	if player != null:
		origin = player.global_position

	var camera := get_viewport().get_camera_3d()
	var forward_xz := Vector3.FORWARD
	if camera != null:
		var forward := -camera.global_transform.basis.z
		var horizontal := Vector3(forward.x, 0.0, forward.z).normalized()
		if horizontal.length_squared() > 0.001:
			forward_xz = horizontal
		elif player != null:
			var player_forward := -player.global_transform.basis.z
			var player_horizontal := Vector3(player_forward.x, 0.0, player_forward.z).normalized()
			if player_horizontal.length_squared() > 0.001:
				forward_xz = player_horizontal
	elif player != null:
		var player_forward := -player.global_transform.basis.z
		var player_horizontal := Vector3(player_forward.x, 0.0, player_forward.z).normalized()
		if player_horizontal.length_squared() > 0.001:
			forward_xz = player_horizontal

	var base_angle := atan2(forward_xz.z, forward_xz.x)
	var half_fov_rad := deg_to_rad(spawn_fov / 2.0)
	var angle_offset := randf_range(-half_fov_rad, half_fov_rad)
	var spawn_angle := base_angle + angle_offset

	var distance := randf_range(minf(min_spawn_distance, spawn_radius), spawn_radius)
	var spawn_position := origin + Vector3(cos(spawn_angle), 0.0, sin(spawn_angle)) * distance
	spawn_position.x = clampf(spawn_position.x, -32.0, 32.0)
	spawn_position.z = clampf(spawn_position.z, -32.0, 32.0)
	spawn_position.y = spawn_y

	var enemy := ENEMY_SCENE.instantiate() as Node3D
	add_child(enemy)
	enemy.global_position = spawn_position



