# Katana Viewmodel Tuning

## Test first (no MCP required)

Run this from terminal:

```bash
/Applications/Summer.app/Contents/MacOS/Summer --headless --path . -s res://tools/katana_smoke_test.gd
```

Expected:

```
KatanaVisualLeft screen=(~430, ~1000) on_screen=true
KatanaVisualRight screen=(~1628, ~1000) on_screen=true
RESULT:PASS
```

Only tune constants after PASS.

## Dual wield layout

Tuned in Summer headless against 1920x1080 viewport.

| Hand | Idle local pos | Slash cut local pos |
|------|----------------|---------------------|
| Left | `(-0.58, -0.20, -0.50)` | `(-0.18, -0.34, -0.42)` → lower-right |
| Right | `(-0.38, -0.20, -0.50)` | `(-0.58, -0.34, -0.42)` → lower-left |

Mesh uses approved basis/origin; left hand mirrors mesh on X.

## Controls

| Input | Action |
|-------|--------|
| `Left Arrow` | Left katana slash |
| `Right Arrow` | Right katana slash |
