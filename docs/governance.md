# Research Governance & Data Management Rules

## 0. Purpose and Scope

**Purpose**: Ensure complete traceability and reproducibility of all experimental work  
**Scope**: All project activities (design, experiments, analysis, publication)

## 1. Five Core Principles

1. **Immutable (Append-only)**: Raw data and metadata are READ-ONLY after creation
2. **Traceable (Unique IDs)**: Every artifact linked by run_id/commit hash
3. **UTC Time (Single timezone)**: All timestamps in UTC milliseconds, ISO8601 format
4. **Automated (Script-first)**: Manual operations minimized, everything regeneratable
5. **Dual-backup (Redundancy)**: Immediate checksum + cloud + local backup

## 2. Identifier & Naming Rules

### Regular Expressions
```regex
subject_id:     S[0-9]{2}                    # S01, S02, ..., S99
device_id:      [A-Za-z0-9_-]{1,16}         # devA01, nrf52_01
session_id:     [0-9A-F]{4}                 # 16-bit hex random
condition:      Fixed-(100|200|500)ms|Adaptive(-.*)?
run_id:         \d{8}_\d{6}Z_S\d{2}_[A-Za-z0-9-]+_\d{3}
filename:       (ppk2|phone|uart|meta)_.*\.(csv|log|json|txt)
```

### Examples
```
run_id:    20250901_043015Z_S01_Adaptive_001
filename:  ppk2_20250901_043015Z_S01_Adaptive_001.csv
```

### Forbidden
- Spaces in filenames
- Non-ASCII characters  
- Mixed case extensions
- Timezone suffixes other than Z (UTC)

## 3. Directory Structure

```
MobileNLD-FL/
├── data/
│   ├── raw/                    # 🔒 READ-ONLY after save
│   │   └── YYYYMMDD/
│   │       └── {subject_id}/
│   │           └── {condition}/
│   │               ├── ppk2_{run_id}.csv
│   │               ├── phone_{run_id}.csv
│   │               ├── uart_{run_id}.log
│   │               ├── meta_{run_id}.json
│   │               └── manifest_{run_id}.txt
│   ├── processed/              # Intermediate files
│   └── releases/               # Tagged snapshots
├── results/
│   ├── summary_by_run.csv
│   ├── summary_by_condition.csv
│   └── statistical_tests.csv
├── figs/
├── logs/
├── configs/
└── catalog.csv                 # Master index
```

## 4. Metadata Schema (Required Fields)

```json
{
  "run_id": "20250901_043015Z_S01_Adaptive_001",
  "subject_id": "S01",
  "device_id": "nrf52_01",
  "session_id": "A3F2",
  "condition": "Adaptive",
  "distance_m": 3,
  "location": "Lab Room 301",
  "phone_model": "Pixel 6",
  "phone_os_ver": "Android 13",
  
  "experiment_config": {
    "fw_commit": "abc123def",
    "app_commit": "456ghi789",
    "thresholds": {
      "theta_q_in": 0.3,
      "theta_q_out": 0.2,
      "theta_a_in": 0.7,
      "theta_a_out": 0.6
    },
    "ewma_alpha": 0.2,
    "rate_limit_s": 2,
    "adv_min_ms": 100,
    "adv_max_ms": 2000,
    "tx_power_dbm": 0,
    "imu_fs_hz": 50,
    "window_s": 2.0,
    "stride_s": 0.5
  },
  
  "environment": {
    "wifi_ssid_count": 12,
    "ble_devices_seen": 45,
    "room_temp_c": 22.5,
    "interferers_note": "None observed"
  },
  
  "schedule": [
    {"start_s": 0, "end_s": 300, "label": "Quiet"},
    {"start_s": 300, "end_s": 600, "label": "Active"},
    {"start_s": 600, "end_s": 900, "label": "Mixed"},
    {"start_s": 900, "end_s": 1200, "label": "Quiet"}
  ],
  
  "recording": {
    "operator": "researcher_id",
    "notes": "Subject comfortable, no issues",
    "start_iso8601_utc": "2025-09-01T04:30:15Z",
    "end_iso8601_utc": "2025-09-01T04:50:15Z"
  },
  
  "quality": {
    "qc_status": "passed",
    "qc_reason_code": [],
    "qc_timestamp": "2025-09-01T04:52:00Z"
  },
  
  "posthoc_patch": []
}
```

## 5. Log Formats

