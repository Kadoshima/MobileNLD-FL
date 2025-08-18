#!/usr/bin/env python3
"""
ingest_run.py - Move experiment files to correct location and generate checksums
"""

import os
import sys
import json
import hashlib
import shutil
import argparse
from datetime import datetime
from pathlib import Path

def calculate_sha256(filepath):
    """Calculate SHA256 checksum of a file."""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def parse_run_id(run_id):
    """Parse run_id to extract components."""
    parts = run_id.split('_')
    if len(parts) != 5:
        raise ValueError(f"Invalid run_id format: {run_id}")
    
    date = parts[0]
    time = parts[1]
    subject = parts[2]
    condition = '_'.join(parts[3:-1])  # Handle Fixed-XXXms format
    seq = parts[-1]
    
    return {
        'date': date,
        'time': time,
        'subject': subject,
        'condition': condition,
        'seq': seq,
        'run_id': run_id
    }

def main():
    parser = argparse.ArgumentParser(description='Ingest experiment run data')
    parser.add_argument('--run_id', required=True, help='Run ID')
    parser.add_argument('--source_dir', default='./temp', help='Source directory with files')
    parser.add_argument('--dry_run', action='store_true', help='Preview actions without executing')
    
    args = parser.parse_args()
    
    # Parse run ID
    try:
        run_info = parse_run_id(args.run_id)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
    
    # Define paths
    dest_dir = Path(f"data/raw/{run_info['date']}/{run_info['subject']}/{run_info['condition']}")
    source_dir = Path(args.source_dir)
    
    # Expected files
    expected_files = [
        f"ppk2_{args.run_id}.csv",
        f"phone_{args.run_id}.csv",
        f"uart_{args.run_id}.log",
        f"meta_{args.run_id}.json"
    ]
    
    # Check source files exist
    missing_files = []
    for filename in expected_files:
        if not (source_dir / filename).exists():
            missing_files.append(filename)
    
    if missing_files:
        print(f"Error: Missing files in {source_dir}:")
        for f in missing_files:
            print(f"  - {f}")
        sys.exit(1)
    
    # Create destination directory
    if not args.dry_run:
        dest_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"{'[DRY RUN] ' if args.dry_run else ''}Ingesting run: {args.run_id}")
    print(f"Source: {source_dir}")
    print(f"Destination: {dest_dir}")
    print("")
    
    # Copy files and calculate checksums
    manifest_lines = []
    manifest_lines.append(f"# Manifest for run_id: {args.run_id}")
    manifest_lines.append(f"# Generated: {datetime.utcnow().isoformat()}Z")
    manifest_lines.append("")
    
    for filename in expected_files:
        source_path = source_dir / filename
        dest_path = dest_dir / filename
        
        # Calculate checksum
        checksum = calculate_sha256(source_path)
        file_size = source_path.stat().st_size
        
        # Copy file
        if not args.dry_run:
            shutil.copy2(source_path, dest_path)
            print(f"✓ Copied: {filename}")
        else:
            print(f"[DRY RUN] Would copy: {filename}")
        
        # Add to manifest
        manifest_lines.append(f"{filename:<50} SHA256:{checksum}  Size:{file_size}")
    
    # Write manifest
    manifest_path = dest_dir / f"manifest_{args.run_id}.txt"
    if not args.dry_run:
        with open(manifest_path, 'w') as f:
            f.write('\n'.join(manifest_lines))
        print(f"✓ Created manifest: {manifest_path}")
    else:
        print(f"[DRY RUN] Would create manifest: {manifest_path}")
    
    # Update catalog.csv
    catalog_path = Path("catalog.csv")
    catalog_entry = {
        'run_id': args.run_id,
        'date': run_info['date'],
        'subject': run_info['subject'],
        'condition': run_info['condition'],
        'path': str(dest_dir),
        'ingested_at': datetime.utcnow().isoformat() + 'Z',
        'status': 'ingested'
    }
    
    if not args.dry_run:
        # Create catalog if doesn't exist
        if not catalog_path.exists():
            with open(catalog_path, 'w') as f:
                f.write("run_id,date,subject,condition,path,ingested_at,status\n")
        
        # Append entry
        with open(catalog_path, 'a') as f:
            f.write(','.join(str(catalog_entry[k]) for k in 
                           ['run_id', 'date', 'subject', 'condition', 'path', 'ingested_at', 'status']))
            f.write('\n')
        print(f"✓ Updated catalog.csv")
    else:
        print(f"[DRY RUN] Would update catalog.csv")
    
    # Set directory to read-only
    if not args.dry_run:
        for file_path in dest_dir.glob(f"*_{args.run_id}.*"):
            os.chmod(file_path, 0o444)  # Read-only for all
        print(f"✓ Set files to READ-ONLY")
    else:
        print(f"[DRY RUN] Would set files to READ-ONLY")
    
    print("")
    print("✅ Ingestion complete!")
    print("")
    print("Next steps:")
    print(f"1. Run quality check: python scripts/qc_run.py --run_id {args.run_id}")
    print(f"2. Backup to cloud storage")
    print(f"3. Update experiment log")

if __name__ == "__main__":
    main()