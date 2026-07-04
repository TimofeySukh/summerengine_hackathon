# Agent Rules — Heat Wave

## Language

- **Chat with the user:** any language.
- **Everything else:** English only — code, comments, commit messages, docs, in-game UI text, and new scene or asset names.

## Workflow

1. Read `docs/PROJECT.md` before changing the project.
2. After every change, update `docs/PROJECT.md` (what changed and current project state).
3. Commit locally after each logical change. **Do not push** unless the user asks.
4. Use one commit per task. Commit messages in English, present tense (e.g. `Add katana hit ray`).

## Assets

- **Do not create assets yourself** — no placeholder meshes, primitive shapes, or hand-made stand-ins when a real asset is needed.
- **Always search for ready-made assets first** — Poly Pizza, OpenGameArt, itch.io, Sketchfab, Summer asset library, CC0 packs, etc.
- Prefer **GLB/GLTF** for 3D models. Check license before import; record source in a `CREDITS.md` next to the asset.
- Use **generation or custom modeling only as a last resort** when no suitable free asset exists and the user explicitly asks for it.

## Project

First-person katana combat slice. Design brief: `.summer/GameSoul.md`. Main scene: `main.tscn`.
