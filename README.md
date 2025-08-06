# EdgeHAR - Distributed Edge Computing for Human Activity Recognition

## 🎯 Research Project
**Dynamic Load Balancing for Energy-Efficient Human Activity Recognition on Edge Devices**

This project implements a distributed edge computing system using multiple M5Stack Core2 devices for energy-efficient Human Activity Recognition (HAR) with adaptive accuracy control.

## 📊 System Architecture

```
[M5Stack_1: Sensor Node] → IMU Data Collection → BLE Transmission
                ↓
[M5Stack_2: Light Inference] → 2-class Classification (Active/Idle)
                ↓
[M5Stack_3: Detailed Inference] → 8-class Activity Recognition
                ↓
[iPhone: Coordinator] → System Orchestration & Visualization
```

## 🚀 Key Features

- **Distributed Processing**: 3× M5Stack devices working collaboratively
- **Dynamic Load Balancing**: Battery-aware task redistribution
- **Adaptive Accuracy**: Context-based switching between simple and detailed models
- **Energy Efficiency**: Target 40-60% power reduction vs single-device approach
- **Real-time Performance**: <150ms end-to-end latency

## 📁 Project Structure

```
MobileNLD-FL/                    # Repository root
├── M5Stack/                     # M5Stack firmware
│   ├── sensor_node/            # Device 1: IMU data collection
│   ├── light_inference/        # Device 2: 2-class model
│   └── detailed_inference/     # Device 3: 8-class model
├── iOS/                        # iPhone application
│   └── EdgeHAR/               # Swift coordinator app
├── scripts/                    # Python utilities
│   ├── download_uci_har.py   # Dataset download
│   ├── train_2class_model.py # Lightweight model training
│   └── train_8class_model.py # Detailed model training
├── models/                     # Trained TFLite models
├── data/                      # Datasets
│   └── uci_har/              # UCI HAR dataset
├── results/                   # Experiment results
└── docs/                      # Documentation
```

## 🛠️ Setup Instructions

### Prerequisites

- 3× M5Stack Core2 devices
- iPhone with iOS 15+
- Arduino IDE 2.0+
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
cd scripts
python download_uci_har.py
```

4. **Train Models**
```bash
python train_2class_model.py  # Generates 2class_model.tflite
python train_8class_model.py  # Generates 8class_model.tflite
```

5. **Deploy to M5Stack**
- Open Arduino IDE
- Install M5Core2 library
- Upload firmware from `M5Stack/` directories

6. **Build iOS App**
- Open `iOS/EdgeHAR` in Xcode
- Build and deploy to iPhone

## 📈 Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Power Reduction | 40-60% | 🟡 In Progress |
| Accuracy (8-class) | 85-92% | 🟡 In Progress |
| Latency | <150ms | 🟡 In Progress |
| Model Size | <50KB | ✅ Achieved |

## 🔬 Experiment Tracking

See `docs/実験進捗トラッカー.md` for detailed experiment logs and results.

## 📝 Research Timeline

- **Week 1** (Dec 10-16): System Implementation
- **Week 2** (Dec 17-23): Experiments & Validation
- **Week 3** (Dec 24-30): Paper Writing
- **Target**: IEICE Letter submission by Jan 31, 2025

## 📚 Documentation

- [Research Overview](docs/研究概要_EdgeHAR.md) (Japanese)
- [Implementation Plan](docs/実装計画_1ヶ月スプリント.md) (Japanese)
- [Experiment Tracker](docs/実験進捗トラッカー.md) (Japanese)

## 🤝 Contributing

This is an active research project. For collaboration inquiries, please contact the maintainer.

## 📄 License

This project is part of academic research. Please cite appropriately if using any part of this work.

## 🏆 Acknowledgments

- UCI Machine Learning Repository for the HAR dataset
- M5Stack community for hardware support
- TensorFlow Lite team for embedded ML tools

---
*Project Status: Active Development*  
*Last Updated: December 10, 2024*