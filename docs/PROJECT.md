# Heat Wave — Project Documentation

> Living doc. Update after every project change.

## Overview

Surveillance katana survival in a flat night-city arena. **Design target:** CCTV feed (see spec). **Current build:** first-person movement restored — WASD, mouse look, LMB slash.

- **Engine:** Summer Engine (Godot 4.6)
- **Main scene:** `ui/main_menu.tscn` (Play loads `main.tscn`)
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
| Esc | Pause / resume (in-game) |

## Asset Policy

Do not create assets from scratch (placeholder boxes, procedural meshes, etc.). Always search for ready-made assets first — free libraries, CC0 packs, Summer templates. Generate or model custom assets only if nothing suitable exists and the user asks for it. See `.summer/AGENTS.md`.

## Music & Sound Licensing

The game currently uses the following tracks:
1. **Main Menu Music**: "Dansez" by Fasion (`dansez_menu.mp3`), sourced from the Epidemic Sound library.
   - **Copyright Status:** Copyrighted by Fasion / Epidemic Sound.
   - **License / Policy:** Used for non-commercial prototyping. Requires an Epidemic Sound subscription/license for public or commercial release.
2. **Gameplay Music**: Main menu theme (`battleblock_theater_menu.ogg`) from the **BattleBlock Theater OST** (composed by Patric Catani, Will Stamper, Analogik, etc.).
   - **Copyright Status:** Copyrighted by The Behemoth.
   - **License / Policy:** Used strictly for non-commercial prototyping and meme purposes. If the project progresses beyond a simple prototype/meme game, this soundtrack **must be replaced** with royalty-free or custom/original music to avoid copyright infringement.

## Current State

### Player

- First-person camera at head height (`player/camera_controller.gd`)
- WASD movement, jump, mouse look (`player/player.gd`)
- CC BY 3.0 katana on `PlayerCamera` viewmodel (`player/katana/`)
- Katana slash via camera ray + animation (`player/melee_attack_area.gd` legacy nodes remain)

### Enemies

- **Humanoid chaser:** `enemies/humanoid_chaser.tscn` uses squad orbit slots, separation, and role-based pressure instead of stacking on the player
- `game/run_director.gd` drives wave-based spawning, kill/time tracking, and best-run persistence
- `ui/survival_hud.tscn` shows wave, kills, time, intermission banners, and best run
- `enemies/enemy_spawner.gd` spawns enemies on wave director command
- Enemy death flashes red, collapses the body, and spawns the existing smoke puff VFX
- `tools/camera-controller/` runs the real camera sidecar against the Tailscale board API (`cph14.tailcfa96c.ts.net`)

### Level

- Flat concrete arena with dark city blocks, neon panels, red/blue lights, fog, and lane-strip accents
- Main level composition is authored directly in `main.tscn`

### Music

