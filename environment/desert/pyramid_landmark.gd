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
