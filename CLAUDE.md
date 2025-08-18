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

### Hardware Configuration (PIVOT: M5StickC Plus2)
```
[M5StickC Plus2] - Wearable Device
  ├─ ESP32-PICO-V3-02 MCU (520KB RAM)
  ├─ MPU6886 6-axis IMU (内蔵)
  ├─ AXP192 Power Management IC
  ├─ 135mAh Battery
  ├─ On-device HAR inference
  ├─ Uncertainty calculation
  └─ Adaptive BLE advertising

[iPhone/Galaxy] - Receiver & Logger
  ├─ BLE packet reception
  ├─ Timestamp logging
  ├─ CSV export
  └─ Real-time monitoring
```

### Available Hardware
- **M5StickC Plus2**: 3台 (ESP32-based)
- **iPhone**: 13, 15
- **Android**: Galaxy S9
- **PPK2**: なし (AXP192で代替)
- **nRF52**: なし

### Software Stack
- **MCU Firmware**: Arduino IDE / ESP-IDF
- **HAR Model**: TensorFlow Lite Micro (2-class: Active/Idle)
- **Mobile App**: 
  - iOS: Swift/CoreBluetooth or nRF Connect
  - Android: Kotlin/BLE Scanner or nRF Connect
- **Analysis**: Python, pandas, matplotlib

## Common Commands

### Environment Setup
```bash
# Python environment for ML training
pip install tensorflow scikit-learn pandas numpy matplotlib

# Arduino IDE setup for M5StickC Plus2
# Install: M5StickCPlus2 library, TensorFlow Lite ESP32
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

## File Organization (STRICT)

```
MobileNLD-FL/                    # Repository root
├── firmware/                    # MCU firmware
│   ├── src/
│   └── include/
├── android_logger/              # Android app
│   └── app/
├── analysis/                    # Analysis scripts
│   ├── notebooks/              # Reproducible notebooks
│   └── requirements.txt        # Python dependencies
├── scripts/                     # Automation scripts
│   ├── new_run.sh              # Run ID generation
│   ├── ingest_run.py           # Data ingestion
│   ├── qc_run.py               # Quality check
│   └── rebuild_all.sh          # Complete regeneration
├── data/                        # ⚠️ APPEND-ONLY
│   ├── raw/                    # 🔒 READ-ONLY after save
│   │   └── YYYYMMDD/           # Date folders
│   │       └── subject_id/     # Subject folders
│   │           └── condition/  # Condition folders
│   │               ├── ppk2_*.csv
│   │               ├── phone_*.csv
│   │               ├── uart_*.log
│   │               ├── meta_*.json
│   │               └── manifest_*.txt
│   ├── processed/              # Intermediate files
│   └── releases/               # Publication snapshots
├── results/                     # Analysis outputs
│   ├── summary_by_run.csv
│   ├── summary_by_condition.csv
│   └── table_paper.csv
├── figs/                        # Generated figures
├── logs/                        # Execution logs
├── configs/                     # Experiment configs
├── docs/
│   ├── templates/              # Document templates
│   ├── adr/                    # Architecture decisions
│   ├── meetings/               # Meeting notes
│   ├── audit/                  # Weekly audits
│   └── governance.md           # THIS RULEBOOK
└── catalog.csv                  # Master index of all runs
```

## 🔴 CRITICAL: Research Execution Rules

### 1. Basic Principles (5 COMMANDMENTS)
1. **Append-only**: Raw data is IMMUTABLE. Never overwrite.
2. **Traceable**: Every artifact linked by run_id/commit hash.
3. **UTC-only**: All timestamps in UTC milliseconds, ISO8601.
4. **Automated**: Manual entry minimized. Scripts regenerate all.
5. **Double-backup**: Immediate checksum + dual backup.

### 2. Naming Convention (REGEX)
```
subject_id:  S[0-9]{2}              (e.g., S01)
device_id:   [A-Za-z0-9_-]{1,16}    (e.g., devA01)
session_id:  16-bit random          (per device boot)
condition:   Fixed-100ms|Fixed-200ms|Fixed-500ms|Adaptive
run_id:      YYYYMMDD_HHMMSSZ_{subject}_{condition}_{seq3}
             (e.g., 20250901_043015Z_S01_Adaptive_001)