- Autoload [MusicManager](file:///Users/Tim/racegame/level/music/music_manager.gd) dynamically manages the game's soundtrack based on the active scene:
  - **Main Menu (`ui/main_menu.tscn`)**: Plays "Dansez" by Fasion (`dansez_menu.mp3`) at `-10.0 dB`.
  - **Gameplay (`levels/desert_arena.tscn`)**: Plays the BattleBlock Theater main menu theme (`battleblock_theater_menu.ogg`) at `-12.0 dB`.

### Menus

- **Main menu:** `ui/main_menu.tscn` — title screen with Play and Quit; visible cursor
- **Pause menu:** `ui/pause_menu.tscn` — instanced in `main.tscn`; Esc pauses the scene tree, shows cursor, Continue / Main Menu

### Disabled / Legacy (from TPS template)

- Coin economy and coin UI
- Weapon switch UI (hidden)
- Grenade launcher and shooting helpers still present in player code but not part of the core loop

## Key Files

| Path | Role |
|------|------|
| `ui/main_menu.tscn` | Title screen (Play → arena) |
| `ui/pause_menu.tscn` | In-game pause overlay (Esc) |
| `main.tscn` | Playable level and enemy placement |
| `player/player.gd` | Movement, attack, damage |
| `player/camera_controller.gd` | First-person camera |
| `player/player.tscn` | Player scene and katana mount |
| `enemies/humanoid_chaser.gd` | Chaser movement, contact damage, and death VFX |
| `enemies/enemy_spawner.gd` | Timed enemy spawning around the player |
| `tools/camera-controller/` | Real-camera pose/slash bridge; `--game-bridge` drives katanas in Webcam mode |

## Changelog

### 2026-07-04

- **Webcam control mode:** auto-starts pose_stream with the game; katanas follow wrist positions relative to skeleton center; slashes still trigger on fast hand swings.
- Added `tools/camera-controller/` — Python sidecar for board MJPEG camera, MediaPipe pose, torso yaw, and slash detection.
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
- Changed katana attack to epic diagonal slash with arc VFX and combined rotation/position sweep.
- Reworked diagonal slash to use tween-driven wind/slash/recover instead of euler keyframes.
- Fixed diagonal slash: hilt pivot arc plus screen-space diagonal path; trail follows blade.
- Slowed slash and reversed diagonal to upper-left → lower-right.
- Moved the first-person katana viewmodel to the right side of the camera frame.
- Tuned the katana viewmodel back toward center after the far-right placement overshot.
- Nudged the katana viewmodel slightly left for a better right-side frame position.
- Reworked katana slash into one continuous hilt-pivot arc (upper-left to lower-right); removed viewmodel position hops and attack movement impulse.
- Rebuilt katana slash as a kesagiri-style keyframed swing: hilt pivot, quaternion slerp, wind/strike/follow-through timing.
- Removed broken world-scale slash trail VFX; simplified viewmodel cut to a short diagonal pivot swing synced with camera hit at slash peak.
- Rebuilt katana slash as a single-axis tip arc: blade forward from hilt pivot, diagonal upper-left to lower-right rotation plane.
- Locked approved FPS katana viewmodel placement; restored diagonal wind-up slash arc on the tuned idle pose.
- Integrated the BattleBlock Theater main menu theme as a looping background track via the new `MusicManager` autoload singleton.
- Added a licensing warning in the project documentation noting that the soundtrack is copyrighted and must be replaced if the project goes beyond a meme game.
- Added main menu (`ui/main_menu.tscn`) and in-game pause menu (`ui/pause_menu.tscn`) with Esc toggle, cursor release, Continue, and return to main menu.
- Updated `enemies/enemy_spawner.gd` and `main.tscn` to spawn enemies in front of the player (within a field-of-view cone) once per second.
- Downloaded a 3D Toon Mummy model (`enemies/toon_mummy/ToonMummyOptimized.gltf`) from the PatrickRyanMS/SampleModels repository.
- Replaced the procedural capsule-based meshes in `enemies/humanoid_chaser.tscn` with the 3D Toon Mummy model scaled up to 4.5.
- Added death screen (`ui/death_screen.tscn`): pauses on player death, Restart respawns at arena start, Main Menu returns to title.
- Player no longer instant-respawns on death; katana kills heal 25% max HP (`kill_heal_percent` on Player).
- Reworked chaser AI: orbit slots around the player, local separation, striker/flanker/lurker roles, and one-at-a-time commit attacks.
- Added wave survival loop (`RunDirector`), neon HUD, death-screen run stats, and katana combat feel (shake, hit-stop, slash/kill audio).
- Fetched the real-camera sidecar and set its default board API host to the Tailscale MagicDNS name `cph14.tailcfa96c.ts.net`.
- Configured dynamic soundtrack switching: main menu plays "Dansez" by Fasion (`dansez_menu.mp3`) and gameplay plays the BattleBlock Theater theme (`battleblock_theater_menu.ogg`).
- Designed the voice-triggered WAVE superpower: local wake-word model in the camera sidecar, UDP bridge event, and enemy-clear effect. Spec: `docs/superpowers/specs/2026-07-04-voice-wave-superpower-design.md`.
