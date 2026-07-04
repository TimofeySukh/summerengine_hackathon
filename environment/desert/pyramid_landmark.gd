extends Node3D

const GLB_PATH := "res://environment/desert/pyramids.glb"

@export var hide_ground_sphere := true
@export var landmark_scale := 0.46
@export var landmark_offset := Vector3(0.0, 0.0, -20.0)


func _ready() -> void:
	_load_landmark()


func _load_landmark() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(GLB_PATH, state)
	if err != OK:
		push_error("PyramidLandmark: failed to load %s (%s)" % [GLB_PATH, error_string(err)])
		return

	var root: Node = doc.generate_scene(state)
	if root == null:
		push_error("PyramidLandmark: generate_scene returned null")
		return

	root.name = "Pyramids"
	add_child(root)

	if hide_ground_sphere:
		var ground := root.get_node_or_null("Sphere001")
		if ground != null:
			ground.visible = false

	scale = Vector3.ONE * landmark_scale
	position = landmark_offset
	_add_pyramid_collision()


func _add_pyramid_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "PyramidCollision"
	add_child(body)

	_add_box_collision(body, Vector3(-2.4, 34.5, -19.1), Vector3(130.0, 69.0, 130.0))
	_add_box_collision(body, Vector3(78.5, 23.9, -38.4), Vector3(72.0, 48.0, 72.0))
	_add_box_collision(body, Vector3(-102.5, 23.9, 34.1), Vector3(72.0, 48.0, 72.0))


func _add_box_collision(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
