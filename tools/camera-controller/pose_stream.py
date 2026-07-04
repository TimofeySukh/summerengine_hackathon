#!/usr/bin/env python3
"""MediaPipe Pose over MJPEG stream from the board camera API."""

from __future__ import annotations

import argparse
import json
import time
import urllib.request
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from audio_player import BoardAudioPlayer
from key_controller import ArrowKeyController
from mjpeg_reader import MjpegStreamReader
from slash_detector import SlashDetector, draw_slash_overlay, draw_wrist_markers
from game_bridge import GameBridge
from hand_tracker import compute_hand_frame
from hand_calibration import (
    CalibratorPhase,
    DEFAULT_CALIBRATION_PATH,
    HandCalibrator,
    HandCalibration,
    load_calibration,
)
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python.vision import drawing_styles, drawing_utils
from mediapipe.tasks.python import vision

DEFAULT_STREAM = "http://cph14.tailcfa96c.ts.net:8080/stream"
DEFAULT_STATUS = "http://cph14.tailcfa96c.ts.net:8080/state"
DEFAULT_AUDIO = "http://cph14.tailcfa96c.ts.net:8081/audio.wav"
MODEL_DIR = Path(__file__).resolve().parent / "models"
MODEL_VARIANTS = {
    "lite": (
        "pose_landmarker_lite/float16/1/pose_landmarker_lite.task",
        MODEL_DIR / "pose_landmarker_lite.task",
    ),
    "full": (
        "pose_landmarker_full/float16/1/pose_landmarker_full.task",
        MODEL_DIR / "pose_landmarker_full.task",
    ),
    "heavy": (
        "pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task",
        MODEL_DIR / "pose_landmarker_heavy.task",
    ),
}


def ensure_model(variant: str) -> Path:
    remote_path, local_path = MODEL_VARIANTS[variant]
    if local_path.exists():
        return local_path

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    url = f"https://storage.googleapis.com/mediapipe-models/pose_landmarker/{remote_path}"
    print(f"Downloading pose model to {local_path} ...")
    urllib.request.urlretrieve(url, local_path)
    return local_path


def draw_pose(frame, landmarks) -> None:
    drawing_utils.draw_landmarks(
        frame,
        landmarks,
        vision.PoseLandmarksConnections.POSE_LANDMARKS,
        drawing_styles.get_default_pose_landmarks_style(),
    )


def make_waiting_frame(width: int, height: int, lines: list[str]) -> np.ndarray:
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    y = 36
    for line in lines:
        cv2.putText(
            frame,
            line,
            (16, y),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (220, 220, 220),
            1,
            cv2.LINE_AA,
        )
        y += 28
    return frame


def fetch_board_status(url: str) -> dict:
    try:
        with urllib.request.urlopen(url, timeout=2) as response:
            payload = json.loads(response.read().decode("utf-8"))
            return payload.get("result", {})
    except (OSError, json.JSONDecodeError):
        return {}


