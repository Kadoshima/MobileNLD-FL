# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Context-Uncertainty-Driven Adaptive BLE Advertising for Ultra-Low-Power Wearable HAR** is a research project implementing adaptive BLE advertising interval control based on HAR (Human Activity Recognition) uncertainty metrics for significant power reduction in wearable devices.

## Research Focus

### Current Research (2024-12-17 onwards)
**Title**: "Context-Uncertainty-Driven Adaptive BLE Advertising for Ultra-Low-Power Wearable HAR"
**Target**: IEICE Communications Express (ComEX) - 4 pages, submission target: 2025

### Key Innovation
- **Adaptive BLE Advertising**: Dynamic adjustment of advertising intervals (100-2000ms) based on HAR uncertainty
- **Composite Context Score**: Combined metric of classification uncertainty and temporal volatility
- **Power Optimization**: ≥40% reduction in average current consumption vs fixed 100ms intervals
- **Real-world Validation**: On-device implementation with actual power measurements using PPK2

## System Architecture

### Hardware Configuration
```
[nRF52 MCU] - Wearable Device
  ├─ 6-axis IMU sensor
  ├─ On-device HAR inference
  ├─ Uncertainty calculation
  └─ Adaptive BLE advertising

[Android Phone] - Receiver & Logger
  ├─ BLE packet reception
  ├─ Timestamp logging
  ├─ CSV export
  └─ Real-time monitoring
```

### Software Stack
- **MCU Firmware**: Zephyr RTOS / nRF SDK
- **HAR Model**: TensorFlow Lite Micro (2-class: Active/Idle)
- **Android App**: Kotlin, BLE Scanner, CSV Logger
- **Analysis**: Python, pandas, matplotlib

## Common Commands

### Environment Setup
```bash
# Python environment for ML training
pip install tensorflow scikit-learn pandas numpy matplotlib

# Arduino IDE setup for M5Stack
# Install: M5Core2 library, TensorFlow Lite Micro
```

### Data Preparation
```bash
# Download UCI HAR dataset
python scripts/download_uci_har.py

# Preprocess for 2-class (Active/Idle)
python scripts/prepare_binary_dataset.py

# Generate train/val/test splits
python scripts/split_dataset.py
```

### Model Training
```bash
# Train 2-class HAR model
python scripts/train_har_model.py

# Quantize for TFLite Micro
python scripts/quantize_model.py

# Convert to C header
xxd -i model.tflite > model_data.h
```

### Performance Analysis
```bash
# Parse PPK2 power measurements
python scripts/parse_ppk2_csv.py

# Analyze BLE packet logs from Android
python scripts/analyze_packet_logs.py

# Calculate power reduction metrics
python scripts/calculate_power_reduction.py

# Generate latency distribution (p50/p95)
python scripts/latency_analysis.py

# Comparative analysis (Fixed vs Adaptive)
python scripts/compare_strategies.py
```

## File Organization

```
MobileNLD-FL/              # Repository root
├── docs/
│   ├── 研究概要_BLE適応制御.md     # Research overview
│   ├── 実装計画.md                # Implementation plan
│   ├── 実験手順書.md              # Experiment procedures
│   ├── archive_NLD-FL/           # Archived NLD research
│   └── EdgeHARv0/               # Previous EdgeHAR project
├── firmware/                    # MCU firmware
│   ├── src/
│   │   ├── main.c              # Main application
│   │   ├── har_model.c         # HAR inference
│   │   ├── uncertainty.c       # Uncertainty calculation
│   │   └── ble_adaptive.c     # Adaptive BLE control
│   ├── include/
│   └── CMakeLists.txt
├── android/                     # Android logger app
│   └── BLELogger/
│       ├── app/src/main/
│       └── build.gradle
├── scripts/                     # Python analysis
│   ├── train_har_model.py
│   ├── parse_ppk2_csv.py
│   ├── analyze_packet_logs.py
│   └── generate_figures.py
├── models/
│   └── har_2class.tflite      # Quantized model
├── data/
│   ├── uci_har/               # UCI HAR dataset
│   ├── power_measurements/    # PPK2 CSV files
│   └── packet_logs/           # Android BLE logs
└── results/
    ├── figures/               # Generated plots
    └── analysis/              # Analysis results
```

