#!/usr/bin/env python3
import argparse
import json
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


DEFAULT_SOCKET_PATH = "/var/run/arduino-router.sock"


class MsgpackNeedMore(Exception):
    pass


def pack_msgpack(value) -> bytes:
    if value is None:
        return b"\xc0"
    if isinstance(value, bool):
        return b"\xc3" if value else b"\xc2"
    if isinstance(value, int):
        if 0 <= value <= 0x7F:
            return bytes([value])
        if -32 <= value < 0:
            return bytes([0x100 + value])
        if 0 <= value <= 0xFF:
            return b"\xcc" + value.to_bytes(1, "big")
        if 0 <= value <= 0xFFFF:
            return b"\xcd" + value.to_bytes(2, "big")
        return b"\xce" + value.to_bytes(4, "big")
    if isinstance(value, str):
        raw = value.encode("utf-8")
        if len(raw) < 32:
            return bytes([0xA0 | len(raw)]) + raw
        if len(raw) <= 0xFF:
            return b"\xd9" + len(raw).to_bytes(1, "big") + raw
        return b"\xda" + len(raw).to_bytes(2, "big") + raw
    if isinstance(value, (list, tuple)):
        if len(value) < 16:
            prefix = bytes([0x90 | len(value)])
        else:
            prefix = b"\xdc" + len(value).to_bytes(2, "big")
        return prefix + b"".join(pack_msgpack(item) for item in value)
    raise TypeError(f"cannot msgpack encode {type(value)!r}")


class MsgpackStream:
    def __init__(self) -> None:
        self.buffer = bytearray()

    def feed(self, data: bytes):
        self.buffer.extend(data)
        messages = []
        while self.buffer:
            try:
                value, offset = self._read(0)
            except MsgpackNeedMore:
                break
            messages.append(value)
            del self.buffer[:offset]
        return messages

    def _need(self, offset: int, size: int) -> None:
        if len(self.buffer) < offset + size:
            raise MsgpackNeedMore()

    def _read(self, offset: int):
        self._need(offset, 1)
        marker = self.buffer[offset]
        offset += 1

        if marker <= 0x7F:
            return marker, offset
        if marker >= 0xE0:
            return marker - 0x100, offset
        if 0x90 <= marker <= 0x9F:
            return self._read_array(offset, marker & 0x0F)
        if 0xA0 <= marker <= 0xBF:
            return self._read_str(offset, marker & 0x1F)

        if marker == 0xC0:
            return None, offset
        if marker == 0xC2:
            return False, offset
        if marker == 0xC3:
            return True, offset
        if marker == 0xCC:
            return self._read_uint(offset, 1)
        if marker == 0xCD:
            return self._read_uint(offset, 2)
        if marker == 0xCE:
            return self._read_uint(offset, 4)
        if marker == 0xD0:
            return self._read_int(offset, 1)
        if marker == 0xD1:
            return self._read_int(offset, 2)
        if marker == 0xD2:
            return self._read_int(offset, 4)
        if marker == 0xD9:
            length, offset = self._read_uint(offset, 1)
            return self._read_str(offset, length)
        if marker == 0xDA:
            length, offset = self._read_uint(offset, 2)
            return self._read_str(offset, length)
        if marker == 0xDC:
            length, offset = self._read_uint(offset, 2)
            return self._read_array(offset, length)

        raise ValueError(f"unsupported msgpack marker 0x{marker:02x}")

    def _read_uint(self, offset: int, size: int):
        self._need(offset, size)
        return int.from_bytes(self.buffer[offset : offset + size], "big"), offset + size

    def _read_int(self, offset: int, size: int):
        self._need(offset, size)
        return int.from_bytes(self.buffer[offset : offset + size], "big", signed=True), offset + size

    def _read_str(self, offset: int, length: int):
        self._need(offset, length)
        raw = bytes(self.buffer[offset : offset + length])
        return raw.decode("utf-8", errors="replace"), offset + length

    def _read_array(self, offset: int, length: int):
        items = []
        for _ in range(length):
            item, offset = self._read(offset)
            items.append(item)
        return items, offset


