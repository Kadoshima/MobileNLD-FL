#!/usr/bin/env python3
"""
Download UCI HAR Dataset for Human Activity Recognition
"""

import os
import zipfile
import urllib.request
from pathlib import Path

def download_uci_har():
    """Download and extract UCI HAR dataset"""
    
    # Dataset URL
    url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00240/UCI%20HAR%20Dataset.zip"
    
    # Create data directory
    data_dir = Path("../data/uci_har")
    data_dir.mkdir(parents=True, exist_ok=True)
    
    # Download file
    zip_path = data_dir / "uci_har.zip"
    
    if not zip_path.exists():
        print(f"Downloading UCI HAR dataset from {url}...")
        urllib.request.urlretrieve(url, zip_path)
        print("Download complete!")
    else:
        print("Dataset already downloaded.")
    
    # Extract zip file
    extract_dir = data_dir / "UCI_HAR_Dataset"
    if not extract_dir.exists():
        print("Extracting dataset...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(data_dir)
        print("Extraction complete!")
    else:
        print("Dataset already extracted.")
    
    # Print dataset info
    print(f"\nDataset location: {extract_dir.absolute()}")
    print("\nDataset structure:")
    print("- train/: Training data (7352 samples, 70%)")
    print("- test/: Test data (2947 samples, 30%)")
    print("- activity_labels.txt: Activity class labels")
    print("- features.txt: Feature names (561 features)")
    print("\nActivity classes:")
    print("1. WALKING")
    print("2. WALKING_UPSTAIRS")
    print("3. WALKING_DOWNSTAIRS")
    print("4. SITTING")
    print("5. STANDING")
    print("6. LAYING")

if __name__ == "__main__":
    download_uci_har()