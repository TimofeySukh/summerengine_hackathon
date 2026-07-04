extends SceneTree

const VP := Vector2(1920, 1080)

func _screen_rect(cam: Camera3D, mesh: MeshInstance3D) -> Rect2:
	var gt := mesh.global_transform
	var aabb := mesh.get_aabb()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in 8:
		var s: Vector2 = cam.unproject_position(gt * aabb.get_endpoint(i))
		mn = Vector2(minf(mn.x, s.x), minf(mn.y, s.y))
		mx = Vector2(maxf(mx.x, s.x), maxf(mx.y, s.y))
	return Rect2(mn, mx - mn)

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
		var rect := _screen_rect(cam, mesh)
		var center := rect.get_center()
		var on_screen := rect.size.x > 0.0 and rect.size.y > 0.0
		on_screen = on_screen and rect.position.x >= -40.0 and rect.end.x <= VP.x + 40.0
		on_screen = on_screen and rect.position.y >= -40.0 and rect.end.y <= VP.y + 120.0
		var vertical := rect.size.y / maxf(rect.size.x, 1.0) > 2.0
		var sized := rect.size.y >= 350.0 and rect.size.y <= 950.0
		var placed := center.y >= 580.0 and center.y <= 860.0
		if label.ends_with("Left"):
			placed = placed and center.x >= 220.0 and center.x <= 480.0
		else:
			placed = placed and center.x >= 1440.0 and center.x <= 1720.0
		print(label, " center=", center, " size=", rect.size, " on_screen=", on_screen, " vertical=", vertical, " sized=", sized, " placed=", placed)
		ok = ok and on_screen and vertical and sized and placed

	print("RESULT:", "PASS" if ok else "FAIL")
	quit(0 if ok else 2)
