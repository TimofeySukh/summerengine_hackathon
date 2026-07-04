"""Per-wrist screen bounds: sweep calibration + runtime auto-tuning."""

from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass, field
from enum import Enum, auto
from pathlib import Path

import cv2
import numpy as np

from hand_tracker import HandFrame, compute_hand_frame

DEFAULT_CALIBRATION_PATH = Path(__file__).resolve().parent / "hand_calibration.json"
SWEEP_SECONDS = 14.0
MIN_AXIS_SPAN = 0.12
CENTER_MOVE_THRESHOLD = 0.07
CENTER_RESET_BUFFER_S = 2.0
AUTOSAVE_INTERVAL_S = 30.0


@dataclass
class WristBounds:
    x_min: float = 0.08
    x_max: float = 0.42
    y_min: float = 0.08
    y_max: float = 0.88

    def copy(self) -> WristBounds:
        return WristBounds(self.x_min, self.x_max, self.y_min, self.y_max)

    def valid(self) -> bool:
        return (self.x_max - self.x_min >= MIN_AXIS_SPAN) and (self.y_max - self.y_min >= MIN_AXIS_SPAN)

    def expand_with(self, x: float, y: float) -> bool:
        changed = False
        if x < self.x_min:
            self.x_min = x
            changed = True
        if x > self.x_max:
            self.x_max = x
            changed = True
        if y < self.y_min:
            self.y_min = y
            changed = True
        if y > self.y_max:
            self.y_max = y
            changed = True
        return changed

    def map_point(self, x: float, y: float) -> tuple[float, float]:
        sx = self.x_max - self.x_min
        sy = self.y_max - self.y_min
        nx = 0.5 if sx < 1e-4 else float(np.clip((x - self.x_min) / sx, 0.0, 1.0))
        ny = 0.5 if sy < 1e-4 else float(np.clip((y - self.y_min) / sy, 0.0, 1.0))
        return nx, ny

    def summary(self, label: str) -> str:
        return (
            f"{label}: x [{self.x_min:.2f}..{self.x_max:.2f}] "
            f"y [{self.y_min:.2f}..{self.y_max:.2f}]"
        )


@dataclass
class HandCalibration:
    left: WristBounds = field(default_factory=WristBounds)
    right: WristBounds = field(default_factory=lambda: WristBounds(0.58, 0.92, 0.08, 0.88))

    @classmethod
    def default(cls) -> HandCalibration:
        return cls()

    def copy(self) -> HandCalibration:
        return HandCalibration(left=self.left.copy(), right=self.right.copy())

    def expand_frame(self, frame: HandFrame) -> bool:
        changed = self.left.expand_with(frame.lx, frame.ly)
        changed = self.right.expand_with(frame.rx, frame.ry) or changed
        return changed

    def apply(self, frame: HandFrame) -> HandFrame:
        lx, ly = self.left.map_point(frame.lx, frame.ly)
        rx, ry = self.right.map_point(frame.rx, frame.ry)
        return HandFrame(lx=lx, ly=ly, rx=rx, ry=ry)

    def summary_lines(self) -> list[str]:
        return [self.left.summary("Left wrist"), self.right.summary("Right wrist")]


def load_calibration(path: Path = DEFAULT_CALIBRATION_PATH) -> HandCalibration | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if "left" in data and "right" in data:
            return HandCalibration(
                left=WristBounds(**{k: float(data["left"][k]) for k in asdict(WristBounds())}),
                right=WristBounds(**{k: float(data["right"][k]) for k in asdict(WristBounds())}),
            )
        return None
    except (OSError, json.JSONDecodeError, TypeError, ValueError, KeyError):
        return None


def save_calibration(cal: HandCalibration, path: Path = DEFAULT_CALIBRATION_PATH) -> None:
    payload = {"version": 2, "left": asdict(cal.left), "right": asdict(cal.right)}
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


class RuntimeBoundsTracker:
    """Expand bounds while the torso stays put; reset after 2s of body movement."""

    def __init__(
        self,
        baseline: HandCalibration,
        *,
        path: Path = DEFAULT_CALIBRATION_PATH,
        center_move_threshold: float = CENTER_MOVE_THRESHOLD,
        reset_buffer_s: float = CENTER_RESET_BUFFER_S,
    ):
        self.path = path
        self.baseline = baseline.copy()
        self.live = baseline.copy()
        self.center_move_threshold = center_move_threshold
        self.reset_buffer_s = reset_buffer_s
        self._anchor_center: tuple[float, float] | None = None
        self._unsettled_since: float | None = None
        self._last_autosave = time.monotonic()

    def update(self, frame: HandFrame, center: tuple[float, float], *, now: float | None = None) -> HandFrame:
        now = time.monotonic() if now is None else now
        if self._anchor_center is None:
            self._anchor_center = center

        moved = (
            abs(center[0] - self._anchor_center[0]) > self.center_move_threshold
            or abs(center[1] - self._anchor_center[1]) > self.center_move_threshold
        )

        if moved:
            if self._unsettled_since is None:
                self._unsettled_since = now
            elif now - self._unsettled_since >= self.reset_buffer_s:
                self.live = self.baseline.copy()
                self._anchor_center = center
                self._unsettled_since = None
        else:
            self._unsettled_since = None
            self._anchor_center = (
                self._anchor_center[0] * 0.92 + center[0] * 0.08,
                self._anchor_center[1] * 0.92 + center[1] * 0.08,
            )
            if self.live.expand_frame(frame):
                self.baseline = self.live.copy()
                if now - self._last_autosave >= AUTOSAVE_INTERVAL_S:
                    save_calibration(self.baseline, self.path)
                    self._last_autosave = now

        return self.live.apply(frame)


