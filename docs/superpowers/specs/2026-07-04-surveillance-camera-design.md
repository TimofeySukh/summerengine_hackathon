# Surveillance Camera Gameplay — Design Spec

> Status: **Draft — awaiting direction choice**  
> Date: 2026-07-04

## Summary

Heat Wave is pivoting from free first-person movement to **surveillance-only play**. In the final game the player never walks the arena directly. They watch the world through fixed security cameras and interact almost exclusively by **swinging the katana** — ideally with **one primary action button**.

The current WASD + mouse prototype is a **temporary stand-in**. It simulates being “on a camera feed” until the real camera system is built. Do not invest in polishing FPS movement; treat it as disposable scaffolding.

## Fantasy

You are trapped behind a monitor wall in a neon night-city arena. Hostile humanoids move through blind spots and camera coverage. You cannot run to them — you can only **cut through the feed** when a target enters your slash window. Success feels like precise timing and reading multiple angles, not platforming.

## Final Target (North Star)

| Area | Final intent |
|------|----------------|
| View | One or more fixed security camera feeds (CCTV aesthetic) |
| Movement | **None** — no WASD body movement in shipping design |
| Primary action | **One button** — katana slash |
| Secondary actions | None in v1, or at most passive camera switching (see variants) |
| Enemies | Enter camera frustums; player reacts with timed slashes |
| Fail state | Miss the window → contact damage / breach / game over pressure |

## Prototype Phase (Now)

Until the camera stack exists:

- Keep keyboard + mouse controls **only as a dev placeholder**
- Left mouse = katana slash (same as today)
- WASD / mouse look = **not final design**; documented as fake “operator desk” input
- Arena, chasers, slash VFX, and hit detection remain useful testbeds for slash timing and enemy paths

**Rule for agents:** do not implement surveillance cameras yet. Do not remove WASD until the chosen variant is approved and camera work is scheduled.

## Control Variants (Pick One)

Three viable one-button directions. Each can start with keyboard slash (LMB) during prototype.

### Variant A — **Auto-Camera Slash** (recommended)

**Button:** Space or Left Mouse — slash on the **currently active** camera.

**Camera behavior:** System auto-selects the feed (single cam at first; later: threat-based switch — e.g. camera with nearest enemy in slash zone).

**Player skill:** Timing — press when the enemy crosses the slash band (center third of frame, floor lane, etc.).

**Pros**

- True one-button loop in shipping build
- Strong readable fantasy: you trust the system to show the right angle
- Easiest to implement after cameras exist

**Cons**

- Less player agency over viewpoint
- Auto-switch logic must feel fair, not random

**Best if:** you want a tight arcade / rhythm-survival game.

---

### Variant B — **Multi-Feed Operator**

**Button:** Left Mouse — slash **where you are looking** within the active feed (ray from screen center or cursor snap to nearest enemy silhouette).

**Camera behavior:** Player picks camera with **prototype-only** keys (1–4, Q/E, click minimap). In final build, camera pick might become automatic round-robin or split-screen grid with focus highlight — still one slash button, but implicit “focus” before slash.

**Player skill:** Choose the right monitor, then slash.

**Pros**

- Tactical “security room” feel
- Natural fit for multi-camera arena layout

**Cons**

- Strictly one button only if camera focus is automatic or UI-driven without extra keys
- More UI and level design work (camera placement, minimap)

**Best if:** you want Papers Please / operator-desk tension with spatial awareness.

---

### Variant C — **Single Fixed Lens**

**Button:** Left Mouse — slash.

**Camera behavior:** **One** security camera for the whole run (or whole wave). Enemies walk through the static frame left-to-right / depth axis.

**Player skill:** Pure timing and pattern recognition.

**Pros**

- Simplest scope; fastest path from prototype to final
- Clear marketing hook: “one camera, one blade”

**Cons**

- Low variety until more waves/cameras are added as content
- Less “surveillance network” fantasy

**Best if:** you want a minimal vertical slice first, expand cameras later.

## Comparison

| | A Auto-Camera | B Multi-Feed | C Single Lens |
|---|:---:|:---:|:---:|
| One button in final | Yes | Yes* | Yes |
| Surveillance fantasy | Medium | High | Low |
| Implementation cost | Medium | High | Low |
| Prototype → final gap | Small | Large | Smallest |

\*Camera focus must not require extra buttons in final; prototype may use number keys temporarily.

## Recommended Path

1. **Approve Variant A or C** for first vertical slice (A if multi-cam arena is core; C if speed matters).
2. Keep current keyboard movement unchanged until camera scenes exist.
3. Next implementation milestone (after approval): fixed `Camera3D` nodes in arena + switch feed rendering; slash hit tests run in **active feed space**, not player body space.
4. Deprecate `player` body movement last — after slash and enemies work through feeds.

## Open Questions

1. Which variant is the design target — A, B, or C?
2. Should slash be **timing-only** (window opens/closes) or **aim-assisted** (forgiving hitbox on enemy in frame)?
3. Is the katana literally in the CCTV overlay (viewmodel on feed HUD) or invisible operator action (only slash VFX on feed)?

## Out of Scope (This Spec)

- Camera implementation code
- Removing WASD / retargeting input map
- New assets beyond existing arena and chasers
