"""Map hand slashes to game key presses (macOS)."""

from __future__ import annotations

import subprocess
import sys
import time
from typing import Literal

Hand = Literal["left", "right"]


class ArrowKeyController:
    def __init__(self, *, cooldown_s: float = 0.35):
        self.cooldown_s = cooldown_s
        self._last_press: dict[Hand, float] = {"left": 0.0, "right": 0.0}
        self.total_left = 0
        self.total_right = 0
        self.backend = "none"
        self._pynput_key = None
        self._pynput_controller = None
        self._init_backend()

    def _init_backend(self) -> None:
        if sys.platform == "darwin":
            try:
                from pynput.keyboard import Controller, Key

                self._pynput_controller = Controller()
                self._pynput_key = Key
                self.backend = "pynput"
                return
            except ImportError:
                pass
            self.backend = "osascript"
            return

        try:
            from pynput.keyboard import Controller, Key

            self._pynput_controller = Controller()
            self._pynput_key = Key
            self.backend = "pynput"
        except ImportError:
            self.backend = "none"

    def on_hand_slash(self, hand: Hand) -> bool:
        now = time.monotonic()
        if now - self._last_press[hand] < self.cooldown_s:
            return False

        ok = self._press_arrow(hand)
        if ok:
            self._last_press[hand] = now
            if hand == "left":
                self.total_left += 1
            else:
                self.total_right += 1
            label = "Left" if hand == "left" else "Right"
            print(f"KEY {label} Arrow ({hand} hand slash)")
        return ok

    def _press_arrow(self, hand: Hand) -> bool:
        key_name = "left_arrow" if hand == "left" else "right_arrow"
        return self._tap_key(key_name)

    def _tap_key(self, key_name: str) -> bool:
        if self.backend == "pynput" and self._pynput_controller is not None:
            key = self._resolve_pynput_key(key_name)
            self._pynput_controller.press(key)
            self._pynput_controller.release(key)
            return True

        if self.backend == "osascript" and sys.platform == "darwin":
            code = self._osascript_key_code(key_name)
            if code < 0:
                return False
            try:
                subprocess.run(
                    [
                        "osascript",
                        "-e",
                        f'tell application "System Events" to key code {code}',
                    ],
                    check=False,
                    capture_output=True,
                    timeout=1.0,
                )
                return True
            except (OSError, subprocess.TimeoutExpired):
                return False

        print("Arrow keys unavailable: install pynput or enable Accessibility for osascript")
        return False

    def _resolve_pynput_key(self, key_name: str):
        if key_name == "left_arrow":
            return self._pynput_key.left
        if key_name == "right_arrow":
            return self._pynput_key.right
        return key_name

    def _osascript_key_code(self, key_name: str) -> int:
        return {
            "left_arrow": 123,
            "right_arrow": 124,
        }.get(key_name, -1)
