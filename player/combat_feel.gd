class_name CombatFeel
extends Node

@export var kill_shake := 0.58
@export var slash_shake := 0.24

@onready var _slash_sound: AudioStreamPlayer = $SlashSound
@onready var _kill_sound: AudioStreamPlayer = $KillSound

var _camera_shake: Node


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


func reset_feedback() -> void:
	Engine.time_scale = 1.0
	if _camera_shake != null and _camera_shake.has_method("reset_trauma"):
		_camera_shake.reset_trauma()
