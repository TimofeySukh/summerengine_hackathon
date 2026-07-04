extends Node

enum ArenaMode { SURVIVAL, SANDBOX }

var arena_mode := ArenaMode.SURVIVAL


func set_survival_mode() -> void:
	arena_mode = ArenaMode.SURVIVAL


func set_sandbox_mode() -> void:
	arena_mode = ArenaMode.SANDBOX


func is_sandbox_mode() -> bool:
	return arena_mode == ArenaMode.SANDBOX


func enemies_enabled() -> bool:
	return arena_mode == ArenaMode.SURVIVAL