def add_hud(
    frame,
    *,
    fps: float,
    pose_fps: float,
    audio_ok: bool = False,
    keys_left: int = 0,
    keys_right: int = 0,
) -> None:
    cv2.putText(
        frame,
        f"stream {fps:.1f} fps | pose {pose_fps:.1f} fps | audio {'on' if audio_ok else 'off'}",
        (8, 20),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (240, 240, 240),
        1,
        cv2.LINE_AA,
    )
    cv2.putText(
        frame,
        f"slashes: left={keys_left} right={keys_right}",
        (8, 40),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.42,
        (200, 200, 200),
        1,
        cv2.LINE_AA,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run MediaPipe Pose on the board MJPEG camera stream.",
    )
    parser.add_argument("--stream", default=DEFAULT_STREAM)
    parser.add_argument("--status", default=DEFAULT_STATUS)
    parser.add_argument("--audio", default=DEFAULT_AUDIO, help="Board WAV audio stream URL")
    parser.add_argument("--no-audio", action="store_true", help="Disable microphone playback")
    parser.add_argument("--no-keys", action="store_true", help="Disable arrow-key emulation")
    parser.add_argument(
        "--game-bridge",
        action="store_true",
        help="Send slash/hand events to Heat Wave over UDP (port 9847)",
    )
    parser.add_argument("--game-host", default="127.0.0.1")
    parser.add_argument("--game-port", type=int, default=9847)
    parser.add_argument(
        "--also-keys",
        action="store_true",
        help="With --game-bridge, also press arrow keys locally",
    )
    parser.add_argument(
        "--key-cooldown",
        type=float,
        default=0.35,
        help="Seconds between arrow key presses per hand",
    )
    parser.add_argument("--model", type=Path, default=None)
    parser.add_argument("--complexity", choices=tuple(MODEL_VARIANTS), default="lite")
    parser.add_argument("--min-detection-confidence", type=float, default=0.5)
    parser.add_argument("--min-tracking-confidence", type=float, default=0.5)
    parser.add_argument("--no-display", action="store_true")
    parser.add_argument(
        "--no-skeleton",
        action="store_true",
        help="Hide pose skeleton (wrists and slash FX still shown)",
    )
    parser.add_argument("--reconnect-delay", type=float, default=0.5)
    parser.add_argument("--slash-min-speed", type=float, default=480.0, help="Peak wrist speed px/s")
    parser.add_argument(
        "--slash-min-travel-ratio",
        type=float,
        default=0.26,
        help="Min slash arc as fraction of frame height (default: 0.26 ~83px at 320p)",
    )
    parser.add_argument("--slash-cooldown", type=float, default=0.55)
    parser.add_argument(
        "--pose-every",
        type=int,
        default=1,
        help="Run pose every N stream frames (default: 1 for slash accuracy)",
    )
    parser.add_argument(
        "--pose-width",
        type=int,
        default=192,
        help="Pose inference width in px (default: 192)",
    )
    parser.add_argument(
        "--no-pose",
        action="store_true",
        help="Show raw stream only (debug stream fps)",
    )
    parser.add_argument(
        "--recalibrate",
        action="store_true",
        help="Force hand calibration (T-pose, then arms at rest)",
    )
    parser.add_argument(
        "--skip-calibration",
        action="store_true",
        help="Skip calibration UI (use saved file or defaults)",
    )
    return parser.parse_args()


def print_status(url: str) -> None:
    try:
        with urllib.request.urlopen(url, timeout=3) as response:
            body = response.read().decode("utf-8", errors="replace").strip()
            print(f"status: {body}")
    except OSError as exc:
        print(f"status unavailable ({url}): {exc}")


def create_landmarker(args: argparse.Namespace) -> vision.PoseLandmarker | None:
    if args.no_pose:
        return None

    if args.model is not None:
        model_path = args.model
        if not model_path.exists():
            raise FileNotFoundError(f"Model not found: {model_path}")
    else:
        model_path = ensure_model(args.complexity)

    options = vision.PoseLandmarkerOptions(
        base_options=mp_tasks.BaseOptions(model_asset_path=str(model_path)),
        running_mode=vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=args.min_detection_confidence,
        min_pose_presence_confidence=args.min_detection_confidence,
        min_tracking_confidence=args.min_tracking_confidence,
    )
    return vision.PoseLandmarker.create_from_options(options)


def detect_pose(
    landmarker: vision.PoseLandmarker,
    frame_bgr: np.ndarray,
    *,
    pose_width: int,
    started_at: float,
) -> object | None:
    h, w = frame_bgr.shape[:2]
    if w > pose_width:
        scale = pose_width / w
        small = cv2.resize(
            frame_bgr,
            (pose_width, max(1, int(h * scale))),
            interpolation=cv2.INTER_LINEAR,
        )
    else:
        small = frame_bgr

    rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    timestamp_ms = int((time.monotonic() - started_at) * 1000)
    result = landmarker.detect_for_video(mp_image, timestamp_ms)
    if not result.pose_landmarks:
        return None
    return result.pose_landmarks[0]


