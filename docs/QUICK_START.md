# Quick Start Guide

## 🚀 30-Second Overview

**What**: Adaptive BLE advertising based on HAR uncertainty to save power  
**Why**: 40%+ power reduction with minimal accuracy loss  
**How**: nRF52 MCU + Android app + Power measurements

## 📦 What You Need

### Hardware
- [ ] nRF52840 DK (or nRF52832)
- [ ] 6-axis IMU (LSM6DS3 or MPU-6050)
- [ ] Nordic PPK2 (for power measurement)
- [ ] Android phone (BLE 5.0 capable)
- [ ] USB cables, jumper wires

### Software
- [ ] nRF Connect SDK
- [ ] Python 3.9+
- [ ] Android Studio
- [ ] Git

## ⚡ Fastest Path to Demo

### 1. Clone & Setup (5 min)
```bash
git clone https://github.com/yourusername/MobileNLD-FL.git
cd MobileNLD-FL
pip install -r requirements.txt
```

### 2. Flash Firmware (10 min)
```bash
# Connect nRF52 DK via USB
cd firmware
./flash_prebuilt.sh  # Uses pre-compiled hex
```

### 3. Install Android App (5 min)
```bash
# Enable USB debugging on Android
cd android
./install_apk.sh  # Installs pre-built APK
```

### 4. Run Demo (10 min)
1. Power on nRF52 with IMU connected
2. Open Android app → Start Scanning
3. Move around (walk, sit, stand)
4. Observe adaptive intervals in real-time
5. Export CSV for analysis

## 🔧 Development Setup

### Building Firmware from Source
```bash
cd firmware
west build -b nrf52840dk_nrf52840
west flash
```

### Training Custom Model
```bash
python scripts/train_har_model.py --classes 2 --epochs 50
python scripts/quantize_model.py
```

### Power Measurement
```bash
# Connect PPK2 between power source and nRF52
# Use nRF Connect Power Profiler
python scripts/parse_ppk2_csv.py data/power_measurements/test.csv
```

## 📊 Verify It's Working

### Expected Behavior
- **LED1**: Blinks on BLE advertising (rate varies)
- **LED2**: On during active state, off during quiet
- **UART**: Outputs debug info at 115200 baud
- **Android**: Shows received packets with timestamps

### Quick Checks
```bash
# Check UART output
screen /dev/ttyACM0 115200

# Sample output:
# [HAR] State: ACTIVE, Uncertainty: 0.82, Interval: 100ms
# [BLE] Advertising with 31 bytes
# [HAR] State: QUIET, Uncertainty: 0.15, Interval: 1500ms
```

## 🐛 Common Issues

### Issue: No BLE packets received
- Check Android location permissions
- Ensure BLE is enabled
- Verify firmware is running (check LEDs)

### Issue: High power consumption
- Verify IMU is in low-power mode
- Check UART isn't flooding output
- Ensure proper sleep modes enabled

### Issue: Model accuracy too low
- Retrain with more data
- Check IMU calibration
- Verify sensor mounting stability

## 📈 Next Steps

1. **Customize Parameters**: Edit `firmware/config.h`
2. **Collect Your Data**: Use `scripts/collect_training_data.py`
3. **Run Full Experiments**: Follow [実験手順書.md](実験手順書.md)
4. **Analyze Results**: Use provided Jupyter notebooks

## 📚 Learn More

- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) - Detailed project description
- [要件定義書.md](要件定義書.md) - Complete requirements
- [TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md) - Deep technical details

## 💬 Getting Help

- **Issues**: GitHub Issues for bugs/questions
- **Discussions**: GitHub Discussions for ideas
- **Email**: research-team@example.com

---
*Get from zero to demo in 30 minutes!*  
*Last Updated: 2024-12-17*