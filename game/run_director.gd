extends Node

enum Phase { INTERMISSION, COMBAT }

signal stats_updated(snapshot: Dictionary)
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal run_ended(snapshot: Dictionary)

const SAVE_PATH := "user://heatwave_best.run"

@export var intermission_duration := 3.0
@export var first_wave_delay := 1.75
@export var first_wave_enemies := 6
@export var enemies_per_wave_bonus := 2
@export var min_spawn_interval := 0.55
@export var base_spawn_interval := 1.05

var phase := Phase.INTERMISSION
var current_wave := 0
var total_kills := 0
var run_time := 0.0
var best_wave := 0
var best_kills := 0

var _spawner: Node = null
var _enemies_remaining := 0
var _intermission_timer := 0.0
var _spawn_timer := 0.0
var _spawn_interval := 1.0
var _intermission_message := ""


func _ready() -> void:
	add_to_group("run_director")
	_load_best()
	call_deferred("_bind_spawner")
	call_deferred("start_run")


func _bind_spawner() -> void:
	_spawner = get_parent().get_node_or_null("Enemies")
	if _spawner != null and _spawner.has_method("set_run_director"):
		_spawner.set_run_director(self)


func _process(delta: float) -> void:
	if _is_player_dead():
		return

	run_time += delta
	match phase:
		Phase.INTERMISSION:
			_process_intermission(delta)
		Phase.COMBAT:
			_process_combat(delta)
	_emit_stats_if_changed()


var _last_stats_signature := ""


func start_run() -> void:
	current_wave = 0
	total_kills = 0
	run_time = 0.0
	_enemies_remaining = 0
	_spawn_timer = 0.0
	if _spawner != null and _spawner.has_method("clear_all_enemies"):
		_spawner.clear_all_enemies()
	_begin_intermission(true)


func restart_run() -> void:
	Engine.time_scale = 1.0
	start_run()


func notify_enemy_defeated() -> void:
	total_kills += 1
	_emit_stats_if_changed(true)


func _restore_normal_time() -> void:
	Engine.time_scale = 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var combat_feel := player.get_node_or_null("CombatFeel")
	if combat_feel != null and combat_feel.has_method("reset_feedback"):
		combat_feel.reset_feedback()


func on_player_died() -> void:
	_update_best_if_better()
	run_ended.emit(get_snapshot())


func get_snapshot() -> Dictionary:
	return {
		"wave": current_wave,
		"kills": total_kills,
		"time": run_time,
		"best_wave": best_wave,
		"best_kills": best_kills,
		"phase": phase,
		"intermission_message": _intermission_message,
		"enemies_remaining": _enemies_remaining,
	}


func _begin_intermission(is_run_start: bool = false) -> void:
	phase = Phase.INTERMISSION
	_restore_normal_time()
	if is_run_start:
		_intermission_timer = first_wave_delay
		_intermission_message = "SURVIVE THE WAVES"
	else:
		_intermission_timer = intermission_duration
		_intermission_message = "WAVE %d CLEAR" % current_wave
	_emit_stats_if_changed(true)


func _start_wave() -> void:
	_restore_normal_time()
	current_wave += 1
	_enemies_remaining = first_wave_enemies + (current_wave - 1) * enemies_per_wave_bonus
	_spawn_interval = maxf(
		min_spawn_interval,
		base_spawn_interval - float(current_wave - 1) * 0.06
	)
	_spawn_timer = 0.35
	phase = Phase.COMBAT
	_intermission_message = ""
	wave_started.emit(current_wave)
	_emit_stats_if_changed(true)


func _process_intermission(delta: float) -> void:
	_intermission_timer -= delta
	if _intermission_timer <= 1.0 and current_wave > 0 and _intermission_message.begins_with("WAVE"):
		_intermission_message = "WAVE %d INCOMING" % (current_wave + 1)
		_emit_stats_if_changed(true)

	if _intermission_timer <= 0.0:
		_start_wave()


func _process_combat(delta: float) -> void:
	if _spawner == null:
		return

	if _enemies_remaining > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _spawn_interval
			_spawner.spawn_enemy()
			_enemies_remaining -= 1
			_emit_stats_if_changed(true)
		return

	if _spawner.get_alive_count() == 0:
		wave_cleared.emit(current_wave)
		_update_best_if_better()
		_begin_intermission()


func _update_best_if_better() -> void:
	if current_wave > best_wave or (current_wave == best_wave and total_kills > best_kills):
		best_wave = maxi(best_wave, current_wave)
		best_kills = maxi(best_kills, total_kills)
		_save_best()


func _emit_stats_if_changed(force := false) -> void:
	var snapshot := get_snapshot()
	var signature := "%s|%s|%s|%s|%s|%s" % [
		snapshot.get("wave", 0),
		snapshot.get("kills", 0),
		int(float(snapshot.get("time", 0.0))),
		snapshot.get("phase", 0),
		snapshot.get("intermission_message", ""),
		snapshot.get("enemies_remaining", 0),
	]
	if not force and signature == _last_stats_signature:
		return
	_last_stats_signature = signature
	stats_updated.emit(snapshot)


func _emit_stats(force_intermission_banner := false) -> void:
	_emit_stats_if_changed(force_intermission_banner)


func _is_player_dead() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.has_method("is_dead") and player.is_dead()


func _load_best() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		best_wave = int(data.get("best_wave", 0))
		best_kills = int(data.get("best_kills", 0))


func _save_best() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"best_wave": best_wave, "best_kills": best_kills}))
