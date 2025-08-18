#!/usr/bin/env python3
"""
qc_run.py - Perform quality check on ingested run data
"""

import os
import sys
import json
import pandas as pd
import argparse
from pathlib import Path
from datetime import datetime

def check_ppk2_data(filepath):
    """Check PPK2 power measurement data."""
    try:
        df = pd.read_csv(filepath)
        
        # Expected columns
        expected_cols = ['Time(s)', 'Current(mA)', 'Voltage(V)']
        if not all(col in df.columns for col in expected_cols):
            return False, "Missing expected columns"
        
        # Check data quality
        avg_current = df['Current(mA)'].mean()
        if avg_current <= 0:
            return False, f"Invalid average current: {avg_current:.2f} mA"
        
        # Check for gaps
        time_diff = df['Time(s)'].diff()
        max_gap = time_diff.max()
        if max_gap > 1.0:  # More than 1 second gap
            return False, f"Large time gap detected: {max_gap:.2f} seconds"
        
        stats = {
            'rows': len(df),
            'duration_s': df['Time(s)'].max() - df['Time(s)'].min(),
            'avg_current_mA': avg_current,
            'avg_voltage_V': df['Voltage(V)'].mean(),
            'avg_power_mW': (df['Current(mA)'] * df['Voltage(V)']).mean()
        }
        
        return True, stats
    except Exception as e:
        return False, str(e)

def check_phone_data(filepath):
    """Check Android BLE log data."""
    try:
        df = pd.read_csv(filepath)
        
        # Check minimum required columns
        required_cols = ['timestamp_phone_unix_ms', 'rssi', 'mfg_raw_hex']
        if not all(col in df.columns for col in required_cols):
            return False, "Missing required columns"
        
        # Calculate packet statistics
        df['timestamp_s'] = df['timestamp_phone_unix_ms'] / 1000.0
        df['interval_ms'] = df['timestamp_phone_unix_ms'].diff()
        
        # Check for large gaps (>10 seconds)
        max_gap_ms = df['interval_ms'].max()
        if max_gap_ms > 10000:
            gap_count = (df['interval_ms'] > 10000).sum()
            return False, f"Found {gap_count} gaps > 10 seconds"
        
        # Calculate loss rate (approximate)
        expected_packets = (df['timestamp_s'].max() - df['timestamp_s'].min()) / 0.1  # Assuming ~100ms average
        actual_packets = len(df)
        loss_rate = max(0, 1 - (actual_packets / expected_packets)) * 100
        
        stats = {
            'packets': len(df),
            'duration_s': df['timestamp_s'].max() - df['timestamp_s'].min(),
            'avg_rssi_dBm': df['rssi'].mean(),
            'p50_interval_ms': df['interval_ms'].quantile(0.50),
            'p95_interval_ms': df['interval_ms'].quantile(0.95),
            'p99_interval_ms': df['interval_ms'].quantile(0.99),
            'est_loss_rate_pct': loss_rate
        }
        
        return True, stats
    except Exception as e:
        return False, str(e)

def check_uart_log(filepath):
    """Check UART debug log."""
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
        
        # Look for key markers
        has_start = any('RUN_START' in line for line in lines)
        has_end = any('RUN_END' in line for line in lines)
        has_config = any('CFG_SNAPSHOT' in line for line in lines)
        
        if not has_start:
            return False, "Missing RUN_START marker"
        if not has_end:
            return False, "Missing RUN_END marker"
        if not has_config:
            return False, "Missing CFG_SNAPSHOT"
        
        # Count state changes
        state_changes = sum(1 for line in lines if 'STATE_CHANGE' in line)
        errors = sum(1 for line in lines if 'ERROR' in line)
        
        stats = {
            'lines': len(lines),
            'state_changes': state_changes,
            'errors': errors,
            'file_size_kb': filepath.stat().st_size / 1024
        }
        
        return True, stats
    except Exception as e:
        return False, str(e)

