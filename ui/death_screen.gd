extends Node

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"

@onready var _death_root: Control = $CanvasLayer/DeathRoot
@onready var _stats_label: Label = %StatsLabel
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
	_update_stats_label()
	_death_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_restart_button.grab_focus()

	var director := get_tree().get_first_node_in_group("run_director")
	if director != null and director.has_method("on_player_died"):
		director.on_player_died()


func _update_stats_label() -> void:
	var director := get_tree().get_first_node_in_group("run_director")
	if director == null or not director.has_method("get_snapshot"):
		_stats_label.text = ""
		return

	var snapshot: Dictionary = director.get_snapshot()
	var wave: int = snapshot.get("wave", 0)
	var kills: int = snapshot.get("kills", 0)
	var time_text := _format_time(float(snapshot.get("time", 0.0)))
	var best_wave: int = snapshot.get("best_wave", 0)
	var best_kills: int = snapshot.get("best_kills", 0)

	if best_wave > 0:
		_stats_label.text = "Wave %d  ·  %d kills  ·  %s\nBest run  W%d  ·  %d kills" % [
			wave, kills, time_text, best_wave, best_kills
		]
	else:
		_stats_label.text = "Wave %d  ·  %d kills  ·  %s" % [wave, kills, time_text]


func _on_restart_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("respawn"):
		player.respawn()

	var director := get_tree().get_first_node_in_group("run_director")
	if director != null and director.has_method("restart_run"):
		director.restart_run()

	_is_showing = false
	get_tree().paused = false
	_death_root.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_main_menu_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func is_showing() -> bool:
	return _is_showing


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var minutes := total / 60
	var secs := total % 60
	return "%d:%02d" % [minutes, secs]
