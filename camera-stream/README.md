# Camera Stream

Low-latency MJPEG web streamer for the attached USB camera.

The systemd user service runs `ustreamer`, which passes the camera's hardware MJPEG frames directly to HTTP clients without CPU re-encoding.

The service uses the stable V4L2 symlink `/dev/v4l/by-id/usb-Jieli_Technology_USB_Composite_Device-video-index0`. Do not pin it to `/dev/videoN`; the USB camera and Qualcomm codec nodes can reorder after reboot.

Run manually:

```sh
v4l2-ctl -d /dev/v4l/by-id/usb-Jieli_Technology_USB_Composite_Device-video-index0 --set-ctrl=auto_exposure=3,brightness=0,contrast=256,saturation=256,gamma=20,gain=4,sharpness=128,backlight_compensation=0,power_line_frequency=1
ustreamer --device /dev/v4l/by-id/usb-Jieli_Technology_USB_Composite_Device-video-index0 --host 0.0.0.0 --port 8080 --resolution 480x320 --format MJPEG --desired-fps 25 --encoder HW --buffers 2 --workers 1 --tcp-nodelay --drop-same-frames 0 --server-timeout 5 --static /home/arduino/camera-stream/static
```

API endpoints from a machine in the same tailnet:

```text
http://100.75.255.41:8080/stream
http://100.75.255.41:8080/state
http://100.75.255.41:8081/audio.wav
```

If the viewing machine is on the same LAN/Wi-Fi, prefer the direct LAN URL to avoid Tailscale relay jitter:

```text
http://10.0.5.54:8080/
```

Useful endpoints:

- `http://100.75.255.41:8080/` - browser page with video.
- `http://100.75.255.41:8080/stream` - raw multipart MJPEG stream for laptop-side OpenCV/ffmpeg processing.
- `http://100.75.255.41:8080/state` - JSON status including source resolution and captured FPS.
- `http://100.75.255.41:8081/audio.wav` - live WAV/PCM audio from the camera microphone, served by `camera-audio.service`.
- `/snapshot` - latest JPEG frame.

Example laptop-side OpenCV input:

```python
import cv2

cap = cv2.VideoCapture("http://100.75.255.41:8080/stream")
while True:
    ok, frame = cap.read()
    if not ok:
        break
    # Run local CV here.
```

The attached `DELTACO W` USB camera advertises 30 fps, but local V4L2 tests on 2026-07-04 measured about 21.4 fps at supported MJPEG resolutions. The active service uses 480x320 at requested 25 fps to avoid saturating the same Tailscale path used by SSH. Requested 20 fps caused this camera/driver to capture only about 10 fps.

The service keeps auto exposure enabled. A previous manual exposure test made the image too dark and did not improve FPS.

Audio is streamed as mono PCM at 16 kHz from ALSA device `hw:CARD=Device,DEV=0`. The simple audio server opens the microphone per `/audio.wav` client, so use one audio listener at a time unless it is replaced with a mixer/broadcast process.

The web page uses a single `/stream` MJPEG connection. Snapshot polling was tested and made relay jitter worse by creating multiple concurrent HTTP connections.
