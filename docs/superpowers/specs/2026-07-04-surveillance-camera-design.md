# Surveillance Camera Gameplay — Design Spec

> Status: **Approved direction — manual camera control, no auto-aim**  
> Date: 2026-07-04 (updated same day)

## Summary

Heat Wave is pivoting from free first-person movement to **surveillance-only play**. The player watches the arena through security cameras, **manually pans/rotates** the active feed, and cuts enemies with a katana — **one slash button**, **no auto-aim**, **no auto camera tracking**.

The current WASD + mouse prototype is a **temporary stand-in**. Mouse look maps to future **camera rotation**; body movement will be removed. Do not invest in polishing FPS locomotion.

## Fantasy

You are at an operator desk in a neon night-city arena. Hostile humanoids move through the coverage of wall-mounted cameras. You **sweep the lens yourself**, find the target in frame, and slash through the feed. Missing a window costs health. Nothing aims for you.

## Approved Control Model

| Input (final) | Action |
|---------------|--------|
| **Pan / rotate camera** | Manual — player turns the active CCTV mount (yaw/pitch within limits) |
| **One button** (LMB / Space) | Katana slash in the **current** camera view |
| **Body movement** | None |

### Explicitly rejected

- **Auto-aim** — no snap-to-enemy, no magnet hitboxes, no “smart” slash toward nearest target
- **Auto camera tracking** — camera never follows or switches to threats by itself
- **Auto feed selection** — system does not pick “best” camera for the player

### Player skill

1. Rotate the camera to bring an enemy into the slash zone  
2. Time the slash when the target is in frame  
3. (Optional later) Manually switch to another camera post — still **player-chosen**, never automatic

## Prototype Mapping (Now)

Until real CCTV nodes ship, keyboard/mouse **simulate** the final model:

| Prototype input | Stands in for (final) |
|-----------------|------------------------|
| **Mouse look** | Camera pan / rotate on mount |
| **Left mouse** | Katana slash |
| WASD | Temporary body movement — **will be removed** |
| Space jump | Temporary — **will be removed** |

**Rule for agents:** do not implement surveillance cameras yet. Do not add auto-aim or auto camera switch logic. Keep WASD until camera scenes replace body movement.

## Camera Implementation Notes (Future — No Code Yet)

When cameras are built:

- Each security camera is a **fixed mount** with a limited rotation arc (typical PTZ — pan-tilt-zoom, here pan/tilt only unless zoom is added later)
- Slash hit detection runs in **active feed space** (ray or volume from camera forward axis / screen center)
- Slash only hits what the player actually framed — skill = aim + timing
- Optional: multiple fixed camera **posts** around the arena; player manually switches feed (e.g. number keys or UI click) — **not** auto-selected

## Open Questions

1. **One rotatable camera** vs **several posts** the player switches between manually?
2. Slash zone: full frame, center band, or crosshair-only?
3. Katana on HUD overlay vs slash VFX only on the feed?

## Out of Scope (This Spec)

- Camera implementation code
- Removing WASD / retargeting input map
- Auto-aim or threat-based camera systems

## Superseded Variants

Earlier draft options A (auto-camera) and auto feed selection are **rejected** per design decision 2026-07-04.