### PPK2 Power Log
```csv
Time(s),Current(mA),Voltage(V)
0.0001,8.234,3.001
0.0002,8.156,3.002
```
- Sample rate: 10 ksps minimum
- Zero calibration before each run

### Phone BLE Log
See `AndroidロガーCSVスキーマ定義.md` for complete schema

### UART Debug Log
```
[2025-09-01T04:30:15.123Z] RUN_START session=A3F2
[2025-09-01T04:30:15.456Z] CFG_SNAPSHOT theta_q=0.3/0.2 theta_a=0.7/0.6
[2025-09-01T04:30:20.789Z] STATE_CHANGE from=QUIET to=UNCERTAIN tick=5789
[2025-09-01T04:50:15.123Z] RUN_END packets_sent=1234 errors=0
```

### Manifest File
```
# Manifest for run_id: 20250901_043015Z_S01_Adaptive_001
# Generated: 2025-09-01T04:52:00Z
ppk2_20250901_043015Z_S01_Adaptive_001.csv    SHA256:abc123...  Size:1234567
phone_20250901_043015Z_S01_Adaptive_001.csv   SHA256:def456...  Size:2345678
uart_20250901_043015Z_S01_Adaptive_001.log    SHA256:ghi789...  Size:345678
meta_20250901_043015Z_S01_Adaptive_001.json   SHA256:jkl012...  Size:4567
```

## 6. Standard Operating Procedures (SOP)

### Pre-Run (MANDATORY)
1. **Time Sync**: NTP sync PC and Android
2. **Run ID**: Generate with `scripts/new_run.sh`
3. **Meta Template**: Fill operator, environment, schedule
4. **Commits**: Record firmware and app git hashes
5. **Calibration**: Zero PPK2, verify BLE reception

### During Run (MANDATORY)
1. **SYNC Phase**: 3-second sync sequence with LEDs
2. **Measurement**: 20 minutes continuous
3. **Triple Log**: PPK2 + Phone + UART simultaneous
4. **Monitoring**: Watch for anomalies, note in real-time
5. **Distance**: Maintain specified distance throughout

### Post-Run (WITHIN 5 MINUTES)
1. **Save Files**: To `data/raw/YYYYMMDD/subject_id/condition/`
2. **Checksums**: Generate SHA256 for all files
3. **Manifest**: Create with file list and hashes
4. **Permissions**: Set raw/ folder to READ-ONLY
5. **Light QC**: Verify loss<10%, files present
6. **Catalog**: Update master catalog.csv
7. **Backup**: Upload to cloud and external drive
8. **Issue**: Post completion comment with run_id

### End of Day
1. **Daily Log**: Fill `docs/logs/daily/YYYYMMDD.md`
2. **Backup Verify**: Confirm all backups complete
3. **Issue Summary**: Post day's achievements

## 7. Quality Control

### Light QC (Immediate)
- [ ] Packet loss < 10%
- [ ] p95 reception interval < 2× configured max
- [ ] All files present (ppk2, phone, uart, meta)
- [ ] Average current > 0 mA
- [ ] File sizes reasonable (>1KB)

### Full QC (Post-Analysis)
- [ ] Power reduction ≥ 40% vs Fixed-100ms
- [ ] p95 latency ≤ 300ms
- [ ] F1 score degradation ≤ 1.5 points  
- [ ] Packet loss ≤ 5%
- [ ] 8-hour stability (if tested)

### Exclusion Codes
- **R1**: BLE reception gap >1 minute continuous
- **R2**: PPK2 overrange or power disconnection
- **R3**: Protocol deviation (distance/posture)
- **R4**: Excessive interference (construction/WiFi)
- **R5**: Subject non-compliance
- **R6**: Equipment malfunction

## 8. Change Management

### Code Changes
- Git commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- Experiment-affecting changes require Issue + PR
- Tag releases for paper submissions

### Design Decisions
- Document in `docs/adr/YYYY-NNN-title.md`
- Include: Context, Decision, Status, Consequences, Alternatives

### Configuration Changes
- Runtime changes via UART must be logged
- Post-run: Copy to meta.posthoc_patch array
- Format: `{"ts": "ISO8601", "field": "x", "old": "y", "new": "z", "reason": "..."}`

## 9. Data Integrity & Preservation

### Checksums
- SHA256 for all raw files
- Store in manifest_{run_id}.txt
- Verify weekly in audit