class CalibratorPhase(Enum):
    INTRO = auto()
    SWEEP = auto()
    DONE = auto()
    SKIPPED = auto()


class SweepCalibrator:
    def __init__(self, *, path: Path = DEFAULT_CALIBRATION_PATH):
        self.path = path
        self.phase = CalibratorPhase.INTRO
        self.calibration = HandCalibration.default()
        self._phase_started = time.monotonic()
        self._message = ""
        self._error = ""
        self._sample_count = 0

    @property
    def blocks_tracking(self) -> bool:
        if self.phase == CalibratorPhase.SKIPPED:
            return False
        if self.phase == CalibratorPhase.DONE:
            return time.monotonic() - self._phase_started <= 2.5
        return True

    @property
    def ready(self) -> bool:
        return self.phase in (CalibratorPhase.DONE, CalibratorPhase.SKIPPED)

    def skip(self) -> None:
        self.calibration = HandCalibration.default()
        self.phase = CalibratorPhase.SKIPPED
        self._message = "Defaults."

    def start_sweep(self) -> None:
        self.calibration = HandCalibration.default()
        self._sample_count = 0
        self.phase = CalibratorPhase.SWEEP
        self._phase_started = time.monotonic()
        self._message = "Веди вытянутыми руками сверху вниз по бокам."
        self._error = ""

    def handle_key(self, key: int) -> None:
        if self.phase == CalibratorPhase.DONE:
            return
        if key in (27, ord("q")):
            self.skip()
            return
        if key == ord("s") and self.phase != CalibratorPhase.DONE:
            self.skip()
            return
        if key == ord(" "):
            if self.phase == CalibratorPhase.INTRO:
                self.start_sweep()
            elif self.phase == CalibratorPhase.SWEEP:
                self._finish()

    def update(self, landmarks) -> None:
        if self.phase == CalibratorPhase.INTRO:
            self._message = "SPACE — калибровка (руки вдоль боков, сверху вниз)."
            return
        if self.phase != CalibratorPhase.SWEEP:
            return

        now = time.monotonic()
        frame = compute_hand_frame(landmarks) if landmarks is not None else None
        if frame is None:
            self._error = "Не видно запястья — отойди, лицом к камере."
            return

        self._error = ""
        self.calibration.expand_frame(frame)
        self._sample_count += 1

        if now - self._phase_started >= SWEEP_SECONDS:
            self._finish()

    def _finish(self) -> None:
        if self._sample_count < 8 or not self.calibration.left.valid() or not self.calibration.right.valid():
            self._error = "Мало данных — повтори замах шире и нажми SPACE."
            self.phase = CalibratorPhase.INTRO
            return
        save_calibration(self.calibration, self.path)
        self.phase = CalibratorPhase.DONE
        self._message = f"Сохранено в {self.path.name}"
        self._phase_started = time.monotonic()

    def sweep_progress(self) -> float:
        if self.phase != CalibratorPhase.SWEEP:
            return 0.0
        return float(np.clip((time.monotonic() - self._phase_started) / SWEEP_SECONDS, 0.0, 1.0))

    def draw_overlay(self, frame: np.ndarray) -> None:
        if self.phase == CalibratorPhase.DONE and time.monotonic() - self._phase_started > 2.5:
            return

        h, w = frame.shape[:2]
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, h), (20, 20, 30), -1)
        cv2.addWeighted(overlay, 0.55, frame, 0.45, 0, frame)

        lines = ["Калибровка рук", "", self._message]
        if self.phase == CalibratorPhase.INTRO:
            lines += ["", "SPACE — начать", "S — дефолт", "Q — выход"]
        elif self.phase == CalibratorPhase.SWEEP:
            pct = int(self.sweep_progress() * 100)
            lines += [
                "",
                f"Замахай руками по бокам... {pct}%",
                f"кадров: {self._sample_count}",
                "SPACE — закончить раньше",
                *self.calibration.summary_lines(),
            ]
        elif self.phase == CalibratorPhase.DONE:
            lines += ["", "Готово!", *self.calibration.summary_lines()]
        elif self.phase == CalibratorPhase.SKIPPED:
            lines += ["", "Пропущено."]

        if self._error:
            lines += ["", self._error]

        y = 34
        for line in lines:
            cv2.putText(
                frame,
                line,
                (24, y),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.58,
                (240, 240, 240),
                1,
                cv2.LINE_AA,
            )
            y += 28 if line else 12

        if self.phase == CalibratorPhase.SWEEP:
            bar_w = w - 48
            fill = int(bar_w * self.sweep_progress())
            cv2.rectangle(frame, (24, h - 36), (24 + bar_w, h - 16), (60, 60, 60), -1)
            cv2.rectangle(frame, (24, h - 36), (24 + fill, h - 16), (90, 200, 120), -1)
