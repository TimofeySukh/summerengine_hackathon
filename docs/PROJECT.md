# Heat Wave — Project Documentation

> Living doc. Update after every project change.

## Overview

First-person katana combat prototype in a stylized Japanese-inspired mountain grove. The player runs, jumps, looks around, and cuts down enemy bots with a katana.

- **Engine:** Summer Engine (Godot 4.6)
- **Main scene:** `main.tscn`
- **Design brief:** `.summer/GameSoul.md`
- **Agent rules:** `.summer/AGENTS.md`

## Controls

| Input | Action |
|-------|--------|
| WASD | Move |
| Mouse | Look |
| Left mouse | Katana attack |
| Space | Jump |
| Esc | Pause |

## Current State

### Player

- First-person camera at head height (`player/camera_controller.gd`)
- WASD movement, jump, mouse look (`player/player.gd`)
- Placeholder katana mesh on `MeleeAnchor` (`player/player.tscn`)
- Melee attack via `Attack` animation and `MeleeAttackArea` hit volume (`player/melee_attack_area.gd`)
- Character model hidden; katana visible in first person

### Enemies

- **Ground:** `beetle_bot` — chases player via navigation, damages on contact
- **Flying:** `bee_bot` — tracks player and shoots projectiles
- Spawned around the start area in `main.tscn` under `Foes`

### Level

- Mountain terrain with navmesh, trees, grass, water, jumping pads
- Destructible crates (`box/`)
- Background music: `level/music/mountain.mp3`

### Disabled / Legacy (from TPS template)

- Coin economy and coin UI
- Weapon switch UI (hidden)
- Grenade launcher and shooting helpers still present in player code but not part of the core loop

## Key Files

| Path | Role |
|------|------|
| `main.tscn` | Playable level and enemy placement |
| `player/player.gd` | Movement, attack, damage |
| `player/player.tscn` | Player scene, katana, melee hitbox |
| `player/camera_controller.gd` | First-person camera |
| `player/melee_attack_area.gd` | Melee damage detection |
| `enemies/beetle_bot.gd` | Ground enemy AI |
| `enemies/bee_bot.gd` | Flying enemy AI |

## Changelog

### 2026-07-04

- Created `docs/PROJECT.md` as the living project doc.
- Added agent workflow rules to `.summer/AGENTS.md` (English in repo, local commits, doc updates).
- Fixed inverted vertical mouse look by disabling `invert_mouse_y` on the player camera.
