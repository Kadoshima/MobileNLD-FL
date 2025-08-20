# Context-Uncertainty-Driven Adaptive BLE Advertising for Ultra-Low-Power Wearable HAR

## Overview
Research project implementing adaptive BLE advertising interval control based on HAR (Human Activity Recognition) uncertainty metrics for power reduction in wearable devices.

**Current Implementation**: M5StickC Plus2 (ESP32-based) as proof-of-concept  
**Target**: IEICE Communications Express (ComEX) - 4 pages

## Key Innovation
- **Adaptive BLE Advertising**: Dynamic adjustment of advertising intervals (100-2000ms) based on HAR uncertainty
- **Non-connectable Mode (ADV_NONCONN_IND)**: Connectionless BLE broadcasts with HAR data embedded in advertising packets
- **Uncertainty-Driven Control**: Combined metric of classification uncertainty and temporal volatility
- **Power Optimization**: Target ≥30-40% reduction in average current consumption (ESP32 estimated value)
- **Real-world Validation**: On-device implementation with AXP192 power measurements (±5mA accuracy)

## System Architecture

### Hardware Configuration (Revised)
```
[M5StickC Plus2] × 3 units
  ├─ ESP32-PICO-V3-02 MCU
  ├─ MPU6886 6-axis IMU (内蔵)
  ├─ AXP192 Power Management IC
  └─ 135mAh Battery

[Smartphones]
  ├─ iPhone 13, 15
  └─ Galaxy S9
```

### Software Components
- **Firmware**: Arduino IDE / ESP-IDF
- **HAR Model**: TensorFlow Lite Micro (2-class: Active/Idle)
- **Mobile Apps**: nRF Connect (iOS/Android)
- **Analysis**: Python (pandas, matplotlib)

## Quick Start

### 1. Environment Setup
```bash
# Python environment
chmod +x scripts/setup/setup_python_env.sh
./scripts/setup/setup_python_env.sh

# Arduino IDE for M5StickC Plus2
# Follow: docs/手順書_M5StickC_Plus2_環境構築.md
```

### 2. Data Preparation
```bash
# Download UCI HAR dataset
python scripts/download_uci_har.py

# Convert to 2-class (Active/Idle)
python scripts/prepare_binary_dataset.py
```

### 3. Upload Firmware
1. Open `firmware/m5stick/ble_fixed_100ms/ble_fixed_100ms.ino`
2. Select Board: M5StickC Plus2
3. Upload to device

### 4. Start Logging
Use nRF Connect app on smartphone to:
1. Scan for "M5HAR_01"
2. Verify 100ms advertising interval
3. Log manufacturer data (0x5900)

## Experiment Protocol

### Phase 1: Feasibility Test (Day 1)
- [x] BLE advertising test (Fixed 100ms)
- [x] IMU data collection (50Hz)
- [x] Power measurement via AXP192
- [ ] Baseline comparison (100ms vs 2000ms)

### Phase 2: Adaptive Control (Day 2-3)
- [ ] Simple HAR implementation (threshold-based)
- [ ] 3-state BLE control (Quiet/Uncertain/Active)
- [ ] Integration testing

### Phase 3: Evaluation (Day 4-5)
- [ ] 3-device simultaneous measurement
- [ ] Fixed vs Adaptive comparison
- [ ] Statistical analysis

## Project Structure
```
MobileNLD-FL/
├── firmware/m5stick/       # M5StickC Plus2 firmware
├── scripts/                # Python scripts
├── data/                   # Experiment data (APPEND-ONLY)
├── docs/                   # Documentation & procedures
│   ├── 手順書_*.md        # Setup guides
│   └── governance.md      # Research rules
├── analysis/              # Jupyter notebooks
└── results/               # Analysis outputs
```

## Key Metrics
1. **Power Reduction**: ≥30% vs fixed 100ms (M5StickC/ESP32)
2. **p95 Latency**: ≤300ms
3. **F1 Score**: Degradation ≤1.5 points
4. **Packet Loss**: <5%

## Current Status
- **Hardware**: M5StickC Plus2 × 3 (Available)
- **Phase**: Implementation (Phase 1)
- **Target**: IEICE ComEX 2025

## Documentation
- [環境構築手順](docs/手順書_M5StickC_Plus2_環境構築.md)
- [実験ガバナンス](docs/governance.md)
- [Android BLEロガー](docs/手順書_Android_BLEロガー.md)

## License
Research use only. Copyright (c) 2024

---
*Last Updated: 2024-12-17*