## Development Guidelines

### Code Style
- **C (nRF52)**: Zephyr coding style, detailed comments
- **Kotlin (Android)**: Android style guide, MVVM pattern
- **Python**: PEP 8, type hints, docstrings

### Git Workflow
- Branch naming: `feature/description`, `fix/issue`
- Commit messages: Clear and descriptive
- Daily commits with progress updates

### Testing Protocol
1. Unit tests for each component
2. Integration tests for BLE communication
3. End-to-end system tests
4. Power consumption measurements
5. Accuracy validation

## Experiment Tracking

### Key Metrics (Priority Order)
1. **Average Current**: ≥40% reduction vs fixed 100ms (PRIMARY)
   - Measured with Nordic PPK2
   - Report mean, std, and energy/minute
2. **p95 Latency**: ≤300ms (BLE advertising-based)
   - Packet reception intervals from Android logs
3. **F1 Score**: Degradation ≤1.5 points
   - 2-class (Active/Idle) classification
4. **Packet Loss**: <1% under normal conditions

### Experiment Conditions
1. **Baseline**: Fixed intervals (100ms, 200ms, 500ms)
2. **Proposed**: Adaptive (100-2000ms based on uncertainty)
3. **Duration**: 20 minutes per condition
4. **Subjects**: 3-5 participants
5. **Activities**: Walking, sitting, standing, stairs

## Paper Writing Guidelines

### IEICE ComEX Format
- 4 pages maximum (strict limit)
- Monthly publication, continuous submission
- Expected acceptance rate: 40-60%

### Optimized Section Allocation
- Introduction: 0.5 pages (emphasize adaptive BLE, uncertainty-driven, power reduction)
- Related Work: 0.3 pages (BLE optimization, HAR uncertainty, adaptive systems)
- Proposed Method: 1.2 pages (uncertainty metrics, adaptation algorithm, implementation)
- Experiments: 1.5 pages (power measurements, latency analysis, comparison)
- Conclusion: 0.5 pages

### Key References
- BLE power optimization in wearables
- Uncertainty quantification in HAR
- Adaptive communication protocols
- Context-aware systems

## Timeline (6-Week Sprint)

### Week 1-2: Implementation
- nRF52 firmware development
- HAR model integration (TFLite Micro)
- Uncertainty calculation implementation
- Adaptive BLE control logic

### Week 3-4: Android App & Testing
- BLE scanner app development
- CSV logging functionality
- System integration testing
- Debug and optimization

### Week 5: Experiments
- Power measurements with PPK2
- 3-5 subjects × 4 conditions × 20 min
- Data collection and validation

### Week 6: Analysis & Writing
- Data analysis and visualization
- Statistical significance testing
- Paper draft (4 pages)
- Internal review and submission prep

## Success Criteria

### Technical Goals
- ✅ Adaptive BLE advertising implementation
- ✅ TFLite Micro model <20KB
- ✅ Real-time uncertainty calculation
- ✅ Power reduction ≥40% vs fixed 100ms

### Research Goals
- ✅ Novel uncertainty-driven adaptation
- ✅ Real-world power measurements
- ✅ Statistical validation
- ✅ Reproducible implementation

## Troubleshooting

### Common Issues
1. **BLE Advertising Conflicts**: Ensure proper interval timing
2. **PPK2 Measurement Drift**: Calibrate before each session
3. **Packet Loss**: Check Android scanner buffer size
4. **Uncertainty Calculation Overhead**: Optimize computation

## Resources

### Documentation
- [nRF52 SDK](https://developer.nordicsemi.com/)
- [Zephyr RTOS](https://zephyrproject.org/)
- [TensorFlow Lite Micro](https://www.tensorflow.org/lite/microcontrollers)
- [UCI HAR Dataset](https://archive.ics.uci.edu/ml/datasets/human+activity+recognition+using+smartphones)

### Tools
- nRF Connect SDK
- Android Studio
- Nordic PPK2
- Python 3.9+

---
*Project Status: Active Development*
*Last Updated: 2024-12-17*
*Target: IEICE ComEX (2025)*
*Focus: Adaptive BLE advertising for power reduction*