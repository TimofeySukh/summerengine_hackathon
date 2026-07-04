# Heat Wave — Project Documentation

> Living doc. Update after every project change.

## Overview

Surveillance katana survival in a flat night-city arena. **Final game:** one rotatable CCTV feed, manual pan, one slash button, no auto-aim. The operator body does not move.

**Playable now:** fixed surveillance mount overlooking the arena; mouse pans, LMB slashes, M/N jog the camera forward/stop (voice stand-in).

- **Engine:** Summer Engine (Godot 4.6)
- **Main scene:** `main.tscn`
- **Design brief:** `.summer/GameSoul.md`
- **Surveillance design spec (draft):** `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`
- **Agent rules:** `.summer/AGENTS.md`

## Design Direction (Major Pivot — 2026-07-04)

| Phase | View | Camera control | Combat |
|-------|------|----------------|--------|
| **Shipped slice** | Single CCTV feed (`SurveillanceMount`) | Mouse pan + M/N jog forward/stop | LMB slash |
| **Removed** | FPS body camera | WASD, jump | — |

Full spec: `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`

## Asset Policy

Do not create assets from scratch (placeholder boxes, procedural meshes, etc.). Always search for ready-made assets first — free libraries, CC0 packs, Summer templates. Generate or model custom assets only if nothing suitable exists and the user asks for it. See `.summer/AGENTS.md`.

## Controls

| Input | Action |
|-------|--------|
| **Mouse** | Pan / rotate surveillance camera |
| **Left mouse** | Katana slash (camera ray, no auto-aim) |
| **M** | Jog camera forward along pan arc *(voice "move" stand-in)* |
| **N** | Stop camera jog *(voice "stop" stand-in)* |
| Esc | Pause |

No WASD body movement. No auto-aim or auto camera tracking.

## Current State

### Operator / camera

- Static operator at arena center (`player/player.gd` — no locomotion)
- Single rotatable CCTV mount (`SurveillanceMount`, `player/camera_controller.gd`)
- Feed camera with katana viewmodel and slash ray (`FeedCamera`, `player/katana/`)
- Voice jog bridge: `player/voice_jog_listener.gd` (M/N now; mic keywords later)
- CC BY 3.0 katana model; procedural straight thrust trail on stab (`player/katana/katana_visual.gd`)
- Slash hits via camera ray + tight shape query — no magnet hitboxes

### Enemies

- **Humanoid chaser:** `enemies/humanoid_chaser.tscn` walks directly toward the player, damages on contact, and dies from katana hits
- `enemies/enemy_spawner.gd` keeps pressure on the player by spawning chasers around the arena
- Enemy death flashes red, collapses the body, and spawns the existing smoke puff VFX

### Level

- Flat concrete arena with dark city blocks, neon panels, red/blue lights, fog, and lane-strip accents
- Main level composition is authored directly in `main.tscn`

### Disabled / Legacy (from TPS template)

- Coin economy and coin UI
- Weapon switch UI (hidden)
- Grenade launcher and shooting helpers still present in player code but not part of the core loop

## Key Files

| Path | Role |
|------|------|
| `main.tscn` | Playable level and enemy placement |
| `player/player.gd` | Operator health, slash, static body |
| `player/camera_controller.gd` | PTZ surveillance mount (pan + jog) |
| `player/voice_jog_listener.gd` | M/N jog bridge for future mic commands |
| `enemies/humanoid_chaser.gd` | Chaser movement, contact damage, and death VFX |
| `enemies/enemy_spawner.gd` | Timed enemy spawning around the player |

## Changelog

### 2026-07-04

- Created `docs/PROJECT.md` as the living project doc.
- Added agent workflow rules to `.summer/AGENTS.md` (English in repo, local commits, doc updates).
- Fixed inverted vertical mouse look by disabling `invert_mouse_y` on the player camera.
- Replaced placeholder katana boxes with CC0 low-poly model from Poly Pizza (CreativeTrio).
- Documented asset policy: prefer ready-made assets over creating placeholders.
- Swapped stubby katana for dook blocks model; reduced FPS scale and tuned materials for readability.
- Parented katana to the FPS camera so it stays visible in view.
- Moved katana to the camera pivot with a forward offset; added `player/katana/PREVIEW.jpg` for asset preview.
- Lowered and leveled the FPS katana viewmodel (blade horizontal, parented to camera at y=0.48).
- Fixed katana jitter: removed per-frame global sync feedback loop; katana is a normal child of `PlayerCamera`.
- Updated project docs to match the current night-city chaser slice.
- Added a free procedural katana slash arc and reused the existing smoke puff for chaser death VFX.
- Reworked the katana attack from a rotating swing into a straight forward stab with a linear thrust trail.
- **Design pivot:** documented surveillance-only final gameplay (manual camera rotate, one-button slash, no auto-aim). WASD prototype is temporary. Spec: `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`.
- **Design decision:** rejected auto-aim and auto camera tracking; mouse look in prototype maps to future camera pan.
- **Design decision:** v1 uses **one rotatable security camera** — no multi-post feed switching.
- **Proposed:** microphone **"move"** / **"stop"** — camera jogs forward along its pan path, then stops (slash stays on button).
- **Implemented surveillance slice:** removed WASD/jump locomotion; single `SurveillanceMount` CCTV feed; mouse pan, M/N jog, LMB slash from camera ray.
