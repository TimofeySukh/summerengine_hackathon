# Heat Wave

Surveillance katana survival in a flat night-city arena inspired by cyberpunk Japan.

You do not run the streets. You watch them through security cameras and cut down humanoid chasers with a katana — **one button, perfect timing**.

## Vision (Final)

- **View:** fixed CCTV feeds over the arena (surveillance fantasy).
- **Movement:** none — the operator stays at the desk.
- **Combat:** single slash action when a target is in the kill window on the active feed.
- **Pressure:** chasers spawn and cross camera coverage; misses cost health or breaches.

## Current Prototype (Temporary)

- Base: Summer `3d-third-person-controller` template, repurposed as a testbed.
- View: first-person camera — **placeholder** until real security cameras ship.
- Movement: WASD, mouse look, Space jump — **not final**; simulates “being on a feed” during development.
- Combat: left mouse katana slash (same action we will keep).
- Map: flat gray concrete arena with dark city blocks, neon panels, and fog.
- Enemies: humanoid chasers spawned over time; contact damage; die to katana hits.
- HUD: health bar upper-left.
- VFX: procedural slash arc on swing; smoke puff on enemy death.
- Design spec: `docs/superpowers/specs/2026-07-04-surveillance-camera-design.md`

## Open Decision

Pick control variant **A** (auto camera), **B** (multi-feed operator), or **C** (single fixed lens) before implementing cameras.
