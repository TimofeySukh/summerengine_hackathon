# Camera controller (real webcam → game input)

Python bridge: reads an MJPEG stream from the board camera, runs MediaPipe Pose, tracks torso yaw and wrist slashes, and emits game input.

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

Defaults: stream `http://cph14.tailcfa96c.ts.net:8080/stream`, status `/state`, audio `/audio.wav` on the same host. The current Tailscale IPv4 fallback is `100.75.255.41`.

Useful flags: `--no-display`, `--no-keys`, `--no-motion-keys`, `--no-audio`, `--game-bridge`, `--also-keys`, `--motion-deadzone`, `--complexity lite|full|heavy`.

## Game bridge (UDP)

When `--game-bridge` is on, slash and torso-yaw events go to Godot autoload `CameraInputBridge` on `127.0.0.1:9847`:

| Message | Effect in game |
|---------|----------------|
| `{"type":"slash","hand":"left\|right"}` | Triggers left/right katana slash |
| `{"type":"yaw","deg":12.5}` | Rotates first-person view from torso |

With `--game-bridge`, local arrow-key emulation is off unless you pass `--also-keys`. Without `--game-bridge`, torso yaw can hold `Q` / `E` for camera rotation and wrist slashes tap the arrow keys.

## Modules

| File | Role |
|------|------|
| `pose_stream.py` | Main loop: MJPEG → pose → HUD, torso motion, slash FX, optional key emulation |
| `mjpeg_reader.py` | Persistent HTTP MJPEG capture |
| `torso_tracker.py` | Torso yaw estimate from shoulder/hip landmarks |
| `slash_detector.py` | Wrist-speed slash detection (left/right hand) |
| `key_controller.py` | Q/E camera motion and arrow-key slash emulation via pynput |
| `game_bridge.py` | UDP sender to Godot `CameraInputBridge` (port 9847) |
| `audio_player.py` | Board microphone WAV playback |
| `run_for_game.sh` | Venv + `pose_stream.py --game-bridge` one-liner |
