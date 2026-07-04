extends Node

var music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	var stream = load("res://level/music/battleblock_theater_menu.ogg")
	if stream:
		# Enable loop mode for the audio stream in Godot 4
		stream.loop = true
		music_player.stream = stream
		music_player.volume_db = -12.0 # Moderate volume to not overwhelm sound effects
		music_player.play()
