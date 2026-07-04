"""Send pose/slash events to Heat Wave over UDP (CameraInputBridge autoload)."""

from __future__ import annotations

import base64
import json
import socket
from typing import Literal

from hand_tracker import HandFrame

Hand = Literal["left", "right"]
MAX_PREVIEW_BYTES = 60_000


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

    def send_hands(self, frame: HandFrame, *, yaw_deg: float | None = None) -> None:
        payload = {
            "v": 1,
            "type": "hands",
            "lx": round(frame.lx, 4),
            "ly": round(frame.ly, 4),
            "rx": round(frame.rx, 4),
            "ry": round(frame.ry, 4),
        }
        if yaw_deg is not None:
            payload["deg"] = round(yaw_deg, 2)
        self._send(payload)

    def send_preview(self, jpeg: bytes) -> None:
        if not jpeg or len(jpeg) > MAX_PREVIEW_BYTES:
            return
        self._send(
            {
                "v": 1,
                "type": "preview",
                "jpg": base64.b64encode(jpeg).decode("ascii"),
            }
        )
