extends Node

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"

@onready var _death_root: Control = $CanvasLayer/DeathRoot
@onready var _restart_button: Button = %RestartButton
@onready var _main_menu_button: Button = %MainMenuButton

var _stored_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _is_showing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_death_root.hide()

	_restart_button.pressed.connect(_on_restart_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)

	call_deferred("_bind_player")


func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	if _is_showing:
		return

	_is_showing = true
	_stored_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	_death_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("respawn"):
		player.respawn()

	_is_showing = false
	get_tree().paused = false
	_death_root.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func is_showing() -> bool:
	return _is_showing
