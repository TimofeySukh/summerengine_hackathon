extends Control

const GAME_SCENE := "res://levels/desert_arena.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _play_webcam_button: Button = %PlayWebcamButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _sandbox_webcam_button: Button = %SandboxWebcamButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _back_button: Button = %BackButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value_label: Label = %VolumeValueLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_button.pressed.connect(_on_play_pressed)
	_play_webcam_button.pressed.connect(_on_play_webcam_pressed)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_sandbox_webcam_button.pressed.connect(_on_sandbox_webcam_pressed)
	_settings_button.pressed.connect(_show_settings)
	_back_button.pressed.connect(_hide_settings)
	_quit_button.pressed.connect(_on_quit_pressed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_hide_settings()
	_on_volume_changed(_volume_slider.value)
	_play_button.grab_focus()


func _show_settings() -> void:
	_settings_panel.visible = true


func _hide_settings() -> void:
	_settings_panel.visible = false
	_play_button.grab_focus()


func _on_volume_changed(value: float) -> void:
	var percent := int(round(value))
	_volume_value_label.text = "%d%%" % percent
	if MusicManager.music_player:
		MusicManager.music_player.volume_db = linear_to_db(clampf(value / 100.0, 0.0, 1.0))


func _on_play_pressed() -> void:
	_start_survival(false)


func _on_play_webcam_pressed() -> void:
	_start_survival(true)


func _on_sandbox_pressed() -> void:
	_start_sandbox(false)


func _on_sandbox_webcam_pressed() -> void:
	_start_sandbox(true)


func _start_survival(webcam: bool) -> void:
	GameSettings.set_survival_mode()
	_launch_game(webcam)


func _start_sandbox(webcam: bool) -> void:
	GameSettings.set_sandbox_mode()
	_launch_game(webcam)


func _launch_game(webcam: bool) -> void:
	ControlMode.set_mode(ControlMode.Mode.WEBCAM if webcam else ControlMode.Mode.KEYBOARD)
	CameraInputBridge.reset_session()
	if webcam:
		WebcamLauncher.start()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