def encode_preview(frame_bgr: np.ndarray, *, width: int = 240, quality: int = 45) -> bytes | None:
    h, frame_w = frame_bgr.shape[:2]
    if frame_w <= 0:
        return None
    scale = width / frame_w
    small = cv2.resize(
        frame_bgr,
        (width, max(1, int(h * scale))),
        interpolation=cv2.INTER_LINEAR,
    )
    ok, buf = cv2.imencode(".jpg", small, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
    if not ok:
        return None
    return bytes(buf)


def main() -> int:
    args = parse_args()
    print_status(args.status)

    landmarker = create_landmarker(args)
    reader = MjpegStreamReader(args.stream, reconnect_delay=args.reconnect_delay)
    reader.start()
    slash_detector = SlashDetector(
        min_peak_speed_px_s=args.slash_min_speed,
        min_travel_ratio=args.slash_min_travel_ratio,
        cooldown_s=args.slash_cooldown,
    )
    use_keys = not args.no_keys and not (args.game_bridge and not args.also_keys)
    key_controller = None if not use_keys else ArrowKeyController(cooldown_s=args.key_cooldown)
    game_bridge = None
    if args.game_bridge:
        game_bridge = GameBridge(host=args.game_host, port=args.game_port)
        game_bridge.ping()
        print(f"Game bridge: UDP -> {args.game_host}:{args.game_port}")
    audio_player = None
    if not args.no_audio:
        audio_player = BoardAudioPlayer(args.audio)
        audio_player.start()
        print(f"Audio: {args.audio} (single client — close ffplay/other listeners first)")
    if key_controller is not None:
        print(f"Arrow keys: left hand -> Left, right hand -> Right ({key_controller.backend})")

    hand_calibration: HandCalibration | None = None
    calibrator = HandCalibrator(path=DEFAULT_CALIBRATION_PATH)
    if args.skip_calibration:
        hand_calibration = load_calibration(DEFAULT_CALIBRATION_PATH) or HandCalibration()
        calibrator.calibration = hand_calibration
        calibrator.phase = CalibratorPhase.SKIPPED
        print("Hand calibration skipped.")
    elif args.recalibrate:
        print("Hand calibration: T-pose, then arms at rest.")
    else:
        loaded = load_calibration(DEFAULT_CALIBRATION_PATH)
        if loaded is not None:
            hand_calibration = loaded
            calibrator.calibration = loaded
            calibrator.phase = CalibratorPhase.SKIPPED
            print(f"Loaded hand calibration from {DEFAULT_CALIBRATION_PATH.name}")
        else:
            print("No saved calibration — T-pose + rest setup on start.")

    window_name = "Katana Pose"
    preview_w, preview_h = 640, 480
    if not args.no_display:
        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(window_name, preview_w, preview_h)

    stream_fps = 0.0
    pose_fps = 0.0
    last_report = time.monotonic()
    stream_started = time.monotonic()
    frames_since_report = 0
    poses_since_report = 0
    last_status_check = 0.0
    board_status: dict = {}
    stream_frame_no = 0
    last_landmarks = None
    display_frame: np.ndarray | None = None

    print("Running. Keys: q or Esc = quit, c = recalibrate hands")
    try:
        while True:
            now = time.monotonic()
            if now - last_status_check >= 5.0:
                board_status = fetch_board_status(args.status)
                last_status_check = now

            got_new_frame, camera_frame = reader.read_latest()
            if camera_frame is not None:
                display_frame = camera_frame
                if got_new_frame:
                    stream_frame_no += 1
                    frames_since_report += 1
                    if game_bridge is not None and args.no_display and stream_frame_no % 3 == 0:
                        preview = encode_preview(display_frame)
                        if preview is not None:
                            game_bridge.send_preview(preview)

            if display_frame is None:
                if not args.no_display:
                    if reader.connected:
                        status_lines = [
                            "Katana Pose",
                            "Waiting for first frame...",
                            "Stream is open, camera may be warming up.",
                        ]
                    else:
                        status_lines = [
                            "Cannot open stream yet.",
                            reader.last_error or args.stream,
                            f"Retrying in ~{args.reconnect_delay:.0f}s",
                        ]
                    waiting = make_waiting_frame(preview_w, preview_h, status_lines)
                    cv2.imshow(window_name, waiting)
                    if (cv2.waitKey(30) & 0xFF) in (ord("q"), 27):
                        break
                else:
                    time.sleep(0.01)
                continue

            if (
                got_new_frame
                and landmarker is not None
                and stream_frame_no % max(1, args.pose_every) == 0
            ):
                last_landmarks = detect_pose(
                    landmarker,
                    display_frame,
                    pose_width=args.pose_width,
                    started_at=stream_started,
                )
                if last_landmarks is not None:
                    poses_since_report += 1
                    if not calibrator.blocks_tracking:
                        hand_frame = compute_hand_frame(last_landmarks)
                        if hand_frame is not None and hand_calibration is not None:
                            hand_frame = hand_calibration.apply(hand_frame)
                        if game_bridge is not None and hand_frame is not None:
                            game_bridge.send_hands(hand_frame)
                        slash_event = slash_detector.update(
                            last_landmarks,
                            frame_w=display_frame.shape[1],
                            frame_h=display_frame.shape[0],
                        )
                        if slash_event is not None:
                            if key_controller is not None:
                                key_controller.on_hand_slash(slash_event.hand)
                            if game_bridge is not None:
                                game_bridge.send_slash(slash_event.hand)
                                print(f"GAME slash {slash_event.hand} ({slash_event.direction})")

            if calibrator.blocks_tracking:
                calibrator.update(last_landmarks)
                if calibrator.calibration is not None and calibrator.ready:
                    hand_calibration = calibrator.calibration
                frame = display_frame.copy()
                if last_landmarks is not None and not args.no_skeleton:
                    draw_pose(frame, last_landmarks)
                    draw_wrist_markers(frame, last_landmarks)
                calibrator.draw_overlay(frame)
                if not args.no_display:
                    cv2.imshow(window_name, frame)
                    key = cv2.waitKey(1) & 0xFF
                    calibrator.handle_key(key)
                    if key in (ord("q"), 27):
                        break
                elif not got_new_frame:
                    time.sleep(0.001)
                continue

            if last_landmarks is not None or slash_detector.flashes:
                frame = display_frame.copy()
                if last_landmarks is not None:
                    if not args.no_skeleton:
                        draw_pose(frame, last_landmarks)
                    draw_wrist_markers(frame, last_landmarks)
                draw_slash_overlay(frame, slash_detector)
            else:
                frame = display_frame

            add_hud(
                frame,
                fps=stream_fps,
                pose_fps=pose_fps,
                audio_ok=audio_player.connected if audio_player is not None else False,
                keys_left=key_controller.total_left if key_controller else 0,
                keys_right=key_controller.total_right if key_controller else 0,
            )
            if game_bridge is not None:
                cv2.putText(
                    frame,
                    f"game UDP {args.game_host}:{args.game_port}",
                    (8, frame.shape[0] - 12),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.42,
                    (120, 255, 160),
                    1,
                    cv2.LINE_AA,
                )

            now = time.monotonic()
            if now - last_report >= 1.0:
                elapsed = now - last_report
                stream_fps = frames_since_report / elapsed
                pose_fps = poses_since_report / elapsed
                frames_since_report = 0
                poses_since_report = 0
                last_report = now

            if not args.no_display:
                cv2.imshow(window_name, frame)
                key = cv2.waitKey(1) & 0xFF
                if key in (ord("q"), 27):
                    break
                if key == ord("c"):
                    calibrator = HandCalibrator(path=DEFAULT_CALIBRATION_PATH)
                    calibrator.start()
                    hand_calibration = None
                    print("Recalibrating hands...")
            elif not got_new_frame:
                time.sleep(0.001)
    finally:
        reader.stop()
        if audio_player is not None:
            audio_player.stop()
        if game_bridge is not None:
            game_bridge.close()
        if landmarker is not None:
            landmarker.close()
        if not args.no_display:
            cv2.destroyAllWindows()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
