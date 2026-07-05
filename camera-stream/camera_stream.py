#!/usr/bin/env python3
import argparse
import contextlib
import html
import http.server
import os
import signal
import socketserver
import subprocess
import threading
import time
from dataclasses import dataclass


SOI = b"\xff\xd8"
EOI = b"\xff\xd9"


@dataclass
class CameraConfig:
    device: str
    width: int
    height: int
    fps: int


class FrameHub:
    def __init__(self) -> None:
        self.condition = threading.Condition()
        self.frame: bytes | None = None
        self.frame_id = 0
        self.last_error: str | None = None
        self.last_frame_at = 0.0

    def publish(self, frame: bytes) -> None:
        with self.condition:
            self.frame = frame
            self.frame_id += 1
            self.last_error = None
            self.last_frame_at = time.time()
            self.condition.notify_all()

    def set_error(self, message: str) -> None:
        with self.condition:
            self.last_error = message
            self.condition.notify_all()

    def wait_next(self, seen_id: int, timeout: float = 5.0) -> tuple[int, bytes | None]:
        deadline = time.time() + timeout
        with self.condition:
            while self.frame_id == seen_id:
                remaining = deadline - time.time()
                if remaining <= 0:
                    return self.frame_id, None
                self.condition.wait(remaining)
            return self.frame_id, self.frame


class CameraWorker(threading.Thread):
    def __init__(self, config: CameraConfig, hub: FrameHub) -> None:
        super().__init__(daemon=True)
        self.config = config
        self.hub = hub
        self.stop_event = threading.Event()
        self.process: subprocess.Popen[bytes] | None = None

    def stop(self) -> None:
        self.stop_event.set()
        if self.process and self.process.poll() is None:
            self.process.terminate()

    def run(self) -> None:
        while not self.stop_event.is_set():
            command = [
                "v4l2-ctl",
                "-d",
                self.config.device,
                f"--set-fmt-video=width={self.config.width},height={self.config.height},pixelformat=MJPG",
                f"--set-parm={self.config.fps}",
                "--stream-mmap=3",
                "--stream-to=-",
            ]
            try:
                self.process = subprocess.Popen(
                    command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                )
            except FileNotFoundError:
                self.hub.set_error("v4l2-ctl is not installed")
                return
            except Exception as exc:
                self.hub.set_error(f"failed to start camera capture: {exc}")
                time.sleep(2)
                continue

            try:
                self._read_frames()
            finally:
                if self.process and self.process.poll() is None:
                    self.process.terminate()
                    with contextlib.suppress(subprocess.TimeoutExpired):
                        self.process.wait(timeout=2)
                if self.process and self.process.poll() is None:
                    self.process.kill()

            if not self.stop_event.is_set():
                self.hub.set_error("camera capture stopped; retrying")
                time.sleep(5)

    def _read_frames(self) -> None:
        assert self.process is not None
        assert self.process.stdout is not None
        buffer = bytearray()

        while not self.stop_event.is_set():
            chunk = self.process.stdout.read(64 * 1024)
            if not chunk:
                break
            buffer.extend(chunk)

            while True:
                start = buffer.find(SOI)
                if start < 0:
                    if len(buffer) > 2:
                        del buffer[:-2]
                    break

                end = buffer.find(EOI, start + 2)
                if end < 0:
                    if start:
                        del buffer[:start]
                    break

                end += 2
                frame = bytes(buffer[start:end])
                del buffer[:end]
                if len(frame) > 1024:
                    self.hub.publish(frame)


def make_handler(hub: FrameHub, config: CameraConfig):
    class Handler(http.server.BaseHTTPRequestHandler):
        server_version = "ArduinoCameraStream/1.0"

        def do_GET(self) -> None:
            if self.path in ("/", "/index.html"):
                self._serve_index()
            elif self.path == "/stream.mjpg":
                self._serve_stream()
            elif self.path == "/snapshot.jpg":
                self._serve_snapshot()
            elif self.path == "/health":
                self._serve_health()
            elif self.path == "/favicon.ico":
                self.send_response(204)
                self.end_headers()
            else:
                self.send_error(404)

        def log_message(self, fmt: str, *args) -> None:
            print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), fmt % args), flush=True)

        def _serve_index(self) -> None:
            title = "Arduino Camera"
            body = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <style>
    :root {{ color-scheme: dark; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    body {{ margin: 0; min-height: 100vh; background: #111; color: #f4f4f4; display: grid; grid-template-rows: auto 1fr; }}
    header {{ display: flex; justify-content: space-between; gap: 16px; align-items: center; padding: 14px 18px; background: #1b1b1b; border-bottom: 1px solid #333; }}
    h1 {{ font-size: 18px; margin: 0; font-weight: 650; }}
    .meta {{ color: #bbb; font-size: 13px; overflow-wrap: anywhere; }}
    main {{ display: grid; place-items: center; padding: 12px; }}
    img {{ width: min(100%, 1280px); max-height: calc(100vh - 86px); object-fit: contain; background: #050505; }}
  </style>
</head>
<body>
  <header>
    <h1>{title}</h1>
    <div class="meta">{html.escape(config.device)} · {config.width}x{config.height}@{config.fps}</div>
  </header>
  <main><img src="/stream.mjpg" alt="Live camera stream"></main>
</body>
</html>
"""
            payload = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def _serve_snapshot(self) -> None:
            _, frame = hub.wait_next(0, timeout=5)
            if not frame:
                self.send_error(503, hub.last_error or "no camera frame available")
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(frame)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(frame)

        def _serve_health(self) -> None:
            age = time.time() - hub.last_frame_at if hub.last_frame_at else -1
            ok = hub.last_frame_at > 0 and age < 10 and not hub.last_error
            payload = (
                f"ok={str(ok).lower()}\n"
                f"device={config.device}\n"
                f"frame_id={hub.frame_id}\n"
                f"last_frame_age_seconds={age:.1f}\n"
                f"last_error={hub.last_error or ''}\n"
            ).encode("utf-8")
            self.send_response(200 if ok else 503)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def _serve_stream(self) -> None:
            self.send_response(200)
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()

            seen_id = 0
            while True:
                seen_id, frame = hub.wait_next(seen_id, timeout=10)
                if not frame:
                    continue
                try:
                    self.wfile.write(b"--frame\r\n")
                    self.wfile.write(b"Content-Type: image/jpeg\r\n")
                    self.wfile.write(f"Content-Length: {len(frame)}\r\n\r\n".encode("ascii"))
                    self.wfile.write(frame)
                    self.wfile.write(b"\r\n")
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError, TimeoutError):
                    break

    return Handler


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve a UVC MJPEG camera as a small web page.")
    parser.add_argument("--device", default="/dev/video2")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--fps", type=int, default=10)
    args = parser.parse_args()

    config = CameraConfig(args.device, args.width, args.height, args.fps)
    hub = FrameHub()
    worker = CameraWorker(config, hub)
    worker.start()

    server = ThreadedHTTPServer((args.host, args.port), make_handler(hub, config))

    def shutdown(_signum, _frame) -> None:
        worker.stop()
        server.server_close()
        os._exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    print(f"Serving camera page on http://{args.host}:{args.port}/ using {args.device}", flush=True)
    try:
        server.serve_forever()
    finally:
        worker.stop()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
