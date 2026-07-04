"""Fast wrist slash detection for katana-style swings (vertical or diagonal)."""

from __future__ import annotations

import math
import time
from collections import deque
from dataclasses import dataclass, field
from typing import Literal

import cv2

Direction = Literal["up", "down"]
Hand = Literal["left", "right"]

LEFT_WRIST = 15
RIGHT_WRIST = 16


@dataclass(frozen=True)
class SlashEvent:
    direction: Direction
    hand: Hand
    speed_px_s: float
    travel_px: float
    start_x_px: float
    start_y_px: float
    end_x_px: float
    end_y_px: float
    timestamp: float


@dataclass
class SlashFlash:
    direction: Direction
    hand: Hand
    start_x_px: float
    start_y_px: float
    end_x_px: float
    end_y_px: float
    travel_px: float
    start: float
    duration: float = 0.45


@dataclass
class _WristHistory:
    samples: deque[tuple[float, float, float]] = field(default_factory=deque)
    last_slash_at: float = 0.0


class SlashDetector:
    """Detect big fast slashes; vertical or diagonal; ignore jitter and small moves."""

    def __init__(
        self,
        *,
        min_peak_speed_px_s: float = 480.0,
        min_travel_ratio: float = 0.26,
        min_vertical_ratio: float = 0.10,
        window_s: float = 0.24,
        cooldown_s: float = 0.55,
        direction_agreement: float = 0.68,
        min_visibility: float = 0.55,
        max_step_travel_ratio: float = 0.18,
    ):
        self.min_peak_speed_px_s = min_peak_speed_px_s
        self.min_travel_ratio = min_travel_ratio
        self.min_vertical_ratio = min_vertical_ratio
        self.window_s = window_s
        self.cooldown_s = cooldown_s
        self.direction_agreement = direction_agreement
        self.min_visibility = min_visibility
        self.max_step_travel_ratio = max_step_travel_ratio
        self._hands: dict[Hand, _WristHistory] = {
            "left": _WristHistory(),
            "right": _WristHistory(),
        }
        self.flashes: list[SlashFlash] = []
        self.last_event: SlashEvent | None = None
        self.total_slash_up = 0
        self.total_slash_down = 0

    def update(
        self,
        landmarks,
        *,
        frame_w: int,
        frame_h: int,
        now: float | None = None,
    ) -> SlashEvent | None:
        now = time.monotonic() if now is None else now
        self._prune_flashes(now)

        best: SlashEvent | None = None
        for hand, index in (("left", LEFT_WRIST), ("right", RIGHT_WRIST)):
            event = self._update_hand(hand, index, landmarks, frame_w, frame_h, now)
            if event is None:
                continue
            if best is None or event.travel_px > best.travel_px:
                best = event

        if best is not None:
            self.last_event = best
            self.flashes.append(
                SlashFlash(
                    direction=best.direction,
                    hand=best.hand,
                    start_x_px=best.start_x_px,
                    start_y_px=best.start_y_px,
                    end_x_px=best.end_x_px,
                    end_y_px=best.end_y_px,
                    travel_px=best.travel_px,
                    start=best.timestamp,
                )
            )
            if best.direction == "up":
                self.total_slash_up += 1
            else:
                self.total_slash_down += 1
            print(
                f"SLASH {best.direction.upper()} ({best.hand}, "
                f"{best.travel_px:.0f}px, peak {best.speed_px_s:.0f}px/s)"
            )
        return best

    def _update_hand(
        self,
        hand: Hand,
        index: int,
        landmarks,
        frame_w: int,
        frame_h: int,
        now: float,
    ) -> SlashEvent | None:
        if index >= len(landmarks):
            return None

        lm = landmarks[index]
        visibility = getattr(lm, "visibility", 1.0)
        if visibility is not None and visibility < self.min_visibility:
            return None

        x_px = lm.x * frame_w
        y_px = lm.y * frame_h
        history = self._hands[hand]

        if history.samples:
            _pt, px, py = history.samples[-1]
            step_travel = math.hypot(x_px - px, y_px - py)
            max_step = self.max_step_travel_ratio * frame_h
            if step_travel > max_step:
                history.samples.clear()

        history.samples.append((now, x_px, y_px))

        while history.samples and now - history.samples[0][0] > self.window_s:
            history.samples.popleft()

        if len(history.samples) < 4:
            return None
        if now - history.last_slash_at < self.cooldown_s:
            return None

        samples = list(history.samples)
        t0, x0, y0 = samples[0]
        t1, x1, y1 = samples[-1]
        dt = t1 - t0
        if dt < 0.08:
            return None

        dx = x1 - x0
        dy = y1 - y0
        travel = math.hypot(dx, dy)
        min_travel = self.min_travel_ratio * frame_h
        min_vertical = self.min_vertical_ratio * frame_h

        if travel < min_travel:
            return None
        if abs(dy) < min_vertical:
            return None

        peak_speed = 0.0
        ux, uy = dx / travel, dy / travel
        aligned_steps = 0
        total_steps = 0
        for i in range(1, len(samples)):
            pt0, px0, py0 = samples[i - 1]
            pt1, px1, py1 = samples[i]
            step_dt = pt1 - pt0
            if step_dt <= 0.0:
                continue
            sx = px1 - px0
            sy = py1 - py0
            step_len = math.hypot(sx, sy)
            if step_len <= 0.0:
                continue
            step_speed = step_len / step_dt
            peak_speed = max(peak_speed, step_speed)
            total_steps += 1
            if (sx / step_len) * ux + (sy / step_len) * uy >= 0.25:
                aligned_steps += 1

        if peak_speed < self.min_peak_speed_px_s:
            return None
        if total_steps and aligned_steps / total_steps < self.direction_agreement:
            return None

        direction: Direction = "up" if dy < 0 else "down"
        history.last_slash_at = now
        history.samples.clear()
        return SlashEvent(
            direction=direction,
            hand=hand,
            speed_px_s=peak_speed,
            travel_px=travel,
            start_x_px=x0,
            start_y_px=y0,
            end_x_px=x1,
            end_y_px=y1,
            timestamp=now,
        )

    def _prune_flashes(self, now: float) -> None:
        self.flashes = [f for f in self.flashes if now - f.start < f.duration]


