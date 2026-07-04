extends SceneTree

const PLAYER_SCENE := preload("res://player/player.tscn")
const ENEMY_SCENE := preload("res://enemies/humanoid_chaser.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)

	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.5, 40.0)
	floor_shape.shape = box
	floor.add_child(floor_shape)
	test_root.add_child(floor)
	floor.position = Vector3(0.0, -0.25, 0.0)

	var player := PLAYER_SCENE.instantiate() as Player
	test_root.add_child(player)
	player.global_position = Vector3(0.0, 1.0, 0.0)

	var enemy := ENEMY_SCENE.instantiate() as Node3D
	test_root.add_child(enemy)
	enemy.global_position = Vector3(2.2, 1.0, 2.8)
	enemy.set_physics_process(false)

	for _i in 5:
		await process_frame

	player._camera_controller._euler_rotation = Vector3(0.0, PI, 0.0)
	player._camera_controller.transform.basis = Basis.from_euler(player._camera_controller._euler_rotation)
	for _i in 2:
		await process_frame

	var failures: Array[String] = []
	var forward := player._get_flat_forward()
	var origin := player.global_position + Vector3.UP * 0.95
	var target := player._find_best_melee_target(origin, forward)

	if target != enemy:
		failures.append("melee target should pick nearby enemy in slash arc")

	player._lunge_target = enemy
	player._hit_with_katana()
	await process_frame

	if enemy.has_method("is_alive") and enemy.is_alive():
		failures.append("katana hit should kill enemy in melee range")

	if failures.is_empty():
		print("Katana hit verification passed")
		quit(0)
	else:
		for msg in failures:
			push_error(msg)
		quit(1)
