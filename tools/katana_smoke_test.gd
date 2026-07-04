extends SceneTree

const VP := Vector2(1920, 1080)

func _init() -> void:
	var world: Node = load("res://main.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	player.get_node("CameraController").call_deferred("setup", player)
	for _i in 12:
		await process_frame

	var cam: Camera3D = player.get_node("CameraController/PlayerCamera")
	var ok := true
	for label in ["KatanaVisualLeft", "KatanaVisualRight"]:
		var node: Node3D = player.get_node("CameraController/PlayerCamera/" + label)
		var mesh: MeshInstance3D = node.get_node("SlashPivot/Katana/Katana_Mesh")
		var aabb := mesh.global_transform * mesh.get_aabb()
		var center := aabb.get_center()
		var screen: Vector2 = cam.unproject_position(center)
		var on_screen := screen.x >= 0.0 and screen.x <= VP.x and screen.y >= 0.0 and screen.y <= VP.y
		var vertical := aabb.size.y / maxf(aabb.size.x, 0.001) > 1.1
		print(label, " screen=", screen, " on_screen=", on_screen, " vertical=", vertical)
		ok = ok and on_screen and vertical

	print("RESULT:", "PASS" if ok else "FAIL")
	quit(0 if ok else 2)
