# Requirements v1.1 Alignment Status

## Updated Documents (2024-12-17)

### 1. 研究概要.md - COMPLETED
- Power reduction target: 30-40% (aligned with v1.1)
- 3-state machine details (Quiet/Uncertain/Active)
- EWMA algorithm (α=0.2) and thresholds
- Non-connectable advertising (ADV_NONCONN_IND)
- Manufacturer Specific Data format (12-16 bytes)
- Multi-device testing (3 units)
- AXP192 accuracy (±5mA)
- 6-week timeline
- Experiment duration: 15min/condition

### 2. CLAUDE.md - COMPLETED
- Power target: 30-40% (ESP32 estimated)
- Experiment conditions updated
- 6-week timeline detailed
- Success criteria aligned with acceptance criteria
- Multi-device configuration noted

### 3. README.md - COMPLETED  
- Power target: 30-40%
- Non-connectable mode (ADV_NONCONN_IND) added
- AXP192 accuracy noted

## Key Alignment Points
1. **BLE Mode**: Non-connectable advertising (ADV_NONCONN_IND)
2. **Power Target**: 30-40% reduction (relative, ESP32 estimated)
3. **Measurement**: AXP192 @ 1Hz (±5mA accuracy)
4. **3-State Control**: Quiet(2000ms)/Uncertain(500ms)/Active(100ms)
5. **EWMA**: m_t = 0.2·u_t + 0.8·m_{t-1}
6. **Thresholds**: θ_q_in=0.25, θ_q_out=0.30, θ_a_in=0.60, θ_a_out=0.55
7. **Multi-device**: 3 M5StickC Plus2 units
8. **Timeline**: 6 weeks (not 3 weeks PoC)
9. **Experiment**: 15min/condition, 3-5 subjects
10. **Data Format**: Manufacturer Specific Data with defined structure