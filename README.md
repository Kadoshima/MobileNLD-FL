# Context-Uncertainty-Driven Adaptive BLE Advertising for Ultra-Low-Power Wearable HAR

## 🎯 Research Project
**Adaptive BLE Communication for Energy-Efficient Human Activity Recognition**

This project implements adaptive BLE advertising interval control based on HAR uncertainty metrics to achieve significant power reduction in wearable devices while maintaining acceptable detection latency.

## 📊 System Architecture

```
[nRF52 MCU + IMU Sensor]
         ↓
    HAR Inference (2-class: Active/Idle)
         ↓
    Uncertainty Calculation
         ↓
    Adaptive BLE Advertising (100-2000ms)
         ↓
[Android Phone: BLE Scanner & Logger]
```

## 🚀 Key Features

- **Adaptive BLE Advertising**: Dynamic intervals (100-2000ms) based on HAR uncertainty
- **Composite Context Score**: Combined uncertainty and temporal volatility metrics
- **Power Optimization**: ≥40% reduction in average current vs fixed 100ms intervals
- **Real-world Validation**: On-device implementation with PPK2 power measurements
- **Low Latency**: p95 ≤300ms for activity detection

## 📁 Project Structure

```
MobileNLD-FL/                    # Repository root
├── firmware/                    # nRF52 MCU firmware
│   ├── src/                    # Source files
│   │   ├── main.c             # Main application
│   │   ├── har_model.c        # HAR inference
│   │   ├── uncertainty.c      # Uncertainty calculation
│   │   └── ble_adaptive.c     # Adaptive BLE control
│   └── include/                # Headers
├── android/                     # Android app
│   └── BLELogger/              # BLE scanner & CSV logger
├── scripts/                     # Python utilities
│   ├── train_har_model.py     # Model training
│   ├── parse_ppk2_csv.py      # Power analysis
│   └── analyze_packet_logs.py # Latency analysis
├── models/                      # TFLite models
│   └── har_2class.tflite      # Quantized model (<20KB)
├── data/                        # Experiment data
│   ├── uci_har/                # UCI HAR dataset
│   ├── power_measurements/     # PPK2 CSV files
│   └── packet_logs/            # Android BLE logs
├── results/                     # Analysis results
└── docs/                        # Documentation
```

## 🛠️ Setup Instructions

### Prerequisites

- nRF52840 DK (or nRF52832 DK)
- 6-axis IMU sensor (LSM6DS3/MPU-6050)
- Nordic Power Profiler Kit II (PPK2)
- Android phone (Android 10+, BLE 5.0)
- Python 3.9+
- TensorFlow 2.x

### Quick Start

1. **Clone Repository**
```bash
git clone https://github.com/yourusername/MobileNLD-FL.git
cd MobileNLD-FL
```

2. **Setup Python Environment**
```bash
pip install -r requirements.txt
```

3. **Download Dataset**
```bash
python scripts/download_uci_har.py
```

4. **Train HAR Model**
```bash
python scripts/train_har_model.py     # Train 2-class model
python scripts/quantize_model.py      # Quantize for TFLite Micro
xxd -i model.tflite > model_data.h    # Convert to C header
```

5. **Build Firmware**
```bash
cd firmware
cmake -B build
cmake --build build
nrfjprog --program build/app.hex --chiperase
```

6. **Install Android App**
```bash
cd android/BLELogger
./gradlew installDebug
```

## 📈 Performance Targets

| Metric | Target | Priority |
|--------|--------|----------|
| Average Current Reduction | ≥40% vs fixed 100ms | PRIMARY |
| p95 Latency | ≤300ms | HIGH |
| F1 Score Degradation | ≤1.5 points | MEDIUM |
| Packet Loss | <1% | LOW |
| Model Size | <20KB | ✅ Achieved |

## 🔬 Experiment Protocol

### Conditions
- **Baseline**: Fixed intervals (100ms, 200ms, 500ms)
- **Proposed**: Adaptive (100-2000ms based on uncertainty)
- **Duration**: 20 minutes per condition
- **Subjects**: 3-5 participants
- **Activities**: Walking, sitting, standing, stairs

See [実験手順書.md](docs/実験手順書.md) for detailed procedures.

## 📝 Timeline (6-Week Sprint)

- **Week 1-2**: Firmware implementation & HAR model integration
- **Week 3-4**: Android app development & system testing
- **Week 5**: Power measurements & experiments (PPK2)
- **Week 6**: Data analysis & paper writing
- **Target**: IEICE ComEX submission 2025

## 📚 Documentation

- [要件定義書](docs/要件定義書.md) - Requirements specification
- [実験手順書](docs/実験手順書.md) - Experiment procedures
- [AndroidロガーCSVスキーマ定義](docs/AndroidロガーCSVスキーマ定義.md) - Data schema
- [CLAUDE.md](CLAUDE.md) - AI assistant instructions

## 🤝 Contributing

This is an active research project. For collaboration inquiries, please contact the maintainer.

## 📄 License

This project is part of academic research. Please cite appropriately if using any part of this work.

## 🏆 Acknowledgments

- UCI Machine Learning Repository for the HAR dataset
- Nordic Semiconductor for nRF SDK and PPK2
- TensorFlow Lite Micro team for embedded ML tools

---
*Project Status: Active Development*  
*Last Updated: December 17, 2024*  
*Focus: Adaptive BLE advertising for power reduction*