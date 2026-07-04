extends Control

@onready var _feed: MjpegStreamView = %Feed
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_mode()


func _process(_delta: float) -> void:
	if ControlMode.is_webcam() != visible:
		_apply_mode()

	if visible and _feed.is_feed_connected():
		_status.text = "LIVE"
		_status.modulate = Color(0.55, 1.0, 0.65, 1.0)
	elif visible:
		_status.text = "CONNECTING"
		_status.modulate = Color(1.0, 0.85, 0.45, 1.0)


func _apply_mode() -> void:
	var want := ControlMode.is_webcam()
	visible = want
	if want:
		_feed.start_stream(WebcamConfig.STREAM_URL)
	else:
		_feed.stop_stream()
