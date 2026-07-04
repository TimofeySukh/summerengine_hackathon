# Katana Viewmodel Tuning

Approved first-person placement (playtest 2026-07-04):

| Property | Value |
|----------|-------|
| `IDLE_POSITION` | `(0.14, -0.22, -0.52)` |
| `IDLE_EULER` | `(0.06, 0.10, -0.18)` |
| Mesh transform | `Transform3D(0, -0.11, 0, 0.11, 0, 0, 0, 0, 0.11, 0.16, 0, -0.08)` |

Do not change these without an in-game playtest.

Slash arc uses a fixed diagonal rotation plane (`REST_TIP_DIR = forward`) on top of this idle pose.
