"""Send pose/slash events to Heat Wave over UDP (CameraInputBridge autoload)."""

from __future__ import annotations

import json
import socket
from typing import Literal

Hand = Literal["left", "right"]


class GameBridge:
    def __init__(self, host: str = "127.0.0.1", port: int = 9847):
        self._addr = (host, port)
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.packets_sent = 0

    def close(self) -> None:
        self._sock.close()

    def _send(self, payload: dict) -> None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self._sock.sendto(data, self._addr)
        self.packets_sent += 1

    def ping(self) -> None:
        self._send({"v": 1, "type": "ping"})

    def send_slash(self, hand: Hand) -> None:
        self._send({"v": 1, "type": "slash", "hand": hand})

    def send_yaw(self, deg: float) -> None:
        self._send({"v": 1, "type": "yaw", "deg": round(deg, 2)})
