# Heat Wave — Project Documentation

> Living doc. Update after every project change.

## Overview

Surveillance katana survival in a flat night-city arena. **Final game:** security camera feeds only — player **manually rotates** the camera, **no auto-aim**, one slash button. No body movement in shipping design.

**Current prototype:** mouse look = future camera pan; WASD = temporary placeholder to remove later.

- **Engine:** Summer Engine (Godot 4.6)
- **Main scene:** `main.tscn`
- **Design brief:** `.summer/GameSoul.md`
- **Surveillance design spec (draft):** `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`
- **Agent rules:** `.summer/AGENTS.md`

## Design Direction (Major Pivot — 2026-07-04)

| Phase | View | Camera control | Combat |
|-------|------|----------------|--------|
| **Final target** | CCTV feed(s) | **Manual pan/rotate** — no auto-aim, no auto tracking | One button — katana slash |
| **Prototype now** | First-person (placeholder) | Mouse look *(maps to future camera rotate)* | Left mouse slash |
| **Prototype (remove later)** | — | WASD + jump = temp body movement | — |

Do **not** build the camera system until open questions in the spec are settled. Do **not** add auto-aim or auto camera switch. Do **not** polish FPS locomotion.

**Approved:** manual camera rotation + one slash button. **Rejected:** auto-aim, auto feed selection, threat-based camera tracking.

Full spec: `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`

## Asset Policy

Do not create assets from scratch (placeholder boxes, procedural meshes, etc.). Always search for ready-made assets first — free libraries, CC0 packs, Summer templates. Generate or model custom assets only if nothing suitable exists and the user asks for it. See `.summer/AGENTS.md`.

## Controls

### Prototype (temporary — not final)

| Input | Action |
|-------|--------|
| **Mouse** | Look *(placeholder for **camera pan/rotate**)* |
| **Left mouse** | Katana slash |
| WASD | Move *(placeholder — will be removed)* |
| Space | Jump *(placeholder — will be removed)* |
| Esc | Pause |

### Final target

| Input | Action |
|-------|--------|
| **Pan / rotate** | Manual camera turn on fixed mount (no auto-aim) |
| **One button** (LMB / Space) | Katana slash in framed view |
| Body movement | None |
| Auto camera / auto aim | **Not allowed** |

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
- **Design pivot:** documented surveillance-only final gameplay (manual camera rotate, one-button slash, no auto-aim). WASD prototype is temporary. Spec: `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`.
- **Design decision:** rejected auto-aim and auto camera tracking; mouse look in prototype maps to future camera pan.
