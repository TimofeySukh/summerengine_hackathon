class_name ShockwaveVisual
extends Node3D

const GROUND_SHADER := preload("res://player/shockwave_ground_shader.gdshader")

const DURATION := 0.8
const MAX_RADIUS_UNITS := 14.0

var _disc: MeshInstance3D
var _mat: ShaderMaterial


func _ready() -> void:
	_disc = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAX_RADIUS_UNITS * 2.0, MAX_RADIUS_UNITS * 2.0)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	_disc.mesh = plane

	_mat = ShaderMaterial.new()
	_mat.shader = GROUND_SHADER
	_mat.set_shader_parameter("wave_color", Color(0.35, 0.88, 1.0, 0.92))
	_mat.set_shader_parameter("intensity", 2.4)
	_mat.set_shader_parameter("ring_width", 0.13)
	_mat.set_shader_parameter("radius", 0.02)
	_disc.material_override = _mat
	add_child(_disc)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_radius, 0.02, 0.98, DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_fade_intensity, 2.4, 0.0, DURATION * 0.9)\
		.set_delay(DURATION * 0.1)
	tween.tween_method(_set_ring_width, 0.13, 0.06, DURATION)\
		.set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)


func _set_radius(value: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("radius", value)


func _set_ring_width(value: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("ring_width", value)


func _fade_intensity(value: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("intensity", value)
