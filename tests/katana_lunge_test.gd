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
	player.position = Vector3(0.0, 1.0, 0.0)

	var enemy := ENEMY_SCENE.instantiate() as Node3D
	test_root.add_child(enemy)
	enemy.position = Vector3(0.0, 1.0, 2.5)

	for _i in 3:
		await process_frame

	var failures: Array[String] = []

	# 1) Direction math toward enemy
	var toward := player._lunge_toward_node(enemy, player.global_position)
	if toward.direction.dot(Vector3(0.0, 0.0, 1.0)) < 0.9:
		failures.append("lunge direction should point at enemy on +Z")
	if toward.distance < 1.0:
		failures.append("lunge distance toward enemy should be > 1.0, got %.2f" % toward.distance)

	# 2) test_move fix — player actually travels when lunge is active
	var start_pos := player.global_position
	player._lunge_direction = Vector3(0.0, 0.0, 1.0)
	player._lunge_remaining = 1.0
	player._lunge_speed = 12.0
	for _i in 8:
		player._apply_attack_lunge(1.0 / 60.0)
	var delta := player.global_position - start_pos
	if delta.z < 0.35:
		failures.append("apply_attack_lunge moved %.3f on Z, expected >= 0.35" % delta.z)
	if player._lunge_remaining > 0.05:
		failures.append("lunge should consume remaining distance, left %.3f" % player._lunge_remaining)

	# 3) Full attack flow with explicit enemy targeting via nearest search
	player.global_position = Vector3(0.0, 1.0, 0.0)
	player._lunge_remaining = 0.0
	player._camera_controller._euler_rotation = Vector3(0.0, PI, 0.0)
	player._camera_controller.transform.basis = Basis.from_euler(player._camera_controller._euler_rotation)
	for _i in 2:
		await process_frame

	start_pos = player.global_position
	player._begin_attack_lunge()
	if player._lunge_remaining < 0.05:
		failures.append("begin_attack_lunge should pick enemy in front")
	else:
		for _i in 12:
			player._apply_attack_lunge(1.0 / 60.0)
		delta = player.global_position - start_pos
		if delta.z < 0.35:
			failures.append("begin_attack_lunge flow moved %.3f on Z toward enemy" % delta.z)

	if failures.is_empty():
		print("Katana lunge verification passed (3 checks)")
		quit(0)
	else:
		for msg in failures:
			push_error(msg)
		quit(1)
