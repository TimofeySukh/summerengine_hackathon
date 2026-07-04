"""Direct wrist positions from the board camera (normalized screen 0–1)."""

from __future__ import annotations

from dataclasses import dataclass

LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_HIP = 23
RIGHT_HIP = 24


@dataclass(frozen=True)
class HandFrame:
    """Wrist positions in camera image space: x/y in 0–1, origin top-left."""

    lx: float
    ly: float
    rx: float
    ry: float


def _ok(lm, min_visibility: float) -> bool:
    visibility = getattr(lm, "visibility", 1.0)
    return visibility is None or visibility >= min_visibility


def compute_hand_frame(landmarks, *, min_visibility: float = 0.5) -> HandFrame | None:
    if max(LEFT_WRIST, RIGHT_WRIST) >= len(landmarks):
        return None

    lw = landmarks[LEFT_WRIST]
    rw = landmarks[RIGHT_WRIST]
    if not _ok(lw, min_visibility) or not _ok(rw, min_visibility):
        return None

    return HandFrame(lx=lw.x, ly=lw.y, rx=rw.x, ry=rw.y)


def compute_torso_center(landmarks, *, min_visibility: float = 0.5) -> tuple[float, float] | None:
    if RIGHT_HIP >= len(landmarks):
        return None
    points = (
        landmarks[LEFT_SHOULDER],
        landmarks[RIGHT_SHOULDER],
        landmarks[LEFT_HIP],
        landmarks[RIGHT_HIP],
    )
    if not all(_ok(lm, min_visibility) for lm in points):
        return None
    cx = sum(lm.x for lm in points) * 0.25
    cy = sum(lm.y for lm in points) * 0.25
    return cx, cy
