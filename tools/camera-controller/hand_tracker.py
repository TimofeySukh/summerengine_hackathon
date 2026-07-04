"""Torso-centered hand offsets for in-game katana viewmodels."""

from __future__ import annotations

from dataclasses import dataclass

LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24


@dataclass(frozen=True)
class HandFrame:
    """Offsets in game space: +x right on screen, +y up on screen."""

    lx: float
    ly: float
    rx: float
    ry: float
    center_x: float
    center_y: float
    span: float


def _ok(lm, min_visibility: float) -> bool:
    visibility = getattr(lm, "visibility", 1.0)
    return visibility is None or visibility >= min_visibility


def compute_hand_frame(landmarks, *, min_visibility: float = 0.5) -> HandFrame | None:
    if max(RIGHT_HIP, RIGHT_WRIST) >= len(landmarks):
        return None

    ls = landmarks[LEFT_SHOULDER]
    rs = landmarks[RIGHT_SHOULDER]
    lh = landmarks[LEFT_HIP]
    rh = landmarks[RIGHT_HIP]
    lw = landmarks[LEFT_WRIST]
    rw = landmarks[RIGHT_WRIST]

    needed = (ls, rs, lh, rh, lw, rw)
    if not all(_ok(lm, min_visibility) for lm in needed):
        return None

    center_x = (ls.x + rs.x + lh.x + rh.x) * 0.25
    center_y = (ls.y + rs.y + lh.y + rh.y) * 0.25

    span = ((rs.x - ls.x) ** 2 + (rs.y - ls.y) ** 2) ** 0.5
    if span < 1e-4:
        return None

    # Board camera is mirrored: keep +y as screen-up, but do not flip x (MediaPipe
    # already labels left/right from the player's body, not the mirrored image).
    lx = (lw.x - center_x) / span
    ly = -(lw.y - center_y) / span
    rx = (rw.x - center_x) / span
    ry = -(rw.y - center_y) / span

    return HandFrame(
        lx=lx,
        ly=ly,
        rx=rx,
        ry=ry,
        center_x=center_x,
        center_y=center_y,
        span=span,
    )
