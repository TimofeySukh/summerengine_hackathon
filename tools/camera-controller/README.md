# Camera controller (real webcam → game input)

Python bridge: reads an MJPEG stream from the board camera, runs MediaPipe Pose, tracks torso yaw and wrist slashes, and can emit arrow-key input for the game.

## Setup

```bash
cd tools/camera-controller
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The pose model (`models/pose_landmarker_lite.task`) is bundled; other variants download on first use.

## Run

**For Heat Wave (webcam control mode):**

```bash
./run_for_game.sh
# or: python pose_stream.py --game-bridge
```

Select **Webcam** on the main menu, start this script, then press Play in the game.

**Standalone preview (arrow keys only, no game):**

```bash
python pose_stream.py
```

Defaults: stream `http://100.75.255.41:8080/stream`, status `/state`, audio `/audio.wav` on the same host.

Useful flags: `--no-display`, `--no-keys`, `--no-audio`, `--game-bridge`, `--complexity lite|full|heavy`.

## Game bridge (UDP)

When `--game-bridge` is on, slash and torso-yaw events go to Godot autoload `CameraInputBridge` on `127.0.0.1:9847`:

| Message | Effect in game |
|---------|----------------|
| `{"type":"slash","hand":"left\|right"}` | Triggers left/right katana slash |
| `{"type":"yaw","deg":12.5}` | Rotates first-person view from torso |

With `--game-bridge`, local arrow-key emulation is off unless you pass `--also-keys`.

## Modules

| File | Role |
|------|------|
| `pose_stream.py` | Main loop: MJPEG → pose → HUD, slash FX, optional key emulation |
| `mjpeg_reader.py` | Persistent HTTP MJPEG capture |
| `torso_tracker.py` | Torso yaw estimate from shoulder/hip landmarks |
| `slash_detector.py` | Wrist-speed slash detection (left/right hand) |
| `key_controller.py` | Arrow-key emulation via pynput |
| `game_bridge.py` | UDP sender to Godot `CameraInputBridge` (port 9847) |
| `run_for_game.sh` | Venv + `pose_stream.py --game-bridge` one-liner |
