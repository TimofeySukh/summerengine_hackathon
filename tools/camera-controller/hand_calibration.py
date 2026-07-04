"""Two-pose hand calibration: T-pose (max reach) then arms at rest (min)."""

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
SAMPLE_SECONDS = 1.5
COUNTDOWN_SECONDS = 3
MIN_SAMPLES = 12


@dataclass
class HandCalibration:
    """Maps raw torso-relative offsets to game space (0 = rest, 1 = T-pose reach)."""

    lx_tpose: float = 0.85
    ly_tpose: float = 0.05
    lx_rest: float = 0.15
    ly_rest: float = -0.55
    rx_tpose: float = -0.85
    ry_tpose: float = 0.05
    rx_rest: float = -0.15
    ry_rest: float = -0.55

    def apply(self, frame: HandFrame) -> HandFrame:
        return HandFrame(
            lx=_norm_axis(frame.lx, self.lx_rest, self.lx_tpose),
            ly=_norm_axis(frame.ly, self.ly_rest, self.ly_tpose),
            rx=_norm_axis(frame.rx, self.rx_rest, self.rx_tpose),
            ry=_norm_axis(frame.ry, self.ry_rest, self.ry_tpose),
            center_x=frame.center_x,
            center_y=frame.center_y,
            span=frame.span,
        )

    def summary_lines(self) -> list[str]:
        return [
            f"Left  X: rest {self.lx_rest:+.2f} -> T {self.lx_tpose:+.2f}",
            f"Left  Y: rest {self.ly_rest:+.2f} -> T {self.ly_tpose:+.2f}",
            f"Right X: rest {self.rx_rest:+.2f} -> T {self.rx_tpose:+.2f}",
            f"Right Y: rest {self.ry_rest:+.2f} -> T {self.ry_tpose:+.2f}",
        ]


def _norm_axis(raw: float, rest: float, tpose: float) -> float:
    span = tpose - rest
    if abs(span) < 1e-4:
        return 0.0
    return float(np.clip((raw - rest) / span, -0.35, 1.35))


def load_calibration(path: Path = DEFAULT_CALIBRATION_PATH) -> HandCalibration | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return HandCalibration(**{k: float(data[k]) for k in asdict(HandCalibration()).keys() if k in data})
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return None


def save_calibration(cal: HandCalibration, path: Path = DEFAULT_CALIBRATION_PATH) -> None:
    path.write_text(json.dumps(asdict(cal), indent=2) + "\n", encoding="utf-8")


@dataclass
class _SampleBuffer:
    frames: list[HandFrame] = field(default_factory=list)

    def add(self, frame: HandFrame | None) -> None:
        if frame is not None:
            self.frames.append(frame)

    def average(self) -> HandCalibration | None:
        if len(self.frames) < MIN_SAMPLES:
            return None
        lx = [f.lx for f in self.frames]
        ly = [f.ly for f in self.frames]
        rx = [f.rx for f in self.frames]
        ry = [f.ry for f in self.frames]
        return HandCalibration(
            lx_tpose=float(np.mean(lx)),
            ly_tpose=float(np.mean(ly)),
            rx_tpose=float(np.mean(rx)),
            ry_tpose=float(np.mean(ry)),
            lx_rest=float(np.mean(lx)),
            ly_rest=float(np.mean(ly)),
            rx_rest=float(np.mean(rx)),
            ry_rest=float(np.mean(ry)),
        )


class CalibratorPhase(Enum):
    INTRO = auto()
    WAIT_T_POSE = auto()
    COUNTDOWN_T = auto()
    SAMPLE_T = auto()
    WAIT_REST = auto()
    COUNTDOWN_REST = auto()
    SAMPLE_REST = auto()
    DONE = auto()
    SKIPPED = auto()


