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

Select **Webcam** on the main menu and press Play — a **Katana Pose** window opens automatically with the live camera feed and skeleton overlay.

```bash
./run_for_game.sh          # display ON (default)
./run_for_game.sh --headless  # no OpenCV window
```

**Standalone preview (arrow keys only, no game):**

```bash
python pose_stream.py
```

Defaults: stream `http://cph14.tailcfa96c.ts.net:8080/stream`, status `/state`, audio `/audio.wav` on the same host. The current Tailscale IPv4 fallback is `100.75.255.41`.

Useful flags: `--no-display`, `--no-keys`, `--no-motion-keys`, `--no-audio`, `--game-bridge`, `--also-keys`, `--no-voice-wave`, `--motion-deadzone`, `--complexity lite|full|heavy`.

Voice WAVE uses the local Vosk small English model (`vosk-model-small-en-us-0.15`, Apache 2.0). The model downloads on first `--game-bridge` run into `tools/camera-controller/models/` and is ignored by Git.

## Game bridge (UDP)

When `--game-bridge` is on, slash and torso-yaw events go to Godot autoload `CameraInputBridge` on `127.0.0.1:9847`:

| Message | Effect in game |
|---------|----------------|
| `{"type":"hands","lx","ly","rx","ry","deg"?}` | Katana positions follow wrists; optional torso yaw |
| `{"type":"slash","hand":"left\|right"}` | Triggers slash animation + hit |
| `{"type":"shockwave","level"?}` | Shockwave around player (mic loud sound in webcam mode) |
| `{"type":"voice_wave","confidence":0.91}` | Triggers the WAVE superpower once |

`run_for_game.sh` starts the game bridge with calibration skipped and audio triggers disabled, so Webcam mode immediately sends hand/slash packets without random mic-triggered abilities. With raw `pose_stream.py --game-bridge`, local arrow-key emulation is off unless you pass `--also-keys`. Loud mic bursts can trigger shockwave unless `--no-audio` is passed, and saying "WAVE" sends the voice-wave event unless `--no-voice-wave` is passed. Without `--game-bridge`, wrist slashes tap the arrow keys.

## Hand calibration

On game start (`--game-bridge`), a sweep calibration screen appears:

1. Stand facing the camera, press **SPACE**.
2. With **arms extended**, sweep **top to bottom along your sides** (~14 s).
3. For each wrist we record **top**, **left**, and **right** extremes; left wrist min X maps to the **left edge** of the in-game katana range, max X to the **right edge**.
4. Press **S** to skip and reuse `hand_calibration.json`, or **C** during play to recalibrate.

During gameplay, bounds **auto-expand** while your torso stays centered. If you move away from center, bounds reset to the last saved safe values after a **2 s buffer**, then resume accumulating.

Pass `--skip-calibration` to bypass the intro entirely.

## Modules

| File | Role |
|------|------|
| `pose_stream.py` | Main loop: MJPEG → pose → HUD, torso motion, slash FX, optional key emulation |
| `mjpeg_reader.py` | Persistent HTTP MJPEG capture |
| `hand_calibration.py` | Per-wrist sweep calibration + runtime auto-tune (2s body-move buffer) |
| `hand_calibration.json` | Saved wrist bounds (gitignored, local per machine) |
| `hand_tracker.py` | Torso center + wrist positions for katana mapping |
| `slash_detector.py` | Wrist-speed slash detection (left/right hand) |
| `key_controller.py` | Q/E camera motion and arrow-key slash emulation via pynput |
| `game_bridge.py` | UDP sender to Godot `CameraInputBridge` (port 9847) |
| `audio_player.py` | Board microphone WAV playback |
| `voice_wave_detector.py` | Offline Vosk recognition for spoken WAVE |
| `run_for_game.sh` | Venv + `pose_stream.py --game-bridge` one-liner |