### Backup Strategy
- **Immediate**: Local working copy
- **Same day**: Cloud backup (Google Drive/Dropbox)
- **Weekly**: External HDD snapshot
- **Monthly**: Archive to cold storage

### Version Control
- Raw data: NOT in git (too large)
- Processed/results: Git LFS if needed
- Releases: Tag with `paper-v1.0` etc.

## 10. Time, Units, and Precision

### Time Standards
- **Internal**: UTC milliseconds (Unix epoch)
- **Logs**: ISO 8601 with Z suffix
- **Analysis**: pandas datetime64[ns, UTC]
- **Display**: Can convert to local for figures

### Unit Standards
| Measurement | Unit | Format | Example |
|-------------|------|--------|---------|
| Current | mA | 0.000 | 8.234 |
| Voltage | V | 0.000 | 3.001 |
| Power | mW | 0.00 | 24.71 |
| Energy | mJ | 0.0 | 494.2 |
| Time | ms | integer | 1234 |
| Distance | m | 0.0 | 3.0 |
| RSSI | dBm | integer | -67 |

### Numerical Precision
- Raw data: Full precision, no rounding
- Analysis: Round only for display
- CSV decimal: Period (.) not comma
- Random seeds: Fixed for reproducibility

## 11. Security & Privacy

### PII Protection
- No real names, only subject IDs
- No photos/videos of subjects
- No audio recordings
- No personal device IDs

### Data Sharing
- Anonymize MAC addresses
- Use dummy Company ID (0xFFFF)
- Remove SSIDs from logs
- PI approval before external sharing

## 12. Automation Scripts

### Essential Scripts
```bash
scripts/new_run.sh              # Generate run_id and templates
scripts/ingest_run.py           # Move files and create manifest
scripts/qc_run.py               # Perform light QC
scripts/rebuild_all.sh          # Regenerate all results
scripts/backup_daily.sh         # Daily backup routine
scripts/audit_weekly.py         # Weekly integrity check
```

### Helper Scripts
```bash
scripts/validate_schema.py      # Check meta.json format
scripts/plot_run.py             # Quick visualization
scripts/compare_conditions.py   # Statistical comparison
scripts/generate_paper_figs.py  # Publication-ready figures
```

## 13. Templates

Located in `docs/templates/`:

### daily_log.md
```markdown
# Daily Log - YYYY-MM-DD

**Operator**: [name]
**Goals**: [what planned]
**Completed Runs**: [list of run_ids]
**Issues**: [any problems]
**Decisions**: [any changes made]
**Tomorrow**: [next steps]
```

### run_log.md
```markdown
# Run Log

**Run ID**: [run_id]
**Subject**: [S01]
**Condition**: [Adaptive]
**Start/End**: [times]
**Anomalies**: [any issues]
**QC Status**: [passed/failed]
```

## 14. Weekly Audit

Every Monday:
1. Verify catalog.csv completeness
2. Check all manifests valid
3. Test restore random run from backup
4. Validate checksums sample (10%)
5. Create `docs/audit/YYYYWW.md` report

## 15. Incident Response

When SOP violated:
1. Stop current activity
2. Create `docs/incidents/YYYYMMDD_HH_incident.md`
3. Document: What, When, Why, Impact, Fix
4. Update affected meta.json files
5. File GitHub Issue with `incident` label
6. PI notification if data compromised

## 16. Definition of Done

### Experiment Run
- [ ] All files in correct location
- [ ] Checksums generated
- [ ] Manifest created
- [ ] Raw folder READ-ONLY
- [ ] Light QC passed
- [ ] Catalog updated
- [ ] Backup completed
- [ ] Issue comment posted

### Analysis
- [ ] Scripts reproduce from raw
- [ ] Results in standard format
- [ ] Statistical tests documented
- [ ] Figures meet standards
- [ ] Notebook committed

### Paper Submission
- [ ] Data snapshot created
- [ ] Code tagged
- [ ] DOI requested
- [ ] Reproducibility tested
- [ ] Archive deposited

## 17. Contact & Escalation

**Principal Investigator**: [Name] - [email]  
**Data Manager**: [Name] - [email]  
**Emergency**: [Phone number]

For violations or incidents, escalate within 24 hours.

---
*Version: 1.0*  
*Effective Date: 2024-12-17*  
*Review Schedule: Monthly*  
*Owner: Project Lead*