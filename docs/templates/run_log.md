# Run Log

## Basic Information
**Run ID**: [YYYYMMDD_HHMMSSZ_SXX_Condition_NNN]  
**Date**: [YYYY-MM-DD]  
**Operator**: [Name]  

## Subject & Condition
**Subject ID**: [S01-S99]  
**Condition**: [Fixed-100ms|Fixed-200ms|Fixed-500ms|Adaptive]  
**Distance**: [1|3|5] meters  
**Location**: [Room/Lab]  

## Timing
**Start Time (UTC)**: [YYYY-MM-DDTHH:MM:SSZ]  
**End Time (UTC)**: [YYYY-MM-DDTHH:MM:SSZ]  
**Duration**: [MM:SS]  

## Configuration
**FW Commit**: [git hash]  
**App Commit**: [git hash]  
**Thresholds**: θ_q=[in/out] θ_a=[in/out]  
**EWMA Alpha**: [0.2]  
**Rate Limit**: [2] seconds  
**TX Power**: [0|-4|-8] dBm  

## Environment
**WiFi Networks**: [count]  
**BLE Devices**: [count]  
**Temperature**: [°C]  
**Interference**: [None|Low|Medium|High]  

## Schedule
| Phase | Start (s) | End (s) | Activity |
|-------|-----------|---------|----------|
| Warm-up | 0 | 60 | Quiet |
| Phase 1 | 60 | 360 | [Activity] |
| Phase 2 | 360 | 660 | [Activity] |
| Phase 3 | 660 | 960 | [Activity] |
| Phase 4 | 960 | 1200 | [Activity] |

## Data Files
- [ ] PPK2: `ppk2_[run_id].csv`
- [ ] Phone: `phone_[run_id].csv`
- [ ] UART: `uart_[run_id].log`
- [ ] Meta: `meta_[run_id].json`
- [ ] Manifest: `manifest_[run_id].txt`

## Quality Check
- [ ] Packet loss < 10%
- [ ] All files present
- [ ] File sizes reasonable
- [ ] Average current > 0
- [ ] No gaps > 1 minute

**QC Status**: [planned|passed|failed|excluded]  
**QC Reason Code**: [R1|R2|R3|R4|R5|R6]  

## Anomalies
[List any unexpected events, errors, or deviations]

## Notes
[Additional observations]

---
*Completed by*: [Name]  
*Time*: [HH:MM UTC]