filename:    {type}_{run_id}.{ext}  (ppk2_*, phone_*, uart_*, meta_*)
```
**FORBIDDEN**: Spaces, non-ASCII, uppercase extensions

### 3. Metadata Schema (meta_{run_id}.json)
```json
{
  "run_id": "required",
  "subject_id": "required",
  "device_id": "required",
  "condition": "required",
  "distance_m": "required",
  "fw_commit": "required",
  "app_commit": "required",
  "thresholds": {
    "theta_q_in": 0.3,
    "theta_q_out": 0.2,
    "theta_a_in": 0.7,
    "theta_a_out": 0.6
  },
  "start_iso8601_utc": "required",
  "end_iso8601_utc": "required",
  "qc_status": "planned|passed|failed|excluded",
  "qc_reason_code": [],
  "posthoc_patch": []
}
```

### 4. Execution SOP (MANDATORY)

#### Pre-Run Checklist
- [ ] NTP sync (PC & Android)
- [ ] Run ID generated (`scripts/new_run.sh`)
- [ ] Meta template created
- [ ] FW/App commit recorded
- [ ] PPK2 calibrated

#### During Run
- [ ] SYNC sequence (3 sec, LED×3)
- [ ] 20-minute measurement
- [ ] PPK2 + Phone + UART simultaneous
- [ ] Distance/environment noted

#### Post-Run (WITHIN 5 MIN)
- [ ] Save to `data/raw/YYYYMMDD/...`
- [ ] Generate SHA256 checksums
- [ ] Create manifest
- [ ] Set raw/ to READ-ONLY
- [ ] Light QC (loss<10%, files OK)
- [ ] Update catalog.csv
- [ ] Backup to cloud/external

### 5. Quality Control Rules

#### Light QC (Immediate)
- Packet loss < 10%
- p95 interval < 2× configured max
- All files present
- I_avg > 0

#### Full QC (Post-Analysis)
- Power reduction ≥ 40%
- p95 latency ≤ 300ms
- F1 degradation ≤ 1.5 points
- Packet loss ≤ 5%

#### Exclusion Codes
- **R1**: Reception gap >1 min
- **R2**: PPK2 overrange/disconnect
- **R3**: Protocol deviation
- **R4**: Excessive interference

### 6. Git & Change Management
- Commits: `feat:`, `fix:`, `docs:` prefixes
- Experiments require Issue + PR
- ADR for design decisions in `docs/adr/`
- Config changes in UART → meta.posthoc_patch

## Development Guidelines

### Code Style
- **C (nRF52)**: Zephyr coding style, detailed comments
- **Kotlin (Android)**: Android style guide, MVVM pattern
- **Python**: PEP 8, type hints, docstrings

### Testing Protocol
1. Unit tests for each component
2. Integration tests for BLE communication
3. End-to-end system tests
4. Power consumption measurements
5. Accuracy validation

## Experiment Execution & Tracking

### Automation Scripts (REQUIRED)
```bash
# Start new experiment run
scripts/new_run.sh                 # Generates run_id, creates templates

# After data collection
scripts/ingest_run.py --run_id XXX # Moves files, generates checksums
scripts/qc_run.py --run_id XXX     # Performs light QC

