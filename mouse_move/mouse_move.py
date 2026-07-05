#!/usr/bin/env python3
import socket
import msgpack
import time

SOCKET_PATH = "/var/run/arduino-router.sock"
HID_MOUSE = "/dev/hidg1"

def mouse_report(buttons=0, x=0, y=0, scroll=0):
    with open(HID_MOUSE, 'rb+') as hid:
        hid.write(bytes([buttons, x & 0xff, y & 0xff, scroll & 0xff]))

def main():
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.connect(SOCKET_PATH)

            reg_packet = [0, 1, "$/register", ["modulino_keypress"]]
            client.sendall(msgpack.packb(reg_packet))
            time.sleep(0.1)

            unpacker = msgpack.Unpacker(raw=False)

            while True:
                data = client.recv(4096)
                if not data:
                    break

                unpacker.feed(data)

                for msg in unpacker:
                    if msg[0] == 2:  # Notification
                        method_name = msg[1]
                        args = msg[2]

                        if method_name == "modulino_keypress":
                            payload = args[0]

                            if payload.startswith("M:"):
                                parts = payload[2:].split(",")
                                if len(parts) == 3:
                                    x = int(parts[0])
                                    y = int(parts[1])
                                    btn = int(parts[2])

                                    # Only send report if there's movement or button activity
                                    if x != 0 or y != 0 or btn:
                                        mouse_report(buttons=btn, x=x, y=y)
                                    else:
                                        # Send empty report to release button
                                        mouse_report()

    except Exception as e:
        print(f"[ERROR] {e}", flush=True)

if __name__ == "__main__":
    main()