def draw_wrist_markers(frame, landmarks, *, min_visibility: float = 0.55) -> None:
    h, w = frame.shape[:2]
    for index, color in ((LEFT_WRIST, (255, 180, 80)), (RIGHT_WRIST, (80, 180, 255))):
        if index >= len(landmarks):
            continue
        lm = landmarks[index]
        visibility = getattr(lm, "visibility", 1.0)
        if visibility is not None and visibility < min_visibility:
            continue
        x = int(lm.x * w)
        y = int(lm.y * h)
        cv2.circle(frame, (x, y), 10, color, 2, cv2.LINE_AA)
        cv2.circle(frame, (x, y), 3, color, -1, cv2.LINE_AA)


def draw_slash_overlay(frame, detector: SlashDetector, *, now: float | None = None) -> None:
    now = time.monotonic() if now is None else now
    h, w = frame.shape[:2]

    for flash in detector.flashes:
        age = now - flash.start
        t = max(0.0, 1.0 - age / flash.duration)
        if t <= 0.0:
            continue

        if flash.direction == "up":
            color = (255, 220, 60)
        else:
            color = (60, 90, 255)
        if flash.hand == "left":
            label = "<- LEFT"
        else:
            label = "RIGHT ->"

        sx = int(flash.start_x_px)
        sy = int(flash.start_y_px)
        ex = int(flash.start_x_px + (flash.end_x_px - flash.start_x_px) * t)
        ey = int(flash.start_y_px + (flash.end_y_px - flash.start_y_px) * t)
        thickness = max(2, int(10 * t))
        cv2.arrowedLine(
            frame,
            (sx, sy),
            (ex, ey),
            color,
            thickness,
            tipLength=0.25,
            line_type=cv2.LINE_AA,
        )

        cv2.rectangle(frame, (0, 0), (w - 1, h - 1), color, max(2, int(4 * t)), cv2.LINE_AA)

        text_scale = 1.0 + 0.4 * t
        text_th = max(2, int(3 * t))
        text_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_DUPLEX, text_scale, text_th)
        tx = (w - text_size[0]) // 2
        ty = int(h * 0.22)
        cv2.putText(
            frame,
            label,
            (tx + 2, ty + 2),
            cv2.FONT_HERSHEY_DUPLEX,
            text_scale,
            (0, 0, 0),
            text_th + 2,
            cv2.LINE_AA,
        )
        cv2.putText(
            frame,
            label,
            (tx, ty),
            cv2.FONT_HERSHEY_DUPLEX,
            text_scale,
            color,
            text_th,
            cv2.LINE_AA,
        )

    _draw_slash_hud(frame, detector)


def _draw_slash_hud(frame, detector: SlashDetector) -> None:
    h, _w = frame.shape[:2]
    min_travel = int(detector.min_travel_ratio * h)
    lines = [
        f"Katana: UP {detector.total_slash_up}  DOWN {detector.total_slash_down}",
        f"Big slash -> arrow key (left hand / right hand)",
    ]
    if detector.last_event is not None:
        evt = detector.last_event
        lines.append(
            f"Last: {evt.direction.upper()} ({evt.hand}, "
            f"{evt.travel_px:.0f}px, peak {evt.speed_px_s:.0f}px/s)"
        )

    y = h - 52
    for line in lines:
        cv2.putText(
            frame,
            line,
            (8, y),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.48,
            (230, 230, 230),
            1,
            cv2.LINE_AA,
        )
        y += 18