# Regenerate all results
scripts/rebuild_all.sh              # Complete analysis regeneration
```

### Key Metrics (Priority Order)
1. **Average Current**: ≥30% reduction vs fixed 100ms (ADJUSTED)
   - Measured with AXP192 @ 1Hz (M5StickC内蔵)
   - Report mean, std, and battery life estimation
2. **p95 Latency**: ≤300ms (BLE advertising-based)
   - Packet reception intervals from Android logs
3. **F1 Score**: Degradation ≤1.5 points
   - 2-class (Active/Idle) classification
4. **Packet Loss**: <5% under normal conditions

### Experiment Conditions
1. **Baseline**: Fixed-100ms, Fixed-200ms, Fixed-500ms
2. **Proposed**: Adaptive (100-2000ms based on uncertainty)
3. **Duration**: 20 minutes per condition
4. **Subjects**: 3-5 participants (S01-S05)
5. **Activities**: Walking, sitting, standing, stairs

### Data Integrity
- **Checksums**: SHA256 for all raw files
- **Backup**: Local + Cloud within same day
- **Versioning**: Git tags for paper submissions
- **Audit**: Weekly integrity checks in `docs/audit/`

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

### Week 1: M5StickC Implementation (PIVOT)
- ESP32 Arduino環境セットアップ
- BLE広告テスト（固定100ms）
- IMUデータ取得（MPU6886, 50Hz）
- AXP192電力測定

### Week 2: Adaptive Control & Apps
- HAR簡易モデル実装（閾値ベース）
- BLE適応制御（3状態）
- Phone側ロガー（Galaxy S9メイン）
- 統合テスト

### Week 3: Experiments & Analysis
- M5StickC 3台同時測定
- Fixed vs Adaptive比較
- 電力削減率算出（AXP192ベース）
- Nordic調達判断

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

## Critical Checklists

### Pre-Experiment Checklist
```
□ NTP time sync completed
□ Run ID generated (scripts/new_run.sh)
□ Meta template filled
□ FW/App commits recorded
□ PPK2 zero calibrated
□ Android location permission ON
□ SYNC sequence ready (3 sec)
```

### Post-Experiment Checklist
```
□ Files saved to data/raw/YYYYMMDD/...
□ SHA256 checksums generated
□ Manifest created
□ Raw folder set to READ-ONLY
□ Light QC passed (loss<10%)
□ catalog.csv updated
□ Cloud backup completed
□ Issue comment posted
```

### Weekly Audit Checklist
```
□ Catalog integrity verified
□ All manifests validated
□ Backup integrity tested
□ Random run reproducibility check
□ Audit log saved to docs/audit/YYYYWW.md
```

## Troubleshooting

### Common Issues
1. **BLE Advertising Conflicts**: Ensure proper interval timing
2. **PPK2 Measurement Drift**: Calibrate before each session
3. **Packet Loss**: Check Android scanner buffer size
4. **Uncertainty Calculation Overhead**: Optimize computation

### Incident Reporting
Any deviation from SOP requires:
1. Create `docs/incidents/YYYYMMDD_incident.md`
2. Record in meta.posthoc_patch
3. File GitHub Issue with `incident` label

## Resources

### Documentation
- [M5StickC Plus2](https://docs.m5stack.com/en/core/M5StickC%20PLUS2)
- [ESP32 Arduino Core](https://github.com/espressif/arduino-esp32)
- [TensorFlow Lite Micro ESP32](https://github.com/tanakamasayuki/Arduino_TensorFlowLite_ESP32)
- [UCI HAR Dataset](https://archive.ics.uci.edu/ml/datasets/human+activity+recognition+using+smartphones)

### Tools
- Arduino IDE 2.x
- ESP-IDF (optional)
- Android Studio / Xcode
- M5StickC Plus2 × 3
- Python 3.9+

## Prohibited Actions (VIOLATIONS)

❌ **NEVER**:
- Overwrite or delete raw data files
- Mix timezones (use UTC only)
- Change configs without recording in UART log
- Use custom naming conventions
- Submit non-reproducible results
- Skip checksums or manifests
- Modify analysis notebooks manually

## Templates Location

All templates in `docs/templates/`:
- `daily_log.md` - Daily experiment log
- `run_log.md` - Per-run recording
- `change_log.md` - Change tracking
- `adr_template.md` - Architecture decisions
- `incident_report.md` - Incident documentation

---
*Project Status: Active Development*
*Last Updated: 2024-12-17*
*Target: IEICE ComEX (2025)*
*Governance: STRICT APPEND-ONLY DATA POLICY*