class ModulinoState:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._state = {
            "ok": False,
            "connected": False,
            "updated_at": None,
            "age_seconds": None,
            "error": "waiting for modulino_state",
            "buttons": {"ok": False, "source": "missing", "a": False, "b": False, "c": False},
            "gyro": {
                "ok": False,
                "fresh": False,
                "source": "missing",
                "accel": {"x": 0, "y": 0, "z": 0},
                "gyro": {"x": 0, "y": 0, "z": 0},
            },
        }

    def set_error(self, message: str) -> None:
        with self._lock:
            self._state["ok"] = False
            self._state["connected"] = False
            self._state["error"] = message

    def update(self, payload: dict) -> None:
        now = time.time()
        with self._lock:
            self._state.update(payload)
            self._state["ok"] = True
            self._state["connected"] = True
            self._state["updated_at"] = now
            self._state["age_seconds"] = 0
            self._state["error"] = None

    def snapshot(self) -> dict:
        with self._lock:
            data = json.loads(json.dumps(self._state))
        updated_at = data.get("updated_at")
        if updated_at:
            data["age_seconds"] = round(time.time() - updated_at, 3)
            if data["age_seconds"] > 2:
                data["ok"] = False
                data["error"] = "stale modulino_state"
        return data


class BridgeReader(threading.Thread):
    def __init__(self, socket_path: str, state: ModulinoState) -> None:
        super().__init__(daemon=True)
        self.socket_path = socket_path
        self.state = state
        self.stop_event = threading.Event()

    def run(self) -> None:
        while not self.stop_event.is_set():
            try:
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                    client.connect(self.socket_path)
                    client.sendall(pack_msgpack([0, 1, "$/register", ["modulino_state"]]))
                    stream = MsgpackStream()
                    while not self.stop_event.is_set():
                        chunk = client.recv(4096)
                        if not chunk:
                            raise ConnectionError("router bridge closed")
                        for msg in stream.feed(chunk):
                            self._handle_message(msg)
            except Exception as exc:
                self.state.set_error(str(exc))
                time.sleep(1)

    def _handle_message(self, msg) -> None:
        try:
            if not isinstance(msg, list) or len(msg) < 3:
                return
            if msg[0] != 2 or msg[1] != "modulino_state":
                return
            args = msg[2]
            if not args:
                return
            payload = args[0]
            if not isinstance(payload, str):
                raise ValueError("modulino_state payload is not a string")
            self.state.update(json.loads(payload))
        except Exception as exc:
            self.state.set_error(f"bad modulino_state: {exc}")


def make_handler(state: ModulinoState):
    class Handler(BaseHTTPRequestHandler):
        server_version = "ModulinoAPI/1.0"

        def do_GET(self) -> None:
            if self.path == "/state":
                self._serve_state()
            elif self.path == "/health":
                self._serve_health()
            elif self.path == "/favicon.ico":
                self.send_response(204)
                self.end_headers()
            else:
                self.send_error(404)

        def log_message(self, fmt: str, *args) -> None:
            print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), fmt % args), flush=True)

        def _send_json(self, payload: dict, status: int = 200) -> None:
            body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        def _serve_state(self) -> None:
            self._send_json(state.snapshot())

        def _serve_health(self) -> None:
            snapshot = state.snapshot()
            self._send_json({"ok": bool(snapshot.get("ok")), "error": snapshot.get("error")}, 200 if snapshot.get("ok") else 503)

    return Handler


def main() -> int:
    parser = argparse.ArgumentParser(description="Expose Arduino Modulino RouterBridge state as JSON.")
    parser.add_argument("--socket", default=DEFAULT_SOCKET_PATH)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8091)
    args = parser.parse_args()

    state = ModulinoState()
    reader = BridgeReader(args.socket, state)
    reader.start()

    server = ThreadingHTTPServer((args.host, args.port), make_handler(state))
    print(f"Serving Modulino API on http://{args.host}:{args.port}/state", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    finally:
        reader.stop_event.set()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
