# Modulino Dashboard

Publishes the selected Modulino Buttons and farthest detected Modulino Movement sensor to Linux through `Arduino_RouterBridge`.

Build for this UNO Q:

```sh
arduino-cli compile -b arduino:zephyr:unoq --libraries /home/arduino/.arduino15/internal/Arduino_Modulino_0.7.0_e9ddcb4cddf945f5 --libraries /home/arduino/.arduino15/internal/Arduino_RouterBridge_0.4.3_456a4ab6b378b066 --libraries /home/arduino/.arduino15/internal/Arduino_RPClite_0.3.0_66fefd6c76c3d010 --libraries /home/arduino/.arduino15/internal/MsgPack_0.4.2_a0d4adc5044d022c --libraries /home/arduino/.arduino15/internal/DebugLog_0.8.4_c199e2cf6415ecc8 --libraries /home/arduino/.arduino15/internal/ArxContainer_0.7.0_007f0bb2a1cdefe3 --libraries /home/arduino/.arduino15/internal/ArxTypeTraits_0.3.2_d65e2aabfeed7838 --libraries /home/arduino/.arduino15/internal/Arduino_LSM6DSOX_1.1.2_287085db9b88b474 --libraries /home/arduino/.arduino15/internal/Arduino_HS300x_1.0.0_182fd7848a9f4724 --libraries /home/arduino/.arduino15/internal/Arduino_LPS22HB_1.0.2_7fe1d8dd8007ad8f --libraries /home/arduino/.arduino15/internal/Arduino_LTR381RGB_1.0.0_88e402623ebd3bc7 --libraries '/home/arduino/.arduino15/internal/STM32duino_VL53L4CD_1.0.5_7e2845a3c673dda2' --libraries '/home/arduino/.arduino15/internal/STM32duino_VL53L4ED_1.0.1_aec71b2071ab306b' /home/arduino/modulino_dashboard
```

Upload from a fixed build dir:

```sh
arduino-cli compile -b arduino:zephyr:unoq --build-path /tmp/modulino_dashboard_build --libraries /home/arduino/.arduino15/internal/Arduino_Modulino_0.7.0_e9ddcb4cddf945f5 --libraries /home/arduino/.arduino15/internal/Arduino_RouterBridge_0.4.3_456a4ab6b378b066 --libraries /home/arduino/.arduino15/internal/Arduino_RPClite_0.3.0_66fefd6c76c3d010 --libraries /home/arduino/.arduino15/internal/MsgPack_0.4.2_a0d4adc5044d022c --libraries /home/arduino/.arduino15/internal/DebugLog_0.8.4_c199e2cf6415ecc8 --libraries /home/arduino/.arduino15/internal/ArxContainer_0.7.0_007f0bb2a1cdefe3 --libraries /home/arduino/.arduino15/internal/ArxTypeTraits_0.3.2_d65e2aabfeed7838 --libraries /home/arduino/.arduino15/internal/Arduino_LSM6DSOX_1.1.2_287085db9b88b474 --libraries /home/arduino/.arduino15/internal/Arduino_HS300x_1.0.0_182fd7848a9f4724 --libraries /home/arduino/.arduino15/internal/Arduino_LPS22HB_1.0.2_7fe1d8dd8007ad8f --libraries /home/arduino/.arduino15/internal/Arduino_LTR381RGB_1.0.0_88e402623ebd3bc7 --libraries '/home/arduino/.arduino15/internal/STM32duino_VL53L4CD_1.0.5_7e2845a3c673dda2' --libraries '/home/arduino/.arduino15/internal/STM32duino_VL53L4ED_1.0.1_aec71b2071ab306b' /home/arduino/modulino_dashboard
/home/arduino/.arduino15/packages/arduino/tools/remoteocd/0.1.1/remoteocd upload --adb-path /home/arduino/.arduino15/packages/arduino/tools/adb/35.0.2/adb -s 2121197850 -f /home/arduino/.arduino15/packages/arduino/hardware/zephyr/0.56.0/variants/arduino_uno_q_stm32u585xx/flash_sketch.cfg --verbose /home/arduino/.arduino15/packages/arduino/hardware/zephyr/0.56.0/firmwares/zephyr-arduino_uno_q_stm32u585xx.elf /tmp/modulino_dashboard_build/modulino_dashboard.ino.elf-zsk.bin
```

On 2026-07-04, `arduino-cli upload -p 10.0.5.54 ...` hung because the network-port upload path passed the OpenOCD config file as `filename0`. Direct `remoteocd` with CPH14 serial `2121197850` uploaded correctly.

The sketch scans direct I2C and hub ports `0..7`. If multiple Movement modules are found through a Modulino Hub, it selects the highest numbered hub port as the farthest sensor.
