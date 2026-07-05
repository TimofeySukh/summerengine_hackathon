// SPDX-License-Identifier: MPL-2.0
#include "Arduino_RouterBridge.h"
#include <Arduino_Modulino.h>

ModulinoJoystick joystick;

unsigned long lastMoveTime = 0;
const unsigned long STEP_DELAY_MS = 30;
const float SPEED = 0.08; // Scale -128..127 down to -10..10 range

void setup() {
    Bridge.begin();
    Modulino.begin();
    joystick.begin();
    joystick.setDeadZone(26); // Built-in deadzone, ignore small drift
}

void loop() {
    unsigned long currentMillis = millis();

    if (currentMillis - lastMoveTime >= STEP_DELAY_MS) {
        lastMoveTime = currentMillis;

        joystick.update();

        int8_t x = joystick.getX();
        int8_t y = joystick.getY();
        bool pressed = (joystick.isPressed() == HIGH);

        int dx = (int)(x * SPEED);
        int dy = (int)(-y * SPEED); // Invert Y so up = up

        // Format: "M:X,Y,BUTTON"
        String payload = "M:" + String(dx) + "," + String(dy) + "," + String(pressed ? 1 : 0);
        Bridge.notify("modulino_keypress", payload.c_str());
    }
}