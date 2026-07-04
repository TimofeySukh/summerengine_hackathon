extends Control

@onready var _feed: MjpegStreamView = %Feed
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_mode()


func _process(_delta: float) -> void:
	if ControlMode.is_webcam() != visible:
		_apply_mode()

	if not visible:
		return

	if CameraInputBridge.has_preview():
		_feed.texture = CameraInputBridge.get_preview_texture()
		_status.text = "LIVE"
		_status.modulate = Color(0.55, 1.0, 0.65, 1.0)
	elif _feed.get_frames_decoded() > 0:
		_status.text = "LIVE"
		_status.modulate = Color(0.55, 1.0, 0.65, 1.0)
	elif CameraInputBridge.is_stream_active():
		_status.text = "TRACKING"
		_status.modulate = Color(0.7, 0.85, 1.0, 1.0)
	else:
		_status.text = "CONNECTING"
		_status.modulate = Color(1.0, 0.85, 0.45, 1.0)


func _apply_mode() -> void:
	var want := ControlMode.is_webcam()
	visible = want
	if want:
		_feed.start_stream(WebcamConfig.STREAM_URL)
	else:
		_feed.stop_stream()
