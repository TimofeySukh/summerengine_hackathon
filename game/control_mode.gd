extends Node

enum Mode { KEYBOARD, WEBCAM }

var mode: Mode = Mode.KEYBOARD


func is_keyboard() -> bool:
	return mode == Mode.KEYBOARD


func is_webcam() -> bool:
	return mode == Mode.WEBCAM


func set_mode(new_mode: Mode) -> void:
	mode = new_mode


func get_label() -> String:
	return "Keyboard" if mode == Mode.KEYBOARD else "Webcam"
