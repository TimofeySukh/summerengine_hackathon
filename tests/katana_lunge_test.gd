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
	enemy.global_position = Vector3(0.0, 1.0, 6.0)
	enemy.set_physics_process(false)

	for _i in 5:
		await process_frame

	var failures: Array[String] = []
	var toward := player._lunge_toward_node(enemy, player.global_position)
	var flat_dist := Vector2(
		enemy.global_position.x - player.global_position.x,
		enemy.global_position.z - player.global_position.z
	).length()
	var expected_travel := flat_dist - player.attack_lunge_stop_margin - player._get_body_collision_radius(enemy)

	if absf(toward.distance - expected_travel) > 0.15:
		failures.append(
			"lunge travel should be ~%.2f, got %.2f (dist=%.2f)"
			% [expected_travel, toward.distance, flat_dist]
		)

	player._camera_controller.setup(player)
	player._camera_controller._euler_rotation = Vector3(0.0, PI, 0.0)
	player._camera_controller.transform.basis = Basis.from_euler(player._camera_controller._euler_rotation)
	player._last_strong_direction = Vector3(0.0, 0.0, 1.0)
	for _i in 2:
		await process_frame

	var start_pos := player.global_position
	player._begin_attack_lunge()
	player._katana_right.play_slash()
	for _i in 30:
		player._apply_attack_lunge(KatanaVisual.SLASH_DURATION / 30.0)
		player.velocity.y = 0.0
		player.move_and_slide()
		await process_frame

	var moved_z := player.global_position.z - start_pos.z
	if moved_z < expected_travel - 0.5:
		failures.append("dash moved %.2f on Z, expected ~%.2f" % [moved_z, expected_travel])

	var gap := Vector2(
		enemy.global_position.x - player.global_position.x,
		enemy.global_position.z - player.global_position.z
	).length()
	if gap > player.attack_lunge_stop_margin + player._get_body_collision_radius(enemy) + 0.45:
		failures.append("ended %.2f from enemy, want <= %.2f" % [gap, player.attack_lunge_stop_margin + player._get_body_collision_radius(enemy) + 0.45])

	if failures.is_empty():
		print("Katana full lunge verification passed")
		quit(0)
	else:
		for msg in failures:
			push_error(msg)
		quit(1)
