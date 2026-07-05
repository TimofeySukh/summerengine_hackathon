# Tailnet Camera and Audio Hub

Arduino-class Linux board that exposes a low-latency camera and microphone feed over Tailscale for remote play, prototyping, and game control.

## Short Description

This project turns the board into a networked sensor node:

- USB camera stream over HTTP with low latency
- Live microphone audio as a WAV/PCM stream
- Optional vision state for motion and hand-candidate tracking
- Companion Modulino sketches for buttons, IMU, and joystick input

## What It Does

The board runs as a small server rather than a single-purpose sketch. A USB UVC camera is captured with `ustreamer` or a lightweight MJPEG pipeline and served to clients on the tailnet. The camera microphone is exposed as a live audio stream. A separate vision process can publish simple skeleton data, which is useful for game interaction or UI feedback.

The result is a compact remote sensor box that can sit next to a play area and send video, audio, and control signals to another machine.

## Why This Project Exists

This setup started as a practical way to play games with a remote camera view and microphone input. The goal was not just to stream video, but to keep latency low enough that the feed is still useful in real time.

The same device can also act as a controller hub:

- Modulino Buttons for direct inputs
- Modulino Movement for IMU data
- Joystick-to-mouse bridging for desktop control

## Hardware

- Arduino-class Linux board `CPH14`
- USB UVC camera
- USB microphone on the same camera device
- Tailscale networking
- Optional Modulino accessories

## Software Layout

- `camera-stream/camera_stream.py` - MJPEG camera server and browser page
- `camera-stream/audio_stream.py` - live audio server for the camera microphone
- `camera-stream/vision_server.py` - motion and hand-candidate skeleton prototype
- `camera-stream/static/index.html` - local viewer page
- `modulino_dashboard/modulino_dashboard.ino` - publishes buttons and IMU state
- `mouse_move/mouse_move.ino` - joystick to bridge-compatible mouse motion
- `mouse_move/mouse_move.py` - host-side mouse writer

## Core Behavior

- Uses the stable V4L2 symlink for the camera device, not `/dev/videoN`
- Keeps auto exposure enabled for usable image brightness
- Serves a single MJPEG stream for the browser page to avoid extra relay load
- Prefers direct LAN access when available to reduce Tailscale relay jitter
- Streams microphone audio as mono PCM at 16 kHz

## Useful Endpoints

- `http://100.75.255.41:8080/` - camera page
- `http://100.75.255.41:8080/stream` - raw MJPEG stream
- `http://100.75.255.41:8080/state` - camera state JSON
- `http://100.75.255.41:8081/audio.wav` - live audio
- `http://100.75.255.41:8090/` - optional vision UI

## Setup Notes

1. Install the Python and system dependencies used by the camera and audio services.
2. Start the user services for camera and audio streaming.
3. Open the browser page from another machine on the tailnet.
4. If the viewer is on the same Wi-Fi network, use the direct LAN address instead of the relay path.

## Build Notes

The Arduino sketches are small companion pieces, not the core of the camera server:

- `modulino_dashboard` reads buttons and movement sensors and publishes JSON over Arduino RouterBridge
- `mouse_move` converts joystick motion into host mouse events

## Good Project Hub Angle

This is best presented as a remote camera-and-audio hub for games rather than a generic webcam project. The distinctive part is the combination of:

- low-latency camera streaming
- live microphone transport
- tailnet access
- optional physical controller input

That makes it easy to describe as an Arduino-powered network sensor node for interactive play.
