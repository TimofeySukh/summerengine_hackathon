"""Send pose/slash events to Heat Wave over UDP (CameraInputBridge autoload)."""

from __future__ import annotations

import base64
import json
import socket
from typing import Literal

from hand_tracker import HandFrame

Hand = Literal["left", "right"]
# macOS UDP datagrams fail above ~9 KiB in practice; base64 adds ~33% overhead.
MAX_UDP_PAYLOAD = 8192
MAX_PREVIEW_JPEG = 5000


class GameBridge:
    def __init__(self, host: str = "127.0.0.1", port: int = 9847):
        self._addr = (host, port)
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.packets_sent = 0

    def close(self) -> None:
        self._sock.close()

    def _send(self, payload: dict) -> bool:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        if len(data) > MAX_UDP_PAYLOAD:
            return False
        try:
            self._sock.sendto(data, self._addr)
            self.packets_sent += 1
            return True
        except OSError:
            return False

    def ping(self) -> None:
        self._send({"v": 1, "type": "ping"})

    def send_slash(self, hand: Hand) -> None:
        self._send({"v": 1, "type": "slash", "hand": hand})

    def send_shockwave(self, level: float = 1.0) -> None:
        self._send({"v": 1, "type": "shockwave", "level": round(level, 3)})

    def send_voice_wave(self, confidence: float) -> None:
        self._send({"v": 1, "type": "voice_wave", "confidence": round(confidence, 3)})

    def send_hands(self, frame: HandFrame) -> None:
        self._send(
            {
                "v": 1,
                "type": "hands",
                "mode": "screen",
                "lx": round(frame.lx, 4),
                "ly": round(frame.ly, 4),
                "rx": round(frame.rx, 4),
                "ry": round(frame.ry, 4),
            }
        )

    def send_preview(self, jpeg: bytes) -> bool:
        if not jpeg or len(jpeg) > MAX_PREVIEW_JPEG:
            return False
        return self._send(
            {
                "v": 1,
                "type": "preview",
                "jpg": base64.b64encode(jpeg).decode("ascii"),
            }
        )
