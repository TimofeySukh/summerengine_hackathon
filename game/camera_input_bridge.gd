extends Node

## UDP listener for tools/camera-controller pose_stream.py (port 9847).

const PORT := 9847
const STALE_MS := 2000

var _peer: PacketPeerUDP
var _slash_queue: Array[String] = []
var _latest_torso_yaw := 0.0
var _has_torso_yaw := false
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


func get_torso_yaw() -> float:
	return _latest_torso_yaw


func has_torso_yaw() -> bool:
	return _has_torso_yaw


func is_stream_active() -> bool:
	return Time.get_ticks_msec() - _last_packet_ms < STALE_MS


func reset_session() -> void:
	_slash_queue.clear()
	_has_torso_yaw = false
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
		"yaw":
			if data.has("deg"):
				_latest_torso_yaw = float(data["deg"])
				_has_torso_yaw = true
		"ping":
			pass
