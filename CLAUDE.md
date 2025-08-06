# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Edge-HAR** is a research project for **Adaptive Human Activity Recognition Using Distributed Edge Computing**. The project implements a multi-device collaborative system using M5Stack Core2 devices and iPhone for energy-efficient real-time activity recognition with dynamic load balancing.

## Research Focus

### Current Research (2024-12-10 onwards)
**Title**: "Dynamic Load Balancing for Energy-Efficient Human Activity Recognition on Edge Devices"
**Target**: IEICE Transactions Letter (4 pages, submission deadline: 2025-01-31)

### Key Innovation
- **Distributed Edge Computing**: 3× M5Stack Core2 devices working collaboratively
- **Dynamic Load Balancing**: Battery-aware task redistribution
- **Adaptive Accuracy Control**: Context-based switching between 2-class and 8-class models
- **Energy Efficiency**: 60% power reduction compared to single-device approach

## System Architecture

### Hardware Configuration
```
[M5Stack_1] - Sensor Hub
  ├─ MPU6886 (6-axis IMU)
  ├─ Data preprocessing
  └─ BLE transmission

[M5Stack_2] - Light Inference
  ├─ 2-class classifier (Active/Idle)
  ├─ TensorFlow Lite Micro
  └─ Quick decision making

[M5Stack_3] - Detailed Inference  
  ├─ 8-class classifier
  ├─ Complex activity recognition
  └─ Power-intensive processing

[iPhone] - Coordinator
  ├─ System orchestration
  ├─ Load balancing decisions
  └─ Real-time visualization
```

### Software Stack
- **M5Stack Firmware**: Arduino/PlatformIO, TFLite Micro, FreeRTOS
- **iPhone App**: Swift 5.0+, Core Bluetooth, Core ML
- **ML Training**: Python, TensorFlow, scikit-learn

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

# Generate synthetic test data
python scripts/generate_test_data.py

# Process and split dataset
python scripts/prepare_dataset.py
```

### Model Training
```bash
# Train 2-class lightweight model
python scripts/train_2class_model.py

# Train 8-class detailed model  
python scripts/train_8class_model.py

# Quantize for TFLite Micro
python scripts/quantize_models.py
```

### Performance Analysis
```bash
# Analyze power consumption logs
python scripts/analyze_power.py

# Generate accuracy reports
python scripts/evaluate_models.py

# Create paper figures
python scripts/generate_figures.py
```

## File Organization

```
MobileNLD-FL/              # Repository root (keeping original name)
├── docs/
│   ├── 研究概要_EdgeHAR.md         # Research overview
│   ├── 実装計画_1ヶ月スプリント.md    # Implementation plan
│   ├── 実験進捗トラッカー.md         # Experiment tracker
│   └── archive_NLD-FL/            # Archived NLD research
├── M5Stack/                       # M5Stack firmware
│   ├── sensor_node/              # M5Stack_1 code
│   ├── light_inference/          # M5Stack_2 code
│   └── detailed_inference/       # M5Stack_3 code
├── iOS/                          # iPhone application
│   └── EdgeHAR/                 # Swift project
├── scripts/                      # Python utilities
│   ├── train_*.py               # Model training
│   ├── evaluate_*.py            # Evaluation
│   └── analyze_*.py             # Analysis
├── models/                       # Trained models
│   ├── 2class_model.tflite
│   └── 8class_model.tflite
├── data/                        # Datasets
│   ├── uci_har/                # UCI HAR dataset
│   └── custom/                  # Custom collected data
└── results/                     # Experiment results
    ├── power_logs/
    ├── accuracy_results/
    └── figures/
```

## Development Guidelines

### Code Style
- **C++ (M5Stack)**: Arduino style, clear comments
- **Swift (iOS)**: SwiftUI, MVVM pattern
- **Python**: PEP 8, type hints

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

### Key Metrics
- **Power Consumption**: Target 40-60% reduction
- **Accuracy**: 85-92% for 8-class (target range)
- **Latency**: <150ms end-to-end (acceptable)
- **Battery Life**: 1.5-2× improvement (target)

### Data Collection Protocol
1. Collect data from 3 participants
2. 8 activity classes × 100 samples each
3. 10-fold cross-validation
4. Statistical significance testing (p<0.05)

## Paper Writing Guidelines

### IEICE Letter Format
- 4 pages maximum
- 2-column format
- Abstract: 150 words
- 15-20 references

### Section Allocation
- Introduction: 0.5 pages
- Related Work: 0.5 pages  
- Proposed Method: 1.5 pages
- Experiments: 1.0 pages
- Results & Conclusion: 0.5 pages

## Timeline (Critical Path)

### Week 1 (Dec 10-16): Implementation
- Day 1-2: BLE communication setup
- Day 3-4: TFLite Micro integration
- Day 5-7: Distributed system integration

### Week 2 (Dec 17-23): Experiments
- Day 8-10: Data collection
- Day 11-12: Power measurements
- Day 13-14: Accuracy evaluation

### Week 3 (Dec 24-30): Paper Writing
- Day 15-17: Draft writing
- Day 18-19: Figure generation
- Day 20-21: Review and submission prep

## Success Criteria

### Technical Goals
- ✅ 3-device BLE network functional
- ✅ TFLite Micro models <50KB
- ✅ Real-time inference <150ms
- ✅ Power reduction 40-60%

### Research Goals
- ✅ Novel distributed edge HAR system
- ✅ Quantitative evaluation complete
- ✅ Paper ready for submission
- ✅ Reproducible results

## Troubleshooting

### Common Issues
1. **BLE Connection Drops**: Reduce transmission rate, implement retry logic
2. **Memory Overflow**: Optimize model size, reduce buffer sizes
3. **Power Measurement Noise**: Use averaging, multiple trials
4. **Model Accuracy Low**: Increase training data, tune hyperparameters

## Resources

### Documentation
- [M5Stack Core2 Guide](https://docs.m5stack.com/en/core/core2)
- [TensorFlow Lite Micro](https://www.tensorflow.org/lite/microcontrollers)
- [UCI HAR Dataset](https://archive.ics.uci.edu/ml/datasets/human+activity+recognition+using+smartphones)

### Tools
- Arduino IDE 2.0+
- Xcode 15+
- Python 3.9+
- USB Power Meter

---
*Project Status: Active Development*
*Last Updated: 2024-12-10*
*Deadline: 2025-01-31 (IEICE Submission)*