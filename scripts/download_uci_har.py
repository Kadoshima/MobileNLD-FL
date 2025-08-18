#!/usr/bin/env python3
"""
UCI HARデータセットのダウンロードと解凍
BLE適応広告制御プロジェクト用
"""

import os
import zipfile
import urllib.request
from pathlib import Path

def download_uci_har():
    """Download and extract UCI HAR dataset."""
    
    # URLs
    dataset_url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00240/UCI%20HAR%20Dataset.zip"
    
    # Paths
    data_dir = Path("data/uci_har")
    zip_path = data_dir / "UCI_HAR_Dataset.zip"
    
    # Create directory
    data_dir.mkdir(parents=True, exist_ok=True)
    
    # Download if not exists
    if not zip_path.exists():
        print(f"Downloading UCI HAR Dataset...")
        print(f"URL: {dataset_url}")
        print(f"Destination: {zip_path}")
        
        # Download with progress
        def download_progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            percent = min(downloaded * 100 / total_size, 100)
            print(f"Progress: {percent:.1f}%", end='\r')
        
        urllib.request.urlretrieve(dataset_url, zip_path, download_progress)
        print("\n✓ Download complete!")
    else:
        print(f"Dataset already downloaded: {zip_path}")
    
    # Extract
    extract_dir = data_dir / "UCI HAR Dataset"
    if not extract_dir.exists():
        print(f"Extracting dataset...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(data_dir)
        print("✓ Extraction complete!")
    else:
        print(f"Dataset already extracted: {extract_dir}")
    
    # List contents
    print("\nDataset structure:")
    for root, dirs, files in os.walk(extract_dir):
        level = root.replace(str(extract_dir), '').count(os.sep)
        indent = ' ' * 2 * level
        print(f"{indent}{os.path.basename(root)}/")
        subindent = ' ' * 2 * (level + 1)
        for file in files[:5]:  # Show first 5 files
            print(f"{subindent}{file}")
        if len(files) > 5:
            print(f"{subindent}... and {len(files)-5} more files")
    
    # Dataset info
    print("\n" + "="*50)
    print("UCI HAR Dataset Info:")
    print("="*50)
    print("- 30 subjects (volunteers)")
    print("- 6 activities: WALKING, WALKING_UPSTAIRS, WALKING_DOWNSTAIRS,")
    print("                SITTING, STANDING, LAYING")
    print("- 561 features from accelerometer and gyroscope")
    print("- Sampling rate: 50 Hz")
    print("- Train/Test split: 70%/30%")
    print("="*50)
    
    return extract_dir

if __name__ == "__main__":
    dataset_path = download_uci_har()
    print(f"\n✅ Dataset ready at: {dataset_path}")
    print("\nNext steps:")
    print("1. Run: python scripts/prepare_binary_dataset.py")
    print("2. Run: python scripts/train_har_model.py")