class HandCalibrator:
    def __init__(self, *, path: Path = DEFAULT_CALIBRATION_PATH):
        self.path = path
        self.phase = CalibratorPhase.INTRO
        self.calibration: HandCalibration | None = None
        self._tpose: HandCalibration | None = None
        self._rest: HandCalibration | None = None
        self._buffer = _SampleBuffer()
        self._phase_started = time.monotonic()
        self._countdown_from = 0
        self._message = ""
        self._error = ""

    @property
    def done(self) -> bool:
        return self.phase in (CalibratorPhase.DONE, CalibratorPhase.SKIPPED)

    @property
    def blocks_tracking(self) -> bool:
        if self.phase == CalibratorPhase.SKIPPED:
            return False
        if self.phase == CalibratorPhase.DONE:
            return time.monotonic() - self._phase_started <= 2.5
        return True

    @property
    def ready(self) -> bool:
        return self.calibration is not None and not self.blocks_tracking

    def skip(self) -> None:
        self.calibration = HandCalibration()
        self.phase = CalibratorPhase.SKIPPED
        self._message = "Calibration skipped — using defaults."

    def start(self) -> None:
        self.phase = CalibratorPhase.WAIT_T_POSE
        self._phase_started = time.monotonic()
        self._message = "Шаг 1/2: встань в T-pose (руки в стороны)."

    def handle_key(self, key: int) -> None:
        if self.done and self.phase != CalibratorPhase.DONE:
            return
        if key in (27, ord("q")):
            self.skip()
            return
        if key == ord("s") and self.phase != CalibratorPhase.DONE:
            self.skip()
            return
        if key == ord(" "):
            if self.phase == CalibratorPhase.INTRO:
                self.start()
            elif self.phase == CalibratorPhase.WAIT_T_POSE:
                self._begin_countdown(CalibratorPhase.COUNTDOWN_T)
            elif self.phase == CalibratorPhase.WAIT_REST:
                self._begin_countdown(CalibratorPhase.COUNTDOWN_REST)

    def update(self, landmarks) -> None:
        if self.done and self.phase != CalibratorPhase.DONE:
            return

        now = time.monotonic()
        frame = compute_hand_frame(landmarks) if landmarks is not None else None

        if self.phase == CalibratorPhase.INTRO:
            if now - self._phase_started > 0.5:
                self._message = "SPACE — калибровка (T-pose, потом руки вдоль тела)."
            return

        if self.phase in (CalibratorPhase.COUNTDOWN_T, CalibratorPhase.COUNTDOWN_REST):
            remaining = self._countdown_from - int(now - self._phase_started)
            if remaining <= 0:
                if self.phase == CalibratorPhase.COUNTDOWN_T:
                    self._begin_sample(CalibratorPhase.SAMPLE_T)
                else:
                    self._begin_sample(CalibratorPhase.SAMPLE_REST)
            return

        if landmarks is None:
            return

        if self.phase in (CalibratorPhase.WAIT_T_POSE, CalibratorPhase.WAIT_REST):
            if frame is None:
                self._error = "Не видно позу — отойди, лицом к камере."
            else:
                self._error = ""
            return

        if self.phase == CalibratorPhase.SAMPLE_T:
            self._buffer.add(frame)
            if frame is None:
                self._error = "Потерял позу во время T-pose."
            elif now - self._phase_started >= SAMPLE_SECONDS:
                self._tpose = self._buffer.average()
                self._buffer = _SampleBuffer()
                if self._tpose is None:
                    self._error = "Мало кадров — держи T-pose и нажми SPACE снова."
                    self.phase = CalibratorPhase.WAIT_T_POSE
                else:
                    self.phase = CalibratorPhase.WAIT_REST
                    self._phase_started = now
                    self._message = "Шаг 2/2: опусти руки вдоль тела."
                    self._error = ""
            return

        if self.phase == CalibratorPhase.SAMPLE_REST:
            self._buffer.add(frame)
            if frame is None:
                self._error = "Потерял позу во время замера."
            elif now - self._phase_started >= SAMPLE_SECONDS:
                self._rest = self._buffer.average()
                if self._rest is None:
                    self._error = "Мало кадров — постой спокойно и нажми SPACE снова."
                    self.phase = CalibratorPhase.WAIT_REST
                else:
                    self._finish()

    def _begin_countdown(self, phase: CalibratorPhase) -> None:
        self.phase = phase
        self._phase_started = time.monotonic()
        self._countdown_from = COUNTDOWN_SECONDS
        self._buffer = _SampleBuffer()
        self._error = ""

    def _begin_sample(self, phase: CalibratorPhase) -> None:
        self.phase = phase
        self._phase_started = time.monotonic()
        self._buffer = _SampleBuffer()
        self._error = ""

    def _finish(self) -> None:
        assert self._tpose is not None and self._rest is not None
        self.calibration = HandCalibration(
            lx_tpose=self._tpose.lx_tpose,
            ly_tpose=self._tpose.ly_tpose,
            rx_tpose=self._tpose.rx_tpose,
            ry_tpose=self._tpose.ry_tpose,
            lx_rest=self._rest.lx_rest,
            ly_rest=self._rest.ly_rest,
            rx_rest=self._rest.rx_rest,
            ry_rest=self._rest.ry_rest,
        )
        save_calibration(self.calibration, self.path)
        self.phase = CalibratorPhase.DONE
        self._message = f"Calibration saved to {self.path.name}"
        self._error = ""
        self._phase_started = time.monotonic()

    def countdown_value(self) -> int | None:
        if self.phase not in (CalibratorPhase.COUNTDOWN_T, CalibratorPhase.COUNTDOWN_REST):
            return None
        remaining = self._countdown_from - int(time.monotonic() - self._phase_started)
        return max(1, remaining)

    def sample_progress(self) -> float:
        if self.phase not in (CalibratorPhase.SAMPLE_T, CalibratorPhase.SAMPLE_REST):
            return 0.0
        elapsed = time.monotonic() - self._phase_started
        return float(np.clip(elapsed / SAMPLE_SECONDS, 0.0, 1.0))

    def draw_overlay(self, frame: np.ndarray) -> None:
        if self.done and self.phase == CalibratorPhase.DONE:
            if time.monotonic() - self._phase_started > 2.5:
                return

        h, w = frame.shape[:2]
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, h), (20, 20, 30), -1)
        cv2.addWeighted(overlay, 0.55, frame, 0.45, 0, frame)

        lines = ["Калибровка рук", "", self._message]
        if self.phase == CalibratorPhase.INTRO:
            lines += ["", "SPACE — начать", "S — пропустить (дефолт)", "Q — выход"]
        elif self.phase == CalibratorPhase.WAIT_T_POSE:
            lines += ["", "SPACE когда готов", "S — пропустить"]
        elif self.phase == CalibratorPhase.WAIT_REST:
            lines += ["", "SPACE когда готов"]
        elif self.phase in (CalibratorPhase.COUNTDOWN_T, CalibratorPhase.COUNTDOWN_REST):
            cd = self.countdown_value()
            if cd is not None:
                lines += ["", str(cd)]
        elif self.phase in (CalibratorPhase.SAMPLE_T, CalibratorPhase.SAMPLE_REST):
            pct = int(self.sample_progress() * 100)
            lines += ["", f"Не двигайся... {pct}%", f"кадров: {len(self._buffer.frames)}"]
        elif self.phase == CalibratorPhase.DONE and self.calibration is not None:
            lines += ["", "Готово!", *self.calibration.summary_lines(), "", "Запуск трекинга..."]

        if self._error:
            lines += ["", self._error]

        y = 34
        for line in lines:
            color = (240, 240, 240)
            if line.startswith("Step"):
                color = (120, 220, 255)
            elif line.isdigit():
                color = (100, 255, 180)
                cv2.putText(
                    frame,
                    line,
                    (w // 2 - 20, h // 2),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    3.0,
                    color,
                    4,
                    cv2.LINE_AA,
                )
                y = h // 2 + 40
                continue
            cv2.putText(
                frame,
                line,
                (24, y),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.62 if not line.isdigit() else 2.0,
                color,
                2 if line.isdigit() else 1,
                cv2.LINE_AA,
            )
            y += 30 if line else 14
