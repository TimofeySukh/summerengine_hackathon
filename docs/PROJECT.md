# Heat Wave — Project Documentation

> Living doc. Update after every project change.

## Overview

Surveillance katana survival in a flat night-city arena. **Design target:** CCTV feed (see spec). **Current build:** first-person movement restored — WASD, mouse look, LMB slash.

- **Engine:** Summer Engine (Godot 4.6)
- **Main scene:** `main.tscn`
- **Design brief:** `.summer/GameSoul.md`
- **Surveillance design spec (draft):** `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`
- **Agent rules:** `.summer/AGENTS.md`

## Design Direction (Major Pivot — 2026-07-04)

| Phase | View | Control |
|-------|------|---------|
| **Current build** | First-person | WASD, mouse look, jump, LMB slash |
| **Design target (not shipped)** | Single CCTV feed | Manual pan, voice jog — see spec |

## Controls

| Input | Action |
|-------|--------|
| WASD | Move |
| Mouse | Look |
| Left mouse | Katana slash |
| Space | Jump |
| Esc | Pause |

## Asset Policy

Do not create assets from scratch (placeholder boxes, procedural meshes, etc.). Always search for ready-made assets first — free libraries, CC0 packs, Summer templates. Generate or model custom assets only if nothing suitable exists and the user asks for it. See `.summer/AGENTS.md`.

## Current State

### Player

- First-person camera at head height (`player/camera_controller.gd`)
- WASD movement, jump, mouse look (`player/player.gd`)
- CC BY 3.0 katana on `PlayerCamera` viewmodel (`player/katana/`)
- Katana slash via camera ray + animation (`player/melee_attack_area.gd` legacy nodes remain)

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
| `player/player.gd` | Movement, attack, damage |
| `player/camera_controller.gd` | First-person camera |
| `player/player.tscn` | Player scene and katana mount |
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
- **Reverted surveillance slice** back to first-person WASD + mouse look per user request.
- Reworked katana attack from rotation swing to straight forward thrust with linear trail VFX.
- Moved the first-person katana viewmodel to the right side of the camera frame.
- Tuned the katana viewmodel back toward center after the far-right placement overshot.
- Nudged the katana viewmodel slightly left for a better right-side frame position.
