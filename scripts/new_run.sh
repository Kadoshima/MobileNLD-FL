#!/bin/bash
# new_run.sh - Generate run ID and create templates for new experiment run

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get current date/time in UTC
DATE=$(date -u +%Y%m%d)
TIME=$(date -u +%H%M%S)
DATETIME="${DATE}_${TIME}Z"

# Prompt for subject ID
echo -e "${YELLOW}Enter Subject ID (e.g., S01):${NC}"
read -r SUBJECT_ID
if [[ ! $SUBJECT_ID =~ ^S[0-9]{2}$ ]]; then
    echo -e "${RED}Invalid subject ID format. Must be S01-S99${NC}"
    exit 1
fi

# Prompt for condition
echo -e "${YELLOW}Select Condition:${NC}"
echo "1) Fixed-100ms"
echo "2) Fixed-200ms"
echo "3) Fixed-500ms"
echo "4) Adaptive"
read -r CONDITION_CHOICE

case $CONDITION_CHOICE in
    1) CONDITION="Fixed-100ms" ;;
    2) CONDITION="Fixed-200ms" ;;
    3) CONDITION="Fixed-500ms" ;;
    4) CONDITION="Adaptive" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

# Find next sequence number for today
SEQ=001
DATA_DIR="data/raw/${DATE}/${SUBJECT_ID}/${CONDITION}"
while [ -d "${DATA_DIR}_${SEQ}" ]; do
    SEQ=$(printf "%03d" $((10#$SEQ + 1)))
done

# Generate run ID
RUN_ID="${DATETIME}_${SUBJECT_ID}_${CONDITION}_${SEQ}"

# Create directory structure
RUN_DIR="data/raw/${DATE}/${SUBJECT_ID}/${CONDITION}"
mkdir -p "$RUN_DIR"

echo -e "${GREEN}✓ Generated Run ID: ${RUN_ID}${NC}"
echo -e "${GREEN}✓ Created directory: ${RUN_DIR}${NC}"

# Create meta.json template
META_FILE="${RUN_DIR}/meta_${RUN_ID}.json"
cat > "$META_FILE" << EOF
{
  "run_id": "${RUN_ID}",
  "subject_id": "${SUBJECT_ID}",
  "device_id": "DEVICE_ID_HERE",
  "session_id": "XXXX",
  "condition": "${CONDITION}",
  "distance_m": 3,
  "location": "Lab Room XXX",
  "phone_model": "Pixel 6",
  "phone_os_ver": "Android 13",
  
  "experiment_config": {
    "fw_commit": "GIT_HASH_HERE",
    "app_commit": "GIT_HASH_HERE",
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
    "wifi_ssid_count": 0,
    "ble_devices_seen": 0,
    "room_temp_c": 22.0,
    "interferers_note": "None"
  },
  
  "schedule": [
    {"start_s": 0, "end_s": 300, "label": "TBD"},
    {"start_s": 300, "end_s": 600, "label": "TBD"},
    {"start_s": 600, "end_s": 900, "label": "TBD"},
    {"start_s": 900, "end_s": 1200, "label": "TBD"}
  ],
  
  "recording": {
    "operator": "YOUR_NAME_HERE",
    "notes": "",
    "start_iso8601_utc": "",
    "end_iso8601_utc": ""
  },
  
  "quality": {
    "qc_status": "planned",
    "qc_reason_code": [],
    "qc_timestamp": ""
  },
  
  "posthoc_patch": []
}
EOF

echo -e "${GREEN}✓ Created meta template: ${META_FILE}${NC}"

# Display checklist
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}PRE-RUN CHECKLIST:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo "□ NTP time sync completed (PC and Android)"
echo "□ PPK2 connected and calibrated"
echo "□ Android app ready with location permission"
echo "□ Subject briefed and consent obtained"
echo "□ Update meta.json with:"
echo "  - device_id"
echo "  - fw_commit (git rev-parse HEAD)"
echo "  - app_commit"
echo "  - operator name"
echo "  - environment details"
echo ""
echo -e "${YELLOW}DURING RUN:${NC}"
echo "□ Start PPK2 recording"
echo "□ Start Android app logging"
echo "□ Start UART logging"
echo "□ Perform 3-second SYNC sequence"
echo "□ Monitor for 20 minutes"
echo ""
echo -e "${YELLOW}FILES TO COLLECT:${NC}"
echo "  - ppk2_${RUN_ID}.csv"
echo "  - phone_${RUN_ID}.csv"
echo "  - uart_${RUN_ID}.log"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

# Save run ID to clipboard if possible
if command -v pbcopy &> /dev/null; then
    echo "$RUN_ID" | pbcopy
    echo -e "${GREEN}✓ Run ID copied to clipboard${NC}"
elif command -v xclip &> /dev/null; then
    echo "$RUN_ID" | xclip -selection clipboard
    echo -e "${GREEN}✓ Run ID copied to clipboard${NC}"
fi

# Create a run command file for easy reference
echo "$RUN_ID" > "current_run_id.txt"
echo -e "${GREEN}✓ Saved to current_run_id.txt${NC}"

echo ""
echo -e "${GREEN}Ready to start experiment!${NC}"
echo -e "${GREEN}Run ID: ${RUN_ID}${NC}"