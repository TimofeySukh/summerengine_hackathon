extends Control

const GAME_SCENE := "res://main.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _control_mode: OptionButton = %ControlModeOption
@onready var _control_hint: Label = %ControlHint


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_control_mode.item_selected.connect(_on_control_mode_selected)
	_setup_control_mode_options()
	_play_button.grab_focus()


func _setup_control_mode_options() -> void:
	_control_mode.clear()
	_control_mode.add_item("Keyboard — arrows / LMB slash", ControlMode.Mode.KEYBOARD)
	_control_mode.add_item("Webcam — real hands via pose_stream", ControlMode.Mode.WEBCAM)
	_control_mode.select(ControlMode.mode)
	_update_control_hint()


func _on_control_mode_selected(index: int) -> void:
	ControlMode.set_mode(_control_mode.get_item_id(index) as ControlMode.Mode)
	_update_control_hint()


func _update_control_hint() -> void:
	if ControlMode.is_webcam():
		_control_hint.text = """Run before Play:
cd tools/camera-controller && python pose_stream.py --game-bridge
Left hand slash -> left katana. Right hand -> right katana. Torso turn -> look."""
	else:
		_control_hint.text = "WASD move · mouse look · <-/-> katana slashes"


func _on_play_pressed() -> void:
	CameraInputBridge.reset_session()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
