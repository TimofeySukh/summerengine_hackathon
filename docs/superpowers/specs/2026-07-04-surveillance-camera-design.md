# Surveillance Camera Gameplay — Design Spec

> Status: **Implemented (v1 slice)** — mic keywords still pending  
> Date: 2026-07-04 (updated same day)

## Summary

Heat Wave is pivoting from free first-person movement to **surveillance-only play**. The player watches the arena through security cameras, **manually pans/rotates** the active feed, and cuts enemies with a katana — **one slash button**, **no auto-aim**, **no auto camera tracking**.

The current keyboard/mouse build **implements** the surveillance model. WASD body movement is removed.

| Input | Action |
|-------|--------|
| **Mouse** | Pan / rotate `SurveillanceMount` |
| **Left mouse** | Katana slash from `FeedCamera` ray |
| **M** | Jog camera forward along pan arc *(voice "move" stand-in)* |
| **N** | Stop jog *(voice "stop" stand-in)* |

**Rule for agents:** do not add auto-aim, auto camera tracking, or body locomotion back without explicit request.

## Fantasy

You are at an operator desk in a neon night-city arena. Hostile humanoids cross the view of **one** rotatable security camera. You **sweep the lens yourself**, find the target in frame, and slash through the feed. Missing a window costs health. Nothing aims for you.

## Approved Control Model

| Input (final) | Action |
|---------------|--------|
| **Pan / rotate camera** | Manual — player turns the active CCTV mount (yaw/pitch within limits) |
| **One button** (LMB / Space) | Katana slash in the **current** camera view |
| **Body movement** | None |

### Voice input (proposed — future)

Optional **microphone** binds for hands-busy operator fantasy. Not required for v1; design before implementation.

| Voice command | Intended action |
|---------------|-----------------|
| **"move"** | Camera **moves forward** — continuous pan along its sweep arc in the forward direction until stopped |
| **"stop"** | Halt camera pan immediately |

**Notes**

- Voice controls **camera motion only** — slash stays on button (no voice attack in v1).
- **"move"** is not free aim: the mount travels **forward along its pan path** (one axis / arc), like holding a CCTV jog control. **"stop"** freezes it.
- Mouse pan remains available for manual fine adjustment; voice is jog forward / stop.
- Implementation likely uses simple **keyword detection** (keyword spotting — only `"move"` / `"stop"`, not full speech-to-text) with debounce so noise does not spam commands.
- Requires mic permission UX and a mute/off toggle.

**Rule for agents:** wire real mic keyword spotting when requested; M/N keyboard jog is the current stand-in.

### Explicitly rejected

- **Auto-aim** — no snap-to-enemy, no magnet hitboxes, no “smart” slash toward nearest target
- **Auto camera tracking** — camera never follows or switches to threats by itself
- **Auto feed selection** — system does not pick “best” camera for the player

### Player skill

1. Rotate the **single** arena camera to bring an enemy into the slash zone  
2. Time the slash when the target is in frame  

There is **one** security camera mount for the slice — no multi-post switching in v1.

## Implementation (v1)

- `SurveillanceMount` in `player/player.tscn` — fixed elevated position, yaw/pitch limits
- `player/camera_controller.gd` — mouse pan + jog forward/stop
- `player/voice_jog_listener.gd` — M/N triggers jog (mic keywords TBD)
- `player/player.gd` — static operator, slash from camera ray

## Open Questions

1. Slash zone: full frame, center band, or crosshair-only?
2. Katana on HUD overlay vs slash VFX only on the feed?
3. Real microphone keyword spotting provider / UX

## Out of Scope

- Auto-aim or threat-based camera systems
- Multi-camera feed switching

## Superseded Variants

Earlier draft options A (auto-camera) and auto feed selection are **rejected** per design decision 2026-07-04.
