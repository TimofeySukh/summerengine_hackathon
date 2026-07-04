"""Play board microphone stream from /audio.wav (single persistent client)."""

from __future__ import annotations

import struct
import threading
import time
import urllib.error
import urllib.request

import numpy as np
import sounddevice as sd

DEFAULT_AUDIO_URL = "http://cph14.tailcfa96c.ts.net:8081/audio.wav"
DEFAULT_HEALTH_URL = "http://cph14.tailcfa96c.ts.net:8081/health"


def _read_wav_header(stream) -> tuple[int, int, int]:
    if stream.read(4) != b"RIFF":
        raise ValueError("Not a RIFF stream")
    stream.read(4)
    if stream.read(4) != b"WAVE":
        raise ValueError("Not a WAVE stream")

    sample_rate = 16000
    channels = 1
    sample_width = 2

    while True:
        chunk_id = stream.read(4)
        if len(chunk_id) < 4:
            raise ValueError("WAV header truncated")
        (chunk_size,) = struct.unpack("<I", stream.read(4))
        if chunk_id == b"fmt ":
            fmt = stream.read(chunk_size)
            channels = struct.unpack("<H", fmt[2:4])[0]
            sample_rate = struct.unpack("<I", fmt[4:8])[0]
            bits = struct.unpack("<H", fmt[14:16])[0]
            sample_width = max(1, bits // 8)
        elif chunk_id == b"data":
            return sample_rate, channels, sample_width
        else:
            stream.read(chunk_size)


class BoardAudioPlayer:
    """Background player; keeps one HTTP connection to the board audio stream."""

    def __init__(
        self,
        url: str = DEFAULT_AUDIO_URL,
        *,
        reconnect_delay: float = 2.0,
        read_chunk_bytes: int = 4096,
    ):
        self.url = url
        self.reconnect_delay = reconnect_delay
        self.read_chunk_bytes = read_chunk_bytes
        self.connected = False
        self.last_error = ""
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, name="board-audio", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=3.0)
            self._thread = None
        self.connected = False

    def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                self._stream_once()
            except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
                self.connected = False
                self.last_error = str(exc)
                time.sleep(self.reconnect_delay)

    def _stream_once(self) -> None:
        request = urllib.request.Request(
            self.url,
            headers={"Connection": "keep-alive", "Accept": "audio/wav,*/*"},
        )
        with urllib.request.urlopen(request, timeout=10) as response:
            sample_rate, channels, sample_width = _read_wav_header(response)
            dtype = np.int16 if sample_width == 2 else np.int8
            frame_bytes = sample_width * channels

            with sd.OutputStream(
                samplerate=sample_rate,
                channels=channels,
                dtype=dtype,
            ) as out:
                self.connected = True
                self.last_error = ""
                pending = b""
                while not self._stop.is_set():
                    chunk = response.read(self.read_chunk_bytes)
                    if not chunk:
                        self.connected = False
                        break
                    pending += chunk
                    usable = len(pending) - (len(pending) % frame_bytes)
                    if usable <= 0:
                        continue
                    pcm = pending[:usable]
                    pending = pending[usable:]
                    out.write(np.frombuffer(pcm, dtype=dtype))