def main():
    parser = argparse.ArgumentParser(description='Quality check experiment run')
    parser.add_argument('--run_id', required=True, help='Run ID to check')
    parser.add_argument('--update_meta', action='store_true', help='Update meta.json with QC results')
    
    args = parser.parse_args()
    
    # Parse run_id to find files
    parts = args.run_id.split('_')
    date = parts[0]
    subject = parts[2]
    condition = '_'.join(parts[3:-1])
    
    # Define data directory
    data_dir = Path(f"data/raw/{date}/{subject}/{condition}")
    
    if not data_dir.exists():
        print(f"Error: Directory not found: {data_dir}")
        sys.exit(1)
    
    print(f"Quality Check for Run: {args.run_id}")
    print("=" * 50)
    
    # Check each file type
    qc_passed = True
    qc_results = {}
    
    # Check PPK2 data
    ppk2_file = data_dir / f"ppk2_{args.run_id}.csv"
    if ppk2_file.exists():
        success, result = check_ppk2_data(ppk2_file)
        qc_results['ppk2'] = result
        if success:
            print(f"✓ PPK2 data: PASS")
            print(f"  - Duration: {result['duration_s']:.1f} seconds")
            print(f"  - Avg Current: {result['avg_current_mA']:.2f} mA")
            print(f"  - Avg Power: {result['avg_power_mW']:.2f} mW")
        else:
            print(f"✗ PPK2 data: FAIL - {result}")
            qc_passed = False
    else:
        print(f"✗ PPK2 data: FILE NOT FOUND")
        qc_passed = False
    
    print()
    
    # Check Phone data
    phone_file = data_dir / f"phone_{args.run_id}.csv"
    if phone_file.exists():
        success, result = check_phone_data(phone_file)
        qc_results['phone'] = result
        if success:
            print(f"✓ Phone data: PASS")
            print(f"  - Packets: {result['packets']}")
            print(f"  - p50 interval: {result['p50_interval_ms']:.1f} ms")
            print(f"  - p95 interval: {result['p95_interval_ms']:.1f} ms")
            print(f"  - Est. loss rate: {result['est_loss_rate_pct']:.1f}%")
            
            # Check against thresholds
            if result['est_loss_rate_pct'] > 10:
                print(f"  ⚠ Warning: Loss rate > 10%")
            if result['p95_interval_ms'] > 600:  # Assuming max 2× 300ms
                print(f"  ⚠ Warning: p95 interval > 600ms")
        else:
            print(f"✗ Phone data: FAIL - {result}")
            qc_passed = False
    else:
        print(f"✗ Phone data: FILE NOT FOUND")
        qc_passed = False
    
    print()
    
    # Check UART log
    uart_file = data_dir / f"uart_{args.run_id}.log"
    if uart_file.exists():
        success, result = check_uart_log(uart_file)
        qc_results['uart'] = result
        if success:
            print(f"✓ UART log: PASS")
            print(f"  - Lines: {result['lines']}")
            print(f"  - State changes: {result['state_changes']}")
            print(f"  - Errors: {result['errors']}")
            
            if result['errors'] > 0:
                print(f"  ⚠ Warning: {result['errors']} errors logged")
        else:
            print(f"✗ UART log: FAIL - {result}")
            qc_passed = False
    else:
        print(f"✗ UART log: FILE NOT FOUND")
        qc_passed = False
    
    print()
    print("=" * 50)
    
    # Update meta.json if requested
    meta_file = data_dir / f"meta_{args.run_id}.json"
    if args.update_meta and meta_file.exists():
        with open(meta_file, 'r') as f:
            meta = json.load(f)
        
        # Update QC status
        meta['quality']['qc_status'] = 'passed' if qc_passed else 'failed'
        meta['quality']['qc_timestamp'] = datetime.utcnow().isoformat() + 'Z'
        meta['quality']['qc_results'] = qc_results
        
        # Determine reason codes if failed
        if not qc_passed:
            reason_codes = []
            if 'phone' in qc_results and isinstance(qc_results['phone'], dict):
                if qc_results['phone'].get('est_loss_rate_pct', 0) > 10:
                    reason_codes.append('R1')  # High loss rate
            meta['quality']['qc_reason_code'] = reason_codes
        
        # Write back (temporarily remove read-only)
        os.chmod(meta_file, 0o644)
        with open(meta_file, 'w') as f:
            json.dump(meta, f, indent=2)
        os.chmod(meta_file, 0o444)
        
        print(f"✓ Updated meta.json with QC results")
    
    # Final verdict
    if qc_passed:
        print("✅ QUALITY CHECK: PASSED")
    else:
        print("❌ QUALITY CHECK: FAILED")
        sys.exit(1)

if __name__ == "__main__":
    main()