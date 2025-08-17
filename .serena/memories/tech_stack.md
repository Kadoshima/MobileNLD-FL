# Technology Stack

## Hardware
- **M5Stack Core2** (3 devices)
  - ESP32 dual-core 240MHz
  - 520KB SRAM, 16MB Flash
  - MPU6886 6-axis IMU
  - BLE 5.0 support
  - FreeRTOS

- **iPhone**
  - iOS 15+
  - Core Bluetooth
  - Core ML

## Software Stack

### M5Stack Firmware
- Arduino IDE 2.0+ / PlatformIO
- TensorFlow Lite Micro
- M5Core2 library
- FreeRTOS for task management
- BLE communication

### iPhone Application
- Swift 5.0+
- SwiftUI for UI
- Core Bluetooth for BLE
- Core ML for inference
- MVVM architecture pattern

### ML Development (Python)
- Python 3.9+
- TensorFlow 2.x
- scikit-learn
- pandas, numpy
- matplotlib for visualization

## Data & Models
- UCI HAR Dataset (baseline)
- TensorFlow Lite models (<50KB)
- 2-class lightweight model
- 8-class detailed model
- INT8 quantization for efficiency