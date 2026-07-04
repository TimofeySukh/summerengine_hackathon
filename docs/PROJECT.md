# Heat Wave — Project Documentation

> Living doc. Update after every project change.

## Overview

Surveillance katana survival in a flat night-city arena. **Final game:** the player watches the arena only through security cameras and survives by timing katana slashes — ideally with **one action button**. No free movement in the shipping design.

**Current prototype** still uses WASD + mouse as temporary scaffolding (“play as if you’re on a camera”). That movement is **not** the final vision.

- **Engine:** Summer Engine (Godot 4.6)
- **Main scene:** `main.tscn`
- **Design brief:** `.summer/GameSoul.md`
- **Surveillance design spec (draft):** `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`
- **Agent rules:** `.summer/AGENTS.md`

## Design Direction (Major Pivot — 2026-07-04)

| Phase | View | Movement | Combat |
|-------|------|----------|--------|
| **Final target** | Fixed CCTV feeds | None | One button — katana slash |
| **Prototype now** | First-person (placeholder) | WASD + jump + mouse look | Left mouse slash |

Do **not** build the camera system until a control variant (A/B/C in the spec) is chosen. Do **not** polish FPS locomotion — it will be removed.

### Control variants (summary)

See full trade-offs in the design spec.

| Variant | Idea | One-button final? |
|---------|------|-------------------|
| **A — Auto-Camera Slash** *(recommended)* | System picks the feed; player only times the slash | Yes |
| **B — Multi-Feed Operator** | Several cameras; slash on focused feed (focus auto or UI in final) | Yes* |
| **C — Single Fixed Lens** | One static camera; enemies cross the frame | Yes |

\*Prototype may use number keys to switch feeds; strip before ship.

## Asset Policy

Do not create assets from scratch (placeholder boxes, procedural meshes, etc.). Always search for ready-made assets first — free libraries, CC0 packs, Summer templates. Generate or model custom assets only if nothing suitable exists and the user asks for it. See `.summer/AGENTS.md`.

## Controls

### Prototype (temporary — not final)

| Input | Action |
|-------|--------|
| WASD | Move *(placeholder; will be removed)* |
| Mouse | Look *(placeholder)* |
| Left mouse | Katana slash |
| Space | Jump *(placeholder)* |
| Esc | Pause |

### Final target

| Input | Action |
|-------|--------|
| **One button** (e.g. Space / LMB) | Katana slash on active camera feed |
| Everything else | No movement; camera selection automatic or UI-only per chosen variant |

## Current State

### Player

- First-person camera at head height (`player/camera_controller.gd`)
- WASD movement, jump, mouse look (`player/player.gd`)
- CC BY 3.0 low-poly katana model (`player/katana/katana.glb`, dook blocks katana via Poly Pizza)
- Katana viewmodel parented to `PlayerCamera` (local offset, no per-frame global sync).
- Procedural blue-white slash arc appears during fast katana swings (`player/katana/katana_visual.gd`)
- Melee attack via `Attack` animation and `MeleeAttackArea` hit volume (`player/melee_attack_area.gd`)
- Character model hidden; katana visible in first person

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
| `player/katana/katana.glb` | Katana 3D model (CC BY 3.0, dook via Poly Pizza) |
| `player/katana/katana_visual.tscn` | Katana scale, orientation, and material tuning for FPS |
| `player/player.tscn` | Player scene, katana mount, melee hitbox |
| `player/camera_controller.gd` | First-person camera |
| `player/melee_attack_area.gd` | Melee damage detection |
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
- **Design pivot:** documented surveillance-only final gameplay (one-button slash, no body movement). WASD prototype is temporary. Draft spec: `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`.
