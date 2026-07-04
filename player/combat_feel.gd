class_name CombatFeel
extends Node

@export var hit_stop_duration := 0.04
@export var hit_stop_scale := 0.08
@export var kill_shake := 0.58
@export var slash_shake := 0.24

@onready var _slash_sound: AudioStreamPlayer = $SlashSound
@onready var _kill_sound: AudioStreamPlayer = $KillSound

var _camera_shake: Node
var _hit_stop_running := false
var _hit_stop_timer: SceneTreeTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(camera_shake: Node) -> void:
	_camera_shake = camera_shake


func play_slash_feedback() -> void:
	if _camera_shake != null:
		_camera_shake.add_trauma(slash_shake)
	_slash_sound.pitch_scale = randf_range(0.94, 1.06)
	_slash_sound.play()


func play_kill_feedback() -> void:
	if _camera_shake != null:
		_camera_shake.add_trauma(slash_shake)
		_camera_shake.add_trauma(kill_shake)
	_slash_sound.pitch_scale = randf_range(0.94, 1.06)
	_slash_sound.play()
	_kill_sound.pitch_scale = randf_range(0.9, 1.1)
	_kill_sound.play()
	_apply_hit_stop()


func reset_feedback() -> void:
	_end_hit_stop()


func _apply_hit_stop() -> void:
	if _hit_stop_timer != null and _hit_stop_timer.time_left > 0.0:
		return

	_hit_stop_running = true
	Engine.time_scale = hit_stop_scale
	_hit_stop_timer = get_tree().create_timer(hit_stop_duration, true, false, true)
	_hit_stop_timer.timeout.connect(_end_hit_stop, CONNECT_ONE_SHOT)


func _end_hit_stop() -> void:
	_hit_stop_running = false
	_hit_stop_timer = null
	Engine.time_scale = 1.0
