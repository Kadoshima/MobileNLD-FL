# EdgeHAR Project Overview

## Project Purpose
EdgeHAR (Edge Human Activity Recognition) is a research project implementing distributed edge computing for energy-efficient human activity recognition using multiple M5Stack Core2 devices and iPhone coordination.

## Research Goals
- Target: IEICE Transactions Letter submission (deadline: 2025-01-31)
- Innovation: Dynamic load balancing with 40-60% power reduction
- Multi-device collaboration: 3× M5Stack devices + iPhone coordinator

## System Architecture
1. **M5Stack_1**: Sensor hub with MPU6886 IMU, data preprocessing
2. **M5Stack_2**: Light inference with 2-class classifier (Active/Idle)
3. **M5Stack_3**: Detailed inference with 8-class classifier
4. **iPhone**: System orchestration and visualization

## Key Features
- Distributed processing across edge devices
- Battery-aware task redistribution
- Adaptive accuracy control (2-class vs 8-class)
- Real-time performance (<150ms latency)
- TensorFlow Lite Micro for embedded inference

## Performance Targets
- Power reduction: 40-60%
- Accuracy (8-class): 85-92%
- Model size: <50KB per model
- Latency: <150ms end-to-end