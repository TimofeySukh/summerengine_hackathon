"""Persistent HTTP MJPEG capture for ustreamer board camera API."""

from __future__ import annotations

import time

import cv2
import numpy as np


class MjpegStreamReader:
    """Keep one VideoCapture open; retry reads instead of reconnect storms."""

    def __init__(
        self,
        url: str,
        *,
        reconnect_delay: float = 1.0,
        read_retry_delay: float = 0.05,
        failures_before_reopen: int = 30,
    ):
        self.url = url
        self.reconnect_delay = reconnect_delay
        self.read_retry_delay = read_retry_delay
        self.failures_before_reopen = max(5, failures_before_reopen)
        self._cap: cv2.VideoCapture | None = None
        self._last_frame: np.ndarray | None = None
        self._read_failures = 0
        self._empty_frames = 0
        self.connected = False
        self.last_error = ""
        self._next_reopen_at = 0.0

    @property
    def empty_frame_count(self) -> int:
        return self._empty_frames

    def start(self) -> bool:
        return self._ensure_open()

    def stop(self) -> None:
        self._release()

    def close(self) -> None:
        self.stop()

    def _release(self) -> None:
        if self._cap is not None:
            try:
                self._cap.release()
            except cv2.error:
                pass
        self._cap = None
        self.connected = False

    def _ensure_open(self) -> bool:
        now = time.monotonic()
        if self._cap is not None and self._cap.isOpened():
            self.connected = True
            return True

        if now < self._next_reopen_at:
            return False

        self._release()
        try:
            cap = cv2.VideoCapture(self.url, cv2.CAP_FFMPEG)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            if not cap.isOpened():
                self.last_error = "VideoCapture failed to open stream"
                self.connected = False
                self._next_reopen_at = now + self.reconnect_delay
                return False

            self._cap = cap
            self.connected = True
            self.last_error = ""
            self._read_failures = 0
            return True
        except cv2.error as exc:
            self.last_error = str(exc)
            self.connected = False
            self._next_reopen_at = now + self.reconnect_delay
            return False

    def read_latest(self) -> tuple[bool, np.ndarray | None]:
        """Return (is_new_frame, frame). On temporary failure reuse last good frame."""
        if not self._ensure_open():
            time.sleep(self.read_retry_delay)
            return False, self._last_frame

        assert self._cap is not None
        ok, frame = self._cap.read()

        if ok and frame is not None and frame.size > 0:
            frame = cv2.flip(frame, 1)  # mirror view (selfie), not audience-facing
            self._last_frame = frame
            self._read_failures = 0
            self._empty_frames = 0
            return True, frame

        self._read_failures += 1
        if not ok:
            self.last_error = "VideoCapture.read() returned no frame"

        if self._read_failures >= self.failures_before_reopen:
            self.last_error = (
                f"Too many read failures ({self._read_failures}); "
                "will reopen stream once"
            )
            self._release()
            self._read_failures = 0
            self._next_reopen_at = time.monotonic() + self.reconnect_delay
        else:
            time.sleep(self.read_retry_delay)

        return False, self._last_frame

    def consume_new_frame(self, last_seq: int) -> tuple[int, np.ndarray | None]:
        del last_seq
        is_new, frame = self.read_latest()
        if not is_new or frame is None:
            return 0, None
        return 1, frame
