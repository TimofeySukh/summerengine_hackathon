#!/usr/bin/env python3
import argparse
import asyncio
import json
import math
import signal
import threading
import time
from dataclasses import dataclass, field

import cv2
import numpy as np
from aiohttp import web

cv2.setNumThreads(1)

INDEX_HTML = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Arduino Vision</title>
  <style>
    :root { color-scheme: dark; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; min-height: 100vh; background: #111; color: #eee; display: grid; grid-template-rows: auto 1fr; }
    header { display: flex; align-items: center; justify-content: space-between; gap: 14px; padding: 12px 16px; background: #1c1c1c; border-bottom: 1px solid #333; }
    h1 { margin: 0; font-size: 17px; }
    .status { font-size: 13px; color: #bbb; overflow-wrap: anywhere; }
    main { display: grid; place-items: center; padding: 12px; }
    canvas { width: min(100%, 960px); aspect-ratio: 4 / 3; background: #050505; border: 1px solid #333; }
  </style>
</head>
<body>
  <header>
    <h1>Arduino Vision</h1>
    <div id="status" class="status">connecting</div>
  </header>
  <main><canvas id="view" width="640" height="480"></canvas></main>
  <script>
    const canvas = document.getElementById("view");
    const ctx = canvas.getContext("2d");
    const statusEl = document.getElementById("status");
    let last = null;

    function sx(x) { return x * canvas.width; }
    function sy(y) { return y * canvas.height; }

    function drawPoint(p, color, radius = 5) {
      ctx.beginPath();
      ctx.arc(sx(p.x), sy(p.y), radius, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.fill();
    }

    function drawLine(a, b, color, width = 2) {
      ctx.beginPath();
      ctx.moveTo(sx(a.x), sy(a.y));
      ctx.lineTo(sx(b.x), sy(b.y));
      ctx.strokeStyle = color;
      ctx.lineWidth = width;
      ctx.stroke();
    }

    function render(msg) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = "#050505";
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.strokeStyle = "#333";
      ctx.lineWidth = 1;
      for (let x = 0; x <= canvas.width; x += canvas.width / 8) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke();
      }
      for (let y = 0; y <= canvas.height; y += canvas.height / 6) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke();
      }

      const contour = msg.contour || [];
      if (contour.length > 1) {
        ctx.beginPath();
        ctx.moveTo(sx(contour[0].x), sy(contour[0].y));
        for (const p of contour.slice(1)) ctx.lineTo(sx(p.x), sy(p.y));
        ctx.closePath();
        ctx.strokeStyle = "#4cc9f0";
        ctx.lineWidth = 2;
        ctx.stroke();
      }

      if (msg.box) {
        ctx.strokeStyle = "#fca311";
        ctx.lineWidth = 2;
        ctx.strokeRect(sx(msg.box.x), sy(msg.box.y), sx(msg.box.w), sy(msg.box.h));
      }

      const center = msg.landmarks?.palm_center;
      if (center) drawPoint(center, "#ffbe0b", 7);

      const tips = msg.landmarks?.fingertips || [];
      for (const p of tips) {
        if (center) drawLine(center, p, "#90be6d", 2);
        drawPoint(p, "#57cc99", 5);
      }

      statusEl.textContent = `${msg.label} conf=${msg.confidence.toFixed(2)} fps=${msg.fps.toFixed(1)} area=${msg.area_ratio.toFixed(3)} clients=${msg.clients}`;
    }

    async function poll() {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 350);
      try {
        const response = await fetch(`/state?ts=${Date.now()}`, {
          cache: "no-store",
          signal: controller.signal
        });
        clearTimeout(timer);
        if (response.ok) {
          last = await response.json();
          render(last);
        } else {
          statusEl.textContent = `state ${response.status}`;
        }
      } catch (error) {
        statusEl.textContent = "waiting for state";
      } finally {
        setTimeout(poll, 125);
      }
    }
    poll();
  </script>
</body>
</html>
"""


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


@dataclass
class VisionState:
    lock: threading.Lock = field(default_factory=threading.Lock)
    payload: dict = field(default_factory=dict)
    running: bool = True

    def update(self, payload: dict) -> None:
        with self.lock:
            self.payload = payload

    def snapshot(self) -> dict:
        with self.lock:
            return dict(self.payload)


class VisionWorker(threading.Thread):
    def __init__(self, args, state: VisionState) -> None:
        super().__init__(daemon=True)
        self.args = args
        self.state = state
        self.bg = cv2.createBackgroundSubtractorMOG2(history=90, varThreshold=28, detectShadows=False)
        self.last_detection: dict | None = None
        self.last_detection_at = 0.0

    def run(self) -> None:
        cap = cv2.VideoCapture(self.args.device, cv2.CAP_V4L2)
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*self.args.format))
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.args.width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.args.height)
        cap.set(cv2.CAP_PROP_FPS, self.args.fps)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        if not cap.isOpened():
            self.state.update(self.empty_payload("camera_error", "camera_open_failed"))
            return

        fps = 0.0
        last_processed_at = time.monotonic()
        frame_interval = 1.0 / max(1.0, float(self.args.process_fps))
        next_frame_at = time.monotonic()

        while self.state.running:
            now = time.monotonic()
            if now < next_frame_at:
                time.sleep(next_frame_at - now)
            next_frame_at = time.monotonic() + frame_interval

            ok, frame = cap.read()
            if not ok or frame is None:
                self.state.update(self.empty_payload("camera_error", "read_failed"))
                time.sleep(0.05)
                continue

            now = time.monotonic()
            elapsed = now - last_processed_at
            if elapsed > 0:
                instant_fps = 1.0 / elapsed
                fps = instant_fps if fps == 0.0 else (fps * 0.8 + instant_fps * 0.2)
            last_processed_at = now

            payload = self.analyze(frame, fps)
            self.state.update(payload)

        cap.release()

    def empty_payload(self, label: str, reason: str = "", fps: float = 0.0) -> dict:
        return self.empty_payload_static(label, reason, fps)

    @staticmethod
    def empty_payload_static(label: str, reason: str = "", fps: float = 0.0) -> dict:
        return {
            "ts": time.time(),
            "label": label,
            "reason": reason,
            "confidence": 0.0,
            "fps": fps,
            "area_ratio": 0.0,
            "box": None,
            "landmarks": {"palm_center": None, "fingertips": []},
            "contour": [],
            "clients": 0,
        }

    def analyze(self, frame, fps: float) -> dict:
        h, w = frame.shape[:2]
        small = cv2.resize(frame, (self.args.width, self.args.height))
        blur = cv2.GaussianBlur(small, (7, 7), 0)
        mask = self.bg.apply(blur)
        _, mask = cv2.threshold(mask, 180, 255, cv2.THRESH_BINARY)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8), iterations=1)
        mask = cv2.morphologyEx(mask, cv2.MORPH_DILATE, np.ones((5, 5), np.uint8), iterations=2)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            return self.held_or_empty(fps)

        contour = max(contours, key=cv2.contourArea)
        area = float(cv2.contourArea(contour))
        area_ratio = area / float(self.args.width * self.args.height)
        if area_ratio < self.args.min_area:
            payload = self.held_or_empty(fps)
            payload["area_ratio"] = area_ratio
            return payload

        x, y, bw, bh = cv2.boundingRect(contour)
        aspect = bw / max(1, bh)
        extent = area / max(1.0, float(bw * bh))
        confidence = clamp01((area_ratio / 0.08) * 0.55 + min(1.0, len(contour) / 80.0) * 0.25 + (1.0 - min(1.0, abs(aspect - 0.8))) * 0.20)
        label = "hand_candidate" if 0.25 <= aspect <= 2.2 and 0.18 <= extent <= 0.85 else "motion"

        moments = cv2.moments(contour)
        if moments["m00"]:
            cx = int(moments["m10"] / moments["m00"])
            cy = int(moments["m01"] / moments["m00"])
        else:
            cx, cy = x + bw // 2, y + bh // 2

        fingertips = self.find_fingertips(contour, (cx, cy), self.args.width, self.args.height)
        contour_points = self.simplify_contour(contour, self.args.width, self.args.height)

        payload = {
            "ts": time.time(),
            "label": label,
            "confidence": confidence,
            "fps": fps,
            "area_ratio": area_ratio,
            "box": {
                "x": x / self.args.width,
                "y": y / self.args.height,
                "w": bw / self.args.width,
                "h": bh / self.args.height,
            },
            "landmarks": {
                "palm_center": {"x": cx / self.args.width, "y": cy / self.args.height},
                "fingertips": fingertips,
            },
            "contour": contour_points,
            "clients": 0,
        }
        self.last_detection = payload
        self.last_detection_at = time.monotonic()
        return payload

    def held_or_empty(self, fps: float) -> dict:
        if self.last_detection and time.monotonic() - self.last_detection_at <= self.args.hold_seconds:
            payload = dict(self.last_detection)
            payload["ts"] = time.time()
            payload["fps"] = fps
            payload["held"] = True
            return payload
        return self.empty_payload("no_motion", fps=fps)

    def find_fingertips(self, contour, center, width: int, height: int) -> list[dict]:
        hull = cv2.convexHull(contour, returnPoints=True).reshape(-1, 2)
        if len(hull) == 0:
            return []
        cx, cy = center
        points = []
        min_dist = max(width, height) * 0.10
        for px, py in hull:
            dist = math.hypot(float(px - cx), float(py - cy))
            if dist < min_dist:
                continue
            points.append((dist, int(px), int(py)))
        points.sort(reverse=True)

        selected = []
        for _, px, py in points:
            if all(math.hypot(px - sx, py - sy) > max(width, height) * 0.09 for sx, sy in selected):
                selected.append((px, py))
            if len(selected) >= 5:
                break
        selected.sort(key=lambda p: p[0])
        return [{"x": px / width, "y": py / height} for px, py in selected]

    def simplify_contour(self, contour, width: int, height: int) -> list[dict]:
        epsilon = max(2.0, 0.01 * cv2.arcLength(contour, True))
        approx = cv2.approxPolyDP(contour, epsilon, True).reshape(-1, 2)
        if len(approx) > 48:
            step = max(1, len(approx) // 48)
            approx = approx[::step][:48]
        return [{"x": float(px) / width, "y": float(py) / height} for px, py in approx]


async def index(_request):
    return web.Response(text=INDEX_HTML, content_type="text/html")


async def state_handler(request):
    state: VisionState = request.app["vision_state"]
    return web.json_response(state.snapshot() or VisionWorker.empty_payload_static("starting"))


async def ws_handler(request):
    state: VisionState = request.app["vision_state"]
    clients = request.app["clients"]
    ws = web.WebSocketResponse(heartbeat=10)
    await ws.prepare(request)
    clients.add(ws)
    try:
        while not ws.closed:
            payload = state.snapshot() or VisionWorker.empty_payload_static("starting")
            payload["clients"] = len(clients)
            await ws.send_str(json.dumps(payload, separators=(",", ":")))
            await asyncio.sleep(request.app["interval"])
    finally:
        clients.discard(ws)
    return ws


async def on_shutdown(app):
    app["vision_state"].running = False
    for ws in set(app["clients"]):
        await ws.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Skeleton-only camera vision server.")
    parser.add_argument("--device", default="/dev/video2")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8090)
    parser.add_argument("--width", type=int, default=320)
    parser.add_argument("--height", type=int, default=240)
    parser.add_argument("--fps", type=int, default=25)
    parser.add_argument("--format", default="YUYV")
    parser.add_argument("--process-fps", type=float, default=10.0)
    parser.add_argument("--send-fps", type=float, default=15.0)
    parser.add_argument("--min-area", type=float, default=0.012)
    parser.add_argument("--hold-seconds", type=float, default=1.2)
    args = parser.parse_args()

    state = VisionState()
    app = web.Application()
    app["vision_state"] = state
    app["clients"] = set()
    app["interval"] = 1.0 / max(1.0, args.send_fps)
    app.router.add_get("/", index)
    app.router.add_get("/state", state_handler)
    app.router.add_get("/ws", ws_handler)
    app.on_shutdown.append(on_shutdown)

    worker = VisionWorker(args, state)
    worker.start()

    loop = asyncio.get_event_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, lambda: asyncio.create_task(app.shutdown()))

    web.run_app(app, host=args.host, port=args.port, print=lambda msg: print(msg, flush=True))
    state.running = False
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
