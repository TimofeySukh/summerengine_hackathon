"""Offline recognition for the spoken WAVE superpower command."""

from __future__ import annotations

import json
import time
import urllib.request
import zipfile
from pathlib import Path
from typing import Callable

import numpy as np

MODEL_NAME = "vosk-model-small-en-us-0.15"
MODEL_URL = f"https://alphacephei.com/kaldi/models/{MODEL_NAME}.zip"
MODEL_DIR = Path(__file__).resolve().parent / "models"
DEFAULT_MODEL_PATH = MODEL_DIR / MODEL_NAME


class VoiceWaveDetector:
    """Detect the word "wave" from streamed board microphone PCM."""

    def __init__(
        self,
        *,
        on_wave: Callable[[float], None],
        model_path: Path = DEFAULT_MODEL_PATH,
        threshold: float = 0.7,
        cooldown_s: float = 3.0,
        auto_download: bool = True,
    ):
        self.on_wave = on_wave
        self.model_path = model_path
        self.threshold = threshold
        self.cooldown_s = cooldown_s
        self._last_wave_at = 0.0
        self._recognizer = None
        self._sample_rate = 0
        self._available = False
        self.last_error = ""

        try:
            self._vosk = __import__("vosk")
        except ImportError:
            self._vosk = None
            self.last_error = "vosk package is not installed"
            return

        if not self.model_path.exists():
            if not auto_download:
                self.last_error = f"voice model missing: {self.model_path}"
                return
            try:
                self._download_model()
            except (OSError, zipfile.BadZipFile) as exc:
                self.last_error = f"voice model download failed: {exc}"
                return

        self._available = True

    @property
    def available(self) -> bool:
        return self._available

    def accept_pcm(
        self,
        pcm: bytes,
        *,
        sample_rate: int,
        channels: int,
        sample_width: int,
    ) -> None:
        if not self._available:
            return
        if sample_width != 2 or sample_rate <= 0:
            return

        mono_pcm = self._to_mono_16bit(pcm, channels)
        if not mono_pcm:
            return

        recognizer = self._get_recognizer(sample_rate)
        if recognizer.AcceptWaveform(mono_pcm):
            self._process_result(recognizer.Result())
        else:
            self._process_result(recognizer.PartialResult(), partial=True)

    def _get_recognizer(self, sample_rate: int):
        if self._recognizer is not None and self._sample_rate == sample_rate:
            return self._recognizer

        assert self._vosk is not None
        self._vosk.SetLogLevel(-1)
        model = self._vosk.Model(str(self.model_path))
        grammar = json.dumps(["wave", "[unk]"])
        recognizer = self._vosk.KaldiRecognizer(model, float(sample_rate), grammar)
        recognizer.SetWords(True)
        self._recognizer = recognizer
        self._sample_rate = sample_rate
        return recognizer

    def _process_result(self, raw: str, *, partial: bool = False) -> None:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return

        text = str(data.get("partial" if partial else "text", "")).strip().lower()
        if text != "wave":
            return

        confidence = self._confidence(data, partial=partial)
        if confidence < self.threshold:
            return

        now = time.monotonic()
        if now - self._last_wave_at < self.cooldown_s:
            return

        self._last_wave_at = now
        print(f"VOICE WAVE ({confidence:.2f})")
        self.on_wave(confidence)

    def _confidence(self, data: dict, *, partial: bool) -> float:
        if partial:
            return self.threshold
        words = data.get("result", [])
        if not isinstance(words, list) or not words:
            return 1.0
        confidences = [
            float(item.get("conf", 0.0))
            for item in words
            if isinstance(item, dict) and str(item.get("word", "")).lower() == "wave"
        ]
        if not confidences:
            return 0.0
        return max(confidences)

    def _to_mono_16bit(self, pcm: bytes, channels: int) -> bytes:
        if channels <= 1:
            return pcm
        samples = np.frombuffer(pcm, dtype=np.int16)
        if samples.size < channels:
            return b""
        frames = samples[: samples.size - (samples.size % channels)].reshape((-1, channels))
        return frames[:, 0].copy().tobytes()

    def _download_model(self) -> None:
        MODEL_DIR.mkdir(parents=True, exist_ok=True)
        zip_path = MODEL_DIR / f"{MODEL_NAME}.zip"
        print(f"Downloading voice model to {zip_path} ...")
        urllib.request.urlretrieve(MODEL_URL, zip_path)
        with zipfile.ZipFile(zip_path) as archive:
            archive.extractall(MODEL_DIR)
