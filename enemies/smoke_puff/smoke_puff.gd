extends Node3D

# Emit when smoke density is at maximum
signal full

const POOF_ANIMATION_SPEED := 4.0

@onready var smoke_sounds := $SmokeSounds.get_children()
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready():
	smoke_sounds.pick_random().play()

	animation_player.play("poof", -1.0, POOF_ANIMATION_SPEED)
	await animation_player.animation_finished
	queue_free()


func smoke_at_full_density():
	full.emit()
