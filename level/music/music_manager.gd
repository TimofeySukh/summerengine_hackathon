extends Node

var music_player: AudioStreamPlayer

const MENU_MUSIC_PATH = "res://level/music/dansez_menu.mp3"
const GAME_MUSIC_PATH = "res://level/music/battleblock_theater_menu.ogg"

var _current_track_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	_update_music()

func _process(_delta: float) -> void:
	_update_music()

func _update_music() -> void:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	var target_track: String = ""
	if current_scene.scene_file_path == "res://ui/main_menu.tscn":
		target_track = MENU_MUSIC_PATH
	else:
		# Any other scene (gameplay scenes like desert_arena)
		target_track = GAME_MUSIC_PATH
		
	if _current_track_path != target_track:
		_play_track(target_track)

func _play_track(path: String) -> void:
	_current_track_path = path
	music_player.stop()
	
	var stream = load(path)
	if stream:
		stream.loop = true
		music_player.stream = stream
		# Adjust volume to be comfortable
		if path == MENU_MUSIC_PATH:
			music_player.volume_db = -10.0 # Dansez MP3 volume adjustment
		else:
			music_player.volume_db = -12.0 # BattleBlock Theater OGG volume adjustment
		music_player.play()
