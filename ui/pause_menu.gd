extends Node

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"

@onready var _pause_root: Control = $CanvasLayer/PauseRoot
@onready var _continue_button: Button = %ContinueButton
@onready var _main_menu_button: Button = %MainMenuButton

var _stored_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _is_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_root.hide()

	_continue_button.pressed.connect(_on_continue_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("pause"):
		return
	if _is_paused:
		unpause()
	else:
		pause()


func pause() -> void:
	if _is_paused:
		return
	_is_paused = true
	_stored_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	_pause_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue_button.grab_focus()


func unpause() -> void:
	if not _is_paused:
		return
	_is_paused = false
	get_tree().paused = false
	_pause_root.hide()
	Input.mouse_mode = _stored_mouse_mode


func _on_continue_pressed() -> void:
	unpause()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
