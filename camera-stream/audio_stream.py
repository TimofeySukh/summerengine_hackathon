#!/usr/bin/env python3
import argparse
import html
import http.server
import os
import signal
import socketserver
import subprocess
from urllib.parse import urlsplit


def wav_header(sample_rate: int, channels: int, bits_per_sample: int) -> bytes:
    byte_rate = sample_rate * channels * bits_per_sample // 8
    block_align = channels * bits_per_sample // 8
    data_size = 0xFFFFFFFF
    riff_size = 0xFFFFFFFF
    return (
        b"RIFF"
        + riff_size.to_bytes(4, "little", signed=False)
        + b"WAVEfmt "
        + (16).to_bytes(4, "little")
        + (1).to_bytes(2, "little")
        + channels.to_bytes(2, "little")
        + sample_rate.to_bytes(4, "little")
        + byte_rate.to_bytes(4, "little")
        + block_align.to_bytes(2, "little")
        + bits_per_sample.to_bytes(2, "little")
        + b"data"
        + data_size.to_bytes(4, "little", signed=False)
    )


def make_handler(args):
    class Handler(http.server.BaseHTTPRequestHandler):
        server_version = "ArduinoAudioStream/1.0"

        def do_GET(self) -> None:
            path = urlsplit(self.path).path
            if path in ("/", "/index.html"):
                self._serve_index()
            elif path == "/audio.wav":
                self._serve_audio()
            elif path == "/health":
                self._serve_health()
            elif path == "/favicon.ico":
                self.send_response(204)
                self.end_headers()
            else:
                self.send_error(404)

        def log_message(self, fmt: str, *values) -> None:
            print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), fmt % values), flush=True)

        def _serve_index(self) -> None:
            video_url = html.escape(args.video_url)
            body = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Arduino Camera</title>
  <style>
    :root {{ color-scheme: dark; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    body {{ margin: 0; min-height: 100vh; background: #101010; color: #f5f5f5; display: grid; grid-template-rows: auto 1fr; }}
    header {{ display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 16px; background: #1b1b1b; border-bottom: 1px solid #333; }}
    h1 {{ margin: 0; font-size: 17px; font-weight: 650; }}
    audio {{ width: min(360px, 48vw); height: 32px; }}
    main {{ display: grid; place-items: center; min-height: 0; padding: 10px; }}
    img {{ width: min(100%, 1280px); max-height: calc(100vh - 76px); object-fit: contain; background: #050505; }}
    @media (max-width: 700px) {{
      header {{ align-items: stretch; flex-direction: column; }}
      audio {{ width: 100%; }}
      img {{ max-height: calc(100vh - 118px); }}
    }}
  </style>
</head>
<body>
  <header>
    <h1>Arduino Camera</h1>
    <audio src="/audio.wav" controls autoplay></audio>
  </header>
  <main><img src="{video_url}" alt="Live camera stream"></main>
</body>
</html>
"""
            payload = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def _serve_health(self) -> None:
            payload = (
                f"ok=true\n"
                f"audio_device={args.audio_device}\n"
                f"sample_rate={args.sample_rate}\n"
                f"channels={args.channels}\n"
                f"video_url={args.video_url}\n"
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def _serve_audio(self) -> None:
            command = [
                "arecord",
                "-D",
                args.audio_device,
                "-f",
                "S16_LE",
                "-c",
                str(args.channels),
                "-r",
                str(args.sample_rate),
                "-t",
                "raw",
                "--buffer-time",
                str(args.buffer_time),
                "--period-time",
                str(args.period_time),
            ]

            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )

            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(wav_header(args.sample_rate, args.channels, 16))

            try:
                assert process.stdout is not None
                while True:
                    chunk = process.stdout.read(4096)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, TimeoutError):
                pass
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=1)
                    except subprocess.TimeoutExpired:
                        process.kill()

    return Handler


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve USB microphone audio and a combined camera page.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8081)
    parser.add_argument("--audio-device", default="hw:1,0")
    parser.add_argument("--sample-rate", type=int, default=48000)
    parser.add_argument("--channels", type=int, default=1)
    parser.add_argument("--buffer-time", type=int, default=100000)
    parser.add_argument("--period-time", type=int, default=20000)
    parser.add_argument("--video-url", default="http://100.75.255.41:8080/stream")
    args = parser.parse_args()

    server = ThreadedHTTPServer((args.host, args.port), make_handler(args))

    def shutdown(_signum, _frame) -> None:
        server.server_close()
        os._exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    print(f"Serving combined camera page on http://{args.host}:{args.port}/", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
