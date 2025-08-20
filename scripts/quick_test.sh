#!/bin/bash
# quick_test.sh - Phase 1 実現可能性検証用スクリプト

set -e

echo "================================"
echo "M5StickC Plus2 Quick Test Helper"
echo "================================"
echo ""

# メニュー表示
echo "Select test type:"
echo "1) BLE Fixed 100ms Test"
echo "2) IMU HAR Test"
echo "3) Power Measurement Test"
echo "4) Generate Run ID for experiment"
echo "5) View today's log"
read -r CHOICE

case $CHOICE in
    1)
        echo "BLE Test Selected"
        echo "1. Upload: firmware/m5stick/ble_fixed_100ms/ble_fixed_100ms.ino"
        echo "2. Open nRF Connect on phone"
        echo "3. Look for: M5HAR_01"
        echo "4. Check interval: ~100ms"
        echo ""
        echo "Press Enter when ready to log results..."
        read
        echo "Test completed at: $(date +%Y-%m-%d\ %H:%M:%S)"
        echo "- Device found: [Y/N]?"
        read FOUND
        echo "Result logged: BLE test - Device found: $FOUND" >> docs/logs/daily_log_$(date +%Y%m%d).md
        ;;
    
    2)
        echo "IMU HAR Test Selected"
        echo "1. Upload: firmware/m5stick/imu_har_test/imu_har_test.ino"
        echo "2. Move device: Still -> Walking -> Still"
        echo "3. Check display for state changes"
        echo ""
        echo "States observed (comma-separated: IDLE,ACTIVE,UNCERTAIN):"
        read STATES
        echo "Uncertainty range (min-max):"
        read UNCERT
        echo "Result logged: IMU test - States: $STATES, Uncertainty: $UNCERT" >> docs/logs/daily_log_$(date +%Y%m%d).md
        ;;
    
    3)
        echo "Power Test Selected"
        echo "1. Upload: firmware/m5stick/power_test/power_test.ino"
        echo "2. Open Serial Monitor (115200 baud)"
        echo "3. Copy CSV data after 5 minutes"
        echo ""
        echo "Average current for 100ms interval (mA):"
        read CURR_100
        echo "Average current for 2000ms interval (mA):"
        read CURR_2000
        REDUCTION=$(echo "scale=2; ($CURR_100 - $CURR_2000) / $CURR_100 * 100" | bc)
        echo "Power reduction: ${REDUCTION}%"
        echo "Result logged: Power test - 100ms: ${CURR_100}mA, 2000ms: ${CURR_2000}mA, Reduction: ${REDUCTION}%" >> docs/logs/daily_log_$(date +%Y%m%d).md
        ;;
    
    4)
        echo "Generating Run ID..."
        DATE=$(date -u +%Y%m%d)
        TIME=$(date -u +%H%M%S)
        echo "Run ID: ${DATE}_${TIME}Z_S01_Test_001"
        echo "Use this for file naming!"
        ;;
    
    5)
        echo "Today's Log:"
        echo "============"
        cat docs/logs/daily_log_$(date +%Y%m%d).md 2>/dev/null || echo "No log for today yet"
        ;;
    
    *)
        echo "Invalid choice"
        ;;
esac

echo ""
echo "Next step: Continue with Phase 1 tasks"
echo "See: docs/手順書_M5StickC_Plus2_環境構築.md"