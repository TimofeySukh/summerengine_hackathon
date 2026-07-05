#!/usr/bin/env python3
import time

def mouse_report(buttons=0, x=0, y=0, scroll=0):
    with open('/dev/hidg1', 'rb+') as hid:
        hid.write(bytes([buttons, x & 0xff, y & 0xff, scroll & 0xff]))

def mouse_move(x, y, steps=10):
    for _ in range(steps):
        mouse_report(x=x // steps, y=y // steps)
        time.sleep(0.02)

def mouse_click(button=0x01):
    mouse_report(buttons=button)
    time.sleep(0.05)
    mouse_report(buttons=0)

def mouse_scroll(amount):
    mouse_report(scroll=amount)

if __name__ == '__main__':
    print('Moving mouse...')
    mouse_move(50, 0)
    mouse_move(0, 50)
    mouse_move(-50, 0)
    mouse_move(0, -50)
    print('Done!')