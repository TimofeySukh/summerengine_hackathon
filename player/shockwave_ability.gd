class_name ShockwaveAbility
extends Node

@export var cooldown := 3.5
@export var radius := 7.0
@export var push_force := 16.0

@onready var _sound: AudioStreamPlayer3D = $ShockwaveSound

var _cooldown_left := 0.0
var _player: Player
var _combat_feel: CombatFeel


func setup(player: Player, combat_feel: CombatFeel) -> void:
	_player = player
	_combat_feel = combat_feel


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)


func get_cooldown_left() -> float:
	return _cooldown_left


func can_trigger() -> bool:
	return _cooldown_left <= 0.0 and _player != null and not _player.is_dead()


func try_trigger() -> bool:
	if not can_trigger():
		return false

	_cooldown_left = cooldown
	_spawn_visual()
	_apply_damage()
	if _combat_feel != null:
		_combat_feel.play_shockwave_feedback()
	if _sound != null:
		_sound.pitch_scale = randf_range(0.82, 0.95)
		_sound.play()
	return true


func _spawn_visual() -> void:
	var visual := ShockwaveVisual.new()
	_player.get_parent().add_child(visual)
	visual.global_position = Vector3(
		_player.global_position.x,
		_player.global_position.y + 0.06,
		_player.global_position.z,
	)


func _apply_damage() -> void:
	var origin := _player.global_position
	for node in _player.get_tree().get_nodes_in_group("damageables"):
		if node == _player or not node is Node3D:
			continue

		var body := node as Node3D
		if body.has_method("is_alive") and not body.is_alive():
			continue

		var offset := body.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > radius or distance < 0.05:
			continue

		var direction := offset / distance
		var falloff := 1.0 - distance / radius * 0.45
		var impact_point := direction
		impact_point = (impact_point + Vector3.UP * 0.15).normalized() * 0.5
		var force := direction * push_force * falloff

		var was_alive := true
		if body.has_method("is_alive"):
			was_alive = body.is_alive()

		body.damage(impact_point, force)

		if was_alive and body.has_method("is_alive") and not body.is_alive():
			_player.register_kill()
