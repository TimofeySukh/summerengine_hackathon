extends Node

## Keyboard stand-in for voice "move" / "stop" until speech recognition is wired.
## Emits the same signals a future mic keyword spotter would use.

signal jog_forward
signal jog_stop


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_jog_forward"):
		jog_forward.emit()
	elif event.is_action_pressed("camera_jog_stop"):
		jog_stop.emit()
