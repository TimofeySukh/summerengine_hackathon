# Heat Wave

Surveillance katana survival in a flat night-city arena inspired by cyberpunk Japan.

You do not run the streets. You sit at one monitor, **turn a single security camera**, and cut down chasers with a katana — **one slash button, no auto-aim**.

## Vision (Final)

- **View:** one rotatable CCTV feed over the arena.
- **Camera:** player manually pans/rotates that mount — no auto-tracking, no other feeds in v1.
- **Movement:** none — operator stays at the desk.
- **Combat:** slash only what you framed in the feed.
- **Voice (TBD):** mic **"move"** / **"stop"** for camera jog — M/N keys stand in for now.

## Current Build

- `SurveillanceMount` CCTV feed — mouse pan, M/N jog, LMB slash
- Static operator at arena center; chasers walk in and take contact damage
- Design spec: `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`

## Open Decision

Slash zone shape; real mic keyword spotting vs keyboard jog only.
