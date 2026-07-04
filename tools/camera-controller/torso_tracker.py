"""Approximate torso yaw from pose landmarks + a Z-rotating cube face widget."""

from __future__ import annotations

import math

import cv2
import numpy as np

LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_HIP = 23
RIGHT_HIP = 24


def _landmark_ok(lm, min_visibility: float) -> bool:
    visibility = getattr(lm, "visibility", 1.0)
    return visibility is None or visibility >= min_visibility


def estimate_raw_yaw_deg(landmarks, *, min_visibility: float = 0.5) -> float | None:
    """Estimate body yaw in degrees from shoulder/hip depth asymmetry."""
    if max(RIGHT_SHOULDER, RIGHT_HIP) >= len(landmarks):
        return None

    ls = landmarks[LEFT_SHOULDER]
    rs = landmarks[RIGHT_SHOULDER]
    lh = landmarks[LEFT_HIP]
    rh = landmarks[RIGHT_HIP]

    if not all(_landmark_ok(lm, min_visibility) for lm in (ls, rs, lh, rh)):
        return None

    shoulder_yaw = math.degrees(math.atan2(rs.z - ls.z, rs.x - ls.x))
    hip_yaw = math.degrees(math.atan2(rh.z - lh.z, rh.x - lh.x))

    shoulder_span = math.hypot(rs.x - ls.x, rs.y - ls.y)
    hip_span = math.hypot(rh.x - lh.x, rh.y - lh.y)
    if shoulder_span < 1e-4:
        return None

    span_ratio = min(1.0, shoulder_span / max(hip_span, 1e-4))
    foreshorten = (1.0 - span_ratio) * 55.0
    depth_sign = 1.0 if (rs.z - ls.z) >= 0 else -1.0
    foreshorten_yaw = foreshorten * depth_sign

    yaw = 0.55 * shoulder_yaw + 0.25 * hip_yaw + 0.20 * foreshorten_yaw
    return max(-90.0, min(90.0, yaw))


class TorsoTracker:
    def __init__(self, *, smooth: float = 0.25):
        self.smooth = smooth
        self.yaw_deg: float | None = None

    def update(self, landmarks) -> float | None:
        raw = estimate_raw_yaw_deg(landmarks)
        if raw is None:
            return self.yaw_deg
        if self.yaw_deg is None:
            self.yaw_deg = raw
        else:
            self.yaw_deg += self.smooth * (raw - self.yaw_deg)
        return self.yaw_deg


def _rotate_z(x: float, z: float, angle_rad: float) -> tuple[float, float]:
    c = math.cos(angle_rad)
    s = math.sin(angle_rad)
    return x * c - z * s, x * s + z * c


def _cube_face_corners(
    yaw_deg: float,
    *,
    center: tuple[int, int],
    half_size: float,
) -> list[tuple[int, int]]:
    """Front face of a cube in XZ plane (Z up), rotated only around Z."""
    cx, cy = center
    angle = math.radians(-yaw_deg)
    corners: list[tuple[int, int]] = []
    for x, z in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)):
        xr, zr = _rotate_z(x, z, angle)
        px = int(round(cx + xr * half_size))
        py = int(round(cy - zr * half_size))
        corners.append((px, py))
    return corners


def draw_torso_widget(
    frame,
    *,
    yaw_deg: float | None,
    anchor: str = "top-right",
    panel_size: int = 120,
) -> None:
    h, w = frame.shape[:2]
    pad = 10
    if anchor == "top-right":
        x2 = w - pad
        x1 = x2 - panel_size
        y1 = pad
        y2 = y1 + panel_size
    else:
        x1, y1 = pad, pad
        x2 = x1 + panel_size
        y2 = y1 + panel_size

    cx = x1 + panel_size // 2
    cy = y1 + panel_size // 2

    overlay = frame.copy()
    cv2.rectangle(overlay, (x1, y1), (x2, y2), (24, 24, 24), -1)
    cv2.addWeighted(overlay, 0.55, frame, 0.45, 0, frame)
    cv2.rectangle(frame, (x1, y1), (x2, y2), (120, 120, 120), 1, cv2.LINE_AA)

    if yaw_deg is None:
        half = panel_size * 0.30
        neutral = _cube_face_corners(0.0, center=(cx, cy), half_size=half)
        cv2.polylines(frame, [np.array(neutral, dtype=np.int32)], True, (80, 80, 80), 1, cv2.LINE_AA)
        cv2.putText(
            frame,
            "yaw --",
            (x1 + 8, y2 - 12),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.42,
            (200, 200, 200),
            1,
            cv2.LINE_AA,
        )
        return

    half = panel_size * 0.30
    corners = _cube_face_corners(yaw_deg, center=(cx, cy), half_size=half)
    pts = np.array(corners, dtype=np.int32)

    cv2.fillPoly(frame, [pts], (50, 95, 130))
    cv2.polylines(frame, [pts], True, (120, 210, 255), 2, cv2.LINE_AA)

    # Top edge (Z+) marker so rotation direction is readable.
    cv2.line(frame, corners[3], corners[2], (255, 230, 120), 3, cv2.LINE_AA)
    cv2.circle(frame, ((corners[3][0] + corners[2][0]) // 2, (corners[3][1] + corners[2][1]) // 2), 3, (255, 230, 120), -1, cv2.LINE_AA)

    label = f"yaw {yaw_deg:+.0f}"
    cv2.putText(
        frame,
        label,
        (x1 + 8, y2 - 12),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.42,
        (230, 230, 230),
        1,
        cv2.LINE_AA,
    )
