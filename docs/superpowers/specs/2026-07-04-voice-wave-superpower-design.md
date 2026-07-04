# Voice Wave Superpower Design

## Goal

When the player loudly says the word "WAVE" into the board microphone, the game fires a wave superpower that clears the current enemies. This must be actual word recognition, not a raw volume threshold.

## User Experience

- In Webcam control mode, the existing camera sidecar also listens to the board audio stream.
- Saying "WAVE" triggers one shockwave event in the running game.
- The shockwave kills all currently alive enemies in the arena.
- The command has a cooldown so one shouted word cannot fire multiple times.
- The first implementation can use existing enemy death VFX. Dedicated wave visuals and sound can be added after the trigger path is reliable.

## Recommended Approach

Use a small local wake-word model for the word "wave" inside `tools/camera-controller/`.

The sidecar already owns the board camera/audio process and already sends UDP messages to Godot through `GameBridge`. Extending that bridge keeps the feature local, avoids macOS key focus issues, and works naturally with Webcam mode.

## Components

### Wake Word Detector

Add a Python module under `tools/camera-controller/` that:

- reads PCM chunks from the board audio stream,
- resamples or windows audio into the model's expected input shape,
- runs a local wake-word model for "wave",
- emits a detection only when confidence crosses a threshold,
- applies a short cooldown after each detection.

The model should live under `tools/camera-controller/models/`, for example `wave_wakeword.onnx`. If a generated or trained model is used, include a short note in the camera-controller README explaining how it was produced.

### Game Bridge Message

Extend the UDP bridge with a new message:

```json
{"type":"voice_wave","confidence":0.91}
```

The existing `--game-bridge` launch path should enable this by default in Webcam mode. A flag such as `--no-voice-wave` should disable it for debugging.

### Godot Receiver

Extend `CameraInputBridge` to store a one-shot `voice_wave_requested` event. Player or RunDirector logic consumes that event once per frame and fires the superpower.

### Superpower Effect

The first gameplay implementation should be deliberately simple:

- find nodes in the `enemies` group,
- skip nodes that have `is_alive()` and return false,
- call their existing `damage()` method with a large outward force,
- let current enemy death handling emit defeat signals so the run stats stay correct.

This preserves the existing enemy lifecycle instead of deleting nodes directly.

## Cooldowns And False Positives

- Python wake-word cooldown: 1.5 to 2.0 seconds after a detection.
- Godot superpower cooldown: 3.0 to 5.0 seconds to protect gameplay even if the model double-fires.
- Detection should require confidence above a tuned threshold, initially around 0.7.
- The sidecar HUD/log should print `VOICE WAVE` with confidence when it fires.

## Error Handling

- If the audio stream is unavailable, pose/slash control should continue working.
- If the wake-word model is missing, the sidecar should print a clear warning and continue without voice wave.
- If Godot is not listening on UDP, the sidecar should continue running and log bridge send attempts as it does for other game bridge events.

## Testing

1. Unit-test the detector against a short recorded "wave" clip and a non-wave/noise clip.
2. Run `pose_stream.py --game-bridge` and confirm the log prints `VOICE WAVE` once per spoken command.
3. In Webcam mode, spawn enemies, say "WAVE", and confirm all alive enemies die through their normal `damage()` path.
4. Say unrelated words and confirm the superpower does not fire.
5. Repeat "WAVE" rapidly and confirm cooldown prevents repeated clears.

## Scope Boundaries

Included in the first implementation:

- local wake-word inference,
- UDP bridge event,
- Godot event consumption,
- enemy clear effect,
- basic logging and cooldown.

Deferred:

- custom shockwave mesh/VFX,
- special audio/music ducking,
- UI charge meter,
- multi-word command grammar,
- cloud speech recognition.
