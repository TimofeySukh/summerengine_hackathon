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

```bash
python pose_stream.py
```

Defaults: stream `http://100.75.255.41:8080/stream`, status `/state`, audio `/audio.wav` on the same host.

Useful flags: `--no-display`, `--no-keys`, `--no-audio`, `--complexity lite|full|heavy`.

## Modules

| File | Role |
|------|------|
| `pose_stream.py` | Main loop: MJPEG → pose → HUD, slash FX, optional key emulation |
| `mjpeg_reader.py` | Persistent HTTP MJPEG capture |
| `torso_tracker.py` | Torso yaw estimate from shoulder/hip landmarks |
| `slash_detector.py` | Wrist-speed slash detection (left/right hand) |
| `key_controller.py` | Arrow-key emulation via pynput |
| `audio_player.py` | Board microphone WAV playback |

Not wired into Godot yet; runs as a sidecar process alongside Summer Engine.
