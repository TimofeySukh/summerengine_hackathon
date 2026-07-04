class_name MjpegStreamView
extends TextureRect

## In-game MJPEG viewer (multipart JPEG over HTTP).

enum Phase { IDLE, CONNECTING, REQUESTING, READING }

const RECONNECT_DELAY := 1.5
const MAX_BUFFER_BYTES := 2_000_000

var _http := HTTPClient.new()
var _buffer := PackedByteArray()
var _phase := Phase.IDLE
var _stream_url := ""
var _host := ""
var _port := 80
var _path := "/stream"
var _use_tls := false
var _image_texture := ImageTexture.new()
var _reconnect_at := 0.0
var _frames_decoded := 0
var _connected := false


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture = _image_texture
	set_process(true)


func start_stream(url: String) -> void:
	stop_stream()
	_stream_url = url
	_parse_url(url)
	_begin_connect()


func stop_stream() -> void:
	_http.close()
	_buffer.clear()
	_phase = Phase.IDLE
	_connected = false
	_reconnect_at = 0.0


func is_feed_connected() -> bool:
	return _connected


func get_frames_decoded() -> int:
	return _frames_decoded


func _process(delta: float) -> void:
	if _stream_url.is_empty():
		return

	if _phase == Phase.IDLE:
		if Time.get_ticks_msec() / 1000.0 >= _reconnect_at:
			_begin_connect()
		return

	_http.poll()
	var status := _http.get_status()

	match _phase:
		Phase.CONNECTING:
			if status == HTTPClient.STATUS_CONNECTED:
				var headers := PackedStringArray(["Accept: multipart/x-mixed-replace, */*"])
				var err := _http.request(HTTPClient.METHOD_GET, _path, headers)
				if err == OK:
					_phase = Phase.REQUESTING
				else:
					_schedule_reconnect()

		Phase.REQUESTING:
			if status == HTTPClient.STATUS_BODY or _http.has_response():
				if status == HTTPClient.STATUS_BODY:
					_phase = Phase.READING
					_connected = true

		Phase.READING:
			if status == HTTPClient.STATUS_BODY:
				while true:
					var chunk := _http.read_response_body_chunk()
					if chunk.is_empty():
						break
					_buffer.append_array(chunk)
					if _buffer.size() > MAX_BUFFER_BYTES:
						_buffer = _buffer.slice(_buffer.size() - 262144)
					_decode_available_frames()
			elif (
				status == HTTPClient.STATUS_DISCONNECTED
				or status == HTTPClient.STATUS_CANT_CONNECT
				or status == HTTPClient.STATUS_CANT_RESOLVE
			):
				_connected = false
				_schedule_reconnect()


func _begin_connect() -> void:
	_http.close()
	_buffer.clear()
	_phase = Phase.CONNECTING
	_connected = false
	var tls := TLSOptions.client() if _use_tls else null
	var err := _http.connect_to_host(_host, _port, tls)
	if err != OK:
		_schedule_reconnect()


func _schedule_reconnect() -> void:
	_http.close()
	_buffer.clear()
	_phase = Phase.IDLE
	_connected = false
	_reconnect_at = Time.get_ticks_msec() / 1000.0 + RECONNECT_DELAY


func _parse_url(url: String) -> void:
	_use_tls = url.begins_with("https://")
	var trimmed := url
	if trimmed.begins_with("http://"):
		trimmed = trimmed.substr(7)
	elif trimmed.begins_with("https://"):
		trimmed = trimmed.substr(8)

	var slash_idx := trimmed.find("/")
	if slash_idx == -1:
		_host = trimmed
		_path = "/"
	else:
		_host = trimmed.substr(0, slash_idx)
		_path = trimmed.substr(slash_idx)

	if _host.contains(":"):
		var parts := _host.split(":", false)
		_host = parts[0]
		_port = int(parts[1])
	else:
		_port = 443 if _use_tls else 80


func _decode_available_frames() -> void:
	while true:
		var start := _find_bytes(_buffer, 0, [0xFF, 0xD8])
		if start == -1:
			return
		if start > 0:
			_buffer = _buffer.slice(start)
			start = 0
		var end := _find_jpeg_end(_buffer, 2)
		if end == -1:
			return
		var frame := _buffer.slice(0, end + 2)
		_buffer = _buffer.slice(end + 2)
		var image := Image.new()
		if image.load_jpg_from_buffer(frame) == OK:
			_image_texture.set_image(image)
			_frames_decoded += 1


func _find_jpeg_end(data: PackedByteArray, from: int) -> int:
	var i := from
	while i + 1 < data.size():
		if data[i] == 0xFF and data[i + 1] == 0xD9:
			return i + 1
		i += 1
	return -1


func _find_bytes(data: PackedByteArray, from: int, seq: Array) -> int:
	var i := from
	while i + seq.size() <= data.size():
		var matched := true
		for j in seq.size():
			if data[i + j] != seq[j]:
				matched = false
				break
		if matched:
			return i
		i += 1
	return -1
