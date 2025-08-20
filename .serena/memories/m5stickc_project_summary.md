# M5StickC Plus2 BLE Adaptive Advertising Project

## Current Setup (2024-12-17)
- **Hardware**: M5StickC Plus2 × 3台 (ESP32-PICO-V3-02)
- **Phones**: iPhone 13/15, Galaxy S9
- **No PPK2**: Using AXP192 internal power measurement

## Project Pivot
- Original: nRF52 + PPK2 → Current: M5StickC Plus2 + AXP192
- Power target: 40% → 30% reduction (realistic for ESP32)
- Timeline: 6 weeks → 3 weeks proof-of-concept

## Key Files
- Firmware: `firmware/m5stick/ble_fixed_100ms/ble_fixed_100ms.ino`
- Setup guide: `docs/手順書_M5StickC_Plus2_環境構築.md`
- Main config: `CLAUDE.md` (updated for M5StickC)

## Implementation Status
✅ Completed:
- Arduino environment setup
- Python environment (TensorFlow, pandas)
- UCI HAR dataset download scripts
- BLE fixed 100ms advertising code
- Documentation cleanup

🔄 In Progress:
- IMU data collection (MPU6886)

⏳ Pending:
- AXP192 power measurement
- Adaptive BLE control (3-state)
- Experiments & analysis