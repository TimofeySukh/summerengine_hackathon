extends Control

const GAME_SCENE := "res://levels/desert_arena.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _quit_button: Button = %QuitButton
@onready var _control_mode: OptionButton = %ControlModeOption
@onready var _control_hint: Label = %ControlHint


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	WebcamLauncher.stop()
	_play_button.pressed.connect(_on_play_pressed)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_control_mode.item_selected.connect(_on_control_mode_selected)
	_setup_control_mode_options()
	_play_button.grab_focus()


func _setup_control_mode_options() -> void:
	_control_mode.clear()
	_control_mode.add_item("Keyboard — arrows / LMB slash", ControlMode.Mode.KEYBOARD)
	_control_mode.add_item("Webcam — hands drive katanas", ControlMode.Mode.WEBCAM)
	_control_mode.select(ControlMode.mode)
	_update_control_hint()


func _on_control_mode_selected(index: int) -> void:
	ControlMode.set_mode(_control_mode.get_item_id(index) as ControlMode.Mode)
	_update_control_hint()


func _update_control_hint() -> void:
	if ControlMode.is_webcam():
		_control_hint.text = """Webcam mode: camera opens in a separate Katana Pose window.
Move your hands — katanas follow your wrists. Slash to attack.
WASD to move."""
	else:
		_control_hint.text = "WASD move · mouse look · <-/-> katana slashes"


func _on_play_pressed() -> void:
	GameSettings.set_survival_mode()
	CameraInputBridge.reset_session()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_sandbox_pressed() -> void:
	GameSettings.set_sandbox_mode()
	CameraInputBridge.reset_session()
	if ControlMode.is_webcam():
		WebcamLauncher.start()
	else:
		WebcamLauncher.stop()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	WebcamLauncher.stop()
	get_tree().quit()
