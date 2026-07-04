extends Node

## UDP listener for tools/camera-controller pose_stream.py (port 9847).

const PORT := 9847
const STALE_MS := 2000

var _peer: PacketPeerUDP
var _slash_queue: Array[String] = []
var _shockwave_pending := false
var _left_hand_screen := Vector2.ZERO
var _right_hand_screen := Vector2.ZERO
var _has_hands := false
var _preview_texture := ImageTexture.new()
var _has_preview := false
var _last_packet_ms := 0


func _ready() -> void:
	_peer = PacketPeerUDP.new()
	var err := _peer.bind(PORT)
	if err != OK:
		push_warning("CameraInputBridge: could not bind UDP port %d (%s)" % [PORT, error_string(err)])


func _process(_delta: float) -> void:
	if _peer == null:
		return
	while _peer.get_available_packet_count() > 0:
		var packet := _peer.get_packet()
		_parse_packet(packet.get_string_from_utf8())


func poll_slash() -> String:
	if _slash_queue.is_empty():
		return ""
	return _slash_queue.pop_front()


func poll_shockwave() -> bool:
	var pending := _shockwave_pending
	_shockwave_pending = false
	return pending


func get_left_hand_screen() -> Vector2:
	return _left_hand_screen


func get_right_hand_screen() -> Vector2:
	return _right_hand_screen


func has_hands() -> bool:
	return _has_hands


func has_preview() -> bool:
	return _has_preview and is_stream_active()


func get_preview_texture() -> ImageTexture:
	return _preview_texture


func is_stream_active() -> bool:
	return Time.get_ticks_msec() - _last_packet_ms < STALE_MS


func reset_session() -> void:
	_slash_queue.clear()
	_shockwave_pending = false
	_has_hands = false
	_has_preview = false
	_left_hand_screen = Vector2.ZERO
	_right_hand_screen = Vector2.ZERO
	_last_packet_ms = 0


func _parse_packet(raw: String) -> void:
	var data: Variant = JSON.parse_string(raw.strip_edges())
	if typeof(data) != TYPE_DICTIONARY:
		return

	_last_packet_ms = Time.get_ticks_msec()
	var msg_type: String = str(data.get("type", ""))

	match msg_type:
		"slash":
			var hand := str(data.get("hand", ""))
			if hand == "left" or hand == "right":
				_slash_queue.append(hand)
		"shockwave":
			_shockwave_pending = true
		"hands":
			_left_hand_screen = Vector2(float(data.get("lx", 0.0)), float(data.get("ly", 0.0)))
			_right_hand_screen = Vector2(float(data.get("rx", 0.0)), float(data.get("ry", 0.0)))
			_has_hands = true
		"preview":
			var encoded: String = str(data.get("jpg", ""))
			if encoded.is_empty():
				return
			var bytes := Marshalls.base64_to_raw(encoded)
			var image := Image.new()
			if image.load_jpg_from_buffer(bytes) == OK:
				_preview_texture.set_image(image)
				_has_preview = true
		"ping":
			pass
