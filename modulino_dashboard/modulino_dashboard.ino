// SPDX-License-Identifier: MPL-2.0
#include "Arduino_RouterBridge.h"
#include <Arduino_Modulino.h>

ModulinoHub hub;

ModulinoButtons directButtons;
ModulinoMovement directMovement;

ModulinoButtons* buttons = nullptr;
ModulinoMovement* movement = nullptr;

int buttonsPort = -2;
int movementPort = -2;
bool buttonsOk = false;
bool movementOk = false;

unsigned long lastPublishMs = 0;
const unsigned long PUBLISH_INTERVAL_MS = 40;

ModulinoButtons* tryButtonsOnPort(int port) {
  ModulinoButtons* candidate;
  if (port >= 0) {
    candidate = new ModulinoButtons(hub.port(port));
  } else {
    candidate = &directButtons;
  }
  return candidate->begin() ? candidate : nullptr;
}

ModulinoMovement* tryMovementOnPort(int port) {
  ModulinoMovement* candidate;
  if (port >= 0) {
    candidate = new ModulinoMovement(hub.port(port));
  } else {
    candidate = &directMovement;
  }
  return candidate->begin() ? candidate : nullptr;
}

void discoverModulinoInputs() {
  buttons = nullptr;
  movement = nullptr;
  buttonsPort = -2;
  movementPort = -2;

  ModulinoButtons* directBtn = tryButtonsOnPort(-1);
  if (directBtn != nullptr) {
    buttons = directBtn;
    buttonsPort = -1;
  }

  ModulinoMovement* directMov = tryMovementOnPort(-1);
  if (directMov != nullptr) {
    movement = directMov;
    movementPort = -1;
  }

  for (int port = 0; port < 8; port++) {
    ModulinoButtons* portButtons = tryButtonsOnPort(port);
    if (portButtons != nullptr) {
      buttons = portButtons;
      buttonsPort = port;
    }

    ModulinoMovement* portMovement = tryMovementOnPort(port);
    if (portMovement != nullptr) {
      movement = portMovement;
      movementPort = port;
    }
  }

  buttonsOk = buttons != nullptr;
  movementOk = movement != nullptr;
}

String sourceName(int port) {
  if (port >= 0) {
    return "hub:" + String(port);
  }
  if (port == -1) {
    return "direct";
  }
  return "missing";
}

void setup() {
  Bridge.begin();
  Modulino.begin();
  discoverModulinoInputs();
}

void loop() {
  unsigned long now = millis();
  if (now - lastPublishMs < PUBLISH_INTERVAL_MS) {
    delay(1);
    return;
  }
  lastPublishMs = now;

  bool a = false;
  bool b = false;
  bool c = false;
  if (buttonsOk) {
    buttons->update();
    a = buttons->isPressed(0) == HIGH;
    b = buttons->isPressed(1) == HIGH;
    c = buttons->isPressed(2) == HIGH;
    buttons->setLeds(a, b, c);
  }

  float ax = 0;
  float ay = 0;
  float az = 0;
  float gx = 0;
  float gy = 0;
  float gz = 0;
  bool movementFresh = false;
  if (movementOk) {
    movementFresh = movement->update() != 0;
    ax = movement->getX();
    ay = movement->getY();
    az = movement->getZ();
    gx = movement->getRoll();
    gy = movement->getPitch();
    gz = movement->getYaw();
  }

  String payload = "{";
  payload += "\"buttons\":{\"ok\":" + String(buttonsOk ? "true" : "false");
  payload += ",\"source\":\"" + sourceName(buttonsPort) + "\"";
  payload += ",\"a\":" + String(a ? "true" : "false");
  payload += ",\"b\":" + String(b ? "true" : "false");
  payload += ",\"c\":" + String(c ? "true" : "false") + "}";
  payload += ",\"gyro\":{\"ok\":" + String(movementOk ? "true" : "false");
  payload += ",\"fresh\":" + String(movementFresh ? "true" : "false");
  payload += ",\"source\":\"" + sourceName(movementPort) + "\"";
  payload += ",\"accel\":{\"x\":" + String(ax, 3) + ",\"y\":" + String(ay, 3) + ",\"z\":" + String(az, 3) + "}";
  payload += ",\"gyro\":{\"x\":" + String(gx, 1) + ",\"y\":" + String(gy, 1) + ",\"z\":" + String(gz, 1) + "}}";
  payload += ",\"uptime_ms\":" + String(now);
  payload += "}";

  Bridge.notify("modulino_state", payload.c_str());
}
