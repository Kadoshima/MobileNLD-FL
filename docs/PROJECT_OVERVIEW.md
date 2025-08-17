# Project Overview: Adaptive BLE Advertising for Ultra-Low-Power Wearable HAR

## 📋 Executive Summary

This research project demonstrates how Human Activity Recognition (HAR) uncertainty can be leveraged to dynamically control BLE advertising intervals, achieving significant power savings in wearable devices without compromising detection latency.

## 🎯 Core Innovation

### The Problem
- Wearable HAR devices consume significant power through constant BLE advertising
- Fixed advertising intervals waste energy during stable activity periods
- Traditional approaches focus on inference optimization, neglecting communication efficiency

### Our Solution
- **Uncertainty-Driven Adaptation**: Use HAR classification uncertainty as a proxy for context changes
- **Dynamic BLE Control**: Adjust advertising intervals (100-2000ms) based on activity context
- **Composite Scoring**: Combine uncertainty metrics with temporal volatility for robust adaptation

## 🔬 Technical Approach

### 1. HAR Uncertainty Estimation
```
Uncertainty = -Σ(p_i * log(p_i))  // Entropy-based
Context Score = α*Uncertainty + β*Volatility
```

### 2. Adaptive States
- **Quiet State**: Low uncertainty → Long intervals (1000-2000ms)
- **Uncertain State**: Medium uncertainty → Medium intervals (200-500ms)  
- **Active State**: High uncertainty → Short intervals (100-200ms)

### 3. Implementation Stack
- **MCU**: nRF52840 (Cortex-M4F, 64MHz)
- **Sensor**: 6-axis IMU at 50Hz
- **Model**: 2-class CNN (<20KB) quantized INT8
- **BLE**: Legacy advertising (31 bytes payload)
- **Power**: Measured with Nordic PPK2

## 📊 Expected Outcomes

### Primary Metrics
| Metric | Baseline (Fixed 100ms) | Target (Adaptive) | Reduction |
|--------|------------------------|-------------------|-----------|
| Average Current | ~8-10 mA | ~4-6 mA | ≥40% |
| Energy/Minute | ~30 mJ/min | ~18 mJ/min | ≥40% |
| Battery Life | 20 hours | 33+ hours | ≥65% |

### Trade-offs
- **Latency**: p95 increases from ~100ms to ≤300ms (acceptable for HAR)
- **Accuracy**: F1 score degradation ≤1.5 points (97% → 95.5%)
- **Packet Loss**: <1% under normal conditions

## 🏗 System Components

### 1. Firmware (nRF52)
- Real-time HAR inference loop
- Uncertainty calculation module
- BLE advertising controller with state machine
- UART debug interface

### 2. Android Logger
- BLE scanner with timestamp logging
- CSV export for offline analysis
- Real-time packet loss monitoring
- Battery level tracking

### 3. Analysis Pipeline
- Power measurement parsing (PPK2)
- Latency distribution analysis
- Statistical significance testing
- Visualization generation

## 📈 Research Contribution

### Scientific Value
1. **First demonstration** of uncertainty-driven BLE adaptation for HAR
2. **Real-world validation** with actual power measurements
3. **Practical trade-off analysis** between power, latency, and accuracy

### Practical Impact
- Extends wearable battery life by 65%+
- Maintains acceptable user experience (sub-300ms detection)
- Simple enough for commercial deployment

## 🚀 Implementation Roadmap

### Phase 1: Core Development (Weeks 1-2)
- [ ] Implement HAR model on nRF52
- [ ] Add uncertainty calculation
- [ ] Create adaptive BLE controller
- [ ] Basic UART debugging

### Phase 2: Android Integration (Weeks 3-4)
- [ ] Develop BLE scanner app
- [ ] Implement CSV logging
- [ ] Add real-time monitoring
- [ ] Test end-to-end system

### Phase 3: Experiments (Week 5)
- [ ] Power measurements with PPK2
- [ ] Multi-subject data collection
- [ ] Baseline comparisons
- [ ] Statistical analysis

### Phase 4: Documentation (Week 6)
- [ ] Data visualization
- [ ] Paper writing (4 pages)
- [ ] Create reproducibility package
- [ ] Final review

## 📚 Key References

1. **Adaptive BLE**: Wang et al., "Energy-Efficient BLE Communication" (2023)
2. **HAR Uncertainty**: Liu et al., "Uncertainty Quantification in HAR" (2024)
3. **Power Optimization**: Nordic Semi, "nRF52 Power Optimization Guide" (2024)

## 🎓 Academic Target

**Publication**: IEICE Communications Express (ComEX)
- 4-page letter format
- Focus on practical demonstration
- Emphasis on reproducible results
- Target submission: 2025

## 💡 Success Criteria

### Must Have
- ✅ ≥40% power reduction demonstrated
- ✅ Complete system working end-to-end
- ✅ Reproducible experimental results
- ✅ 4-page paper ready for submission

### Nice to Have
- ⭐ Open-source release
- ⭐ Video demonstration
- ⭐ Extended 8-class evaluation
- ⭐ iOS compatibility testing

---
*This overview serves as the central reference for all project stakeholders*  
*Last Updated: 2024-12-17*