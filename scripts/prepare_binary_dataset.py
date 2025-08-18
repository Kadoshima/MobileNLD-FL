#!/usr/bin/env python3
"""
UCI HARデータセットを2クラス（Active/Idle）に変換
BLE適応広告制御プロジェクト用
"""

import numpy as np
import pandas as pd
from pathlib import Path
import json

def load_uci_har_data(dataset_path):
    """Load UCI HAR dataset."""
    
    print("Loading UCI HAR dataset...")
    
    # Load training data
    X_train = np.loadtxt(dataset_path / "train" / "X_train.txt")
    y_train = np.loadtxt(dataset_path / "train" / "y_train.txt")
    
    # Load test data
    X_test = np.loadtxt(dataset_path / "test" / "X_test.txt")
    y_test = np.loadtxt(dataset_path / "test" / "y_test.txt")
    
    # Load activity labels
    activity_labels = pd.read_csv(
        dataset_path / "activity_labels.txt",
        sep=' ',
        header=None,
        names=['id', 'activity']
    )
    
    print(f"✓ Loaded train: {X_train.shape[0]} samples")
    print(f"✓ Loaded test: {X_test.shape[0]} samples")
    print(f"✓ Features: {X_train.shape[1]}")
    
    return X_train, y_train, X_test, y_test, activity_labels

def convert_to_binary(y, activity_labels):
    """
    Convert 6-class labels to 2-class (Active/Idle).
    
    Active (1): WALKING, WALKING_UPSTAIRS, WALKING_DOWNSTAIRS
    Idle (0): SITTING, STANDING, LAYING
    """
    
    # Define active activities (1, 2, 3)
    active_ids = [1, 2, 3]  # WALKING, WALKING_UPSTAIRS, WALKING_DOWNSTAIRS
    
    # Convert to binary
    y_binary = np.zeros_like(y)
    for active_id in active_ids:
        y_binary[y == active_id] = 1
    
    # Count samples
    active_count = np.sum(y_binary == 1)
    idle_count = np.sum(y_binary == 0)
    
    print(f"\nBinary conversion:")
    print(f"  Active samples: {active_count} ({active_count/len(y)*100:.1f}%)")
    print(f"  Idle samples: {idle_count} ({idle_count/len(y)*100:.1f}%)")
    
    return y_binary

def select_imu_features(X):
    """
    Select only IMU-related features (accelerometer + gyroscope).
    From 561 features, select first 6 raw signals or computed features.
    """
    
    # For simplicity, use first 6 features (typically tBodyAcc-XYZ, tBodyGyro-XYZ)
    # In practice, you might want to select specific feature indices
    
    # Indices for body acceleration and gyroscope (example)
    # These would need to be verified against feature_info.txt
    selected_indices = list(range(6))  # First 6 features as example
    
    X_imu = X[:, selected_indices]
    
    print(f"✓ Selected {X_imu.shape[1]} IMU features from {X.shape[1]} total features")
    
    return X_imu

def save_binary_dataset(X_train, y_train, X_test, y_test, output_dir):
    """Save processed dataset."""
    
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save as numpy arrays
    np.save(output_dir / "X_train_binary.npy", X_train)
    np.save(output_dir / "y_train_binary.npy", y_train)
    np.save(output_dir / "X_test_binary.npy", X_test)
    np.save(output_dir / "y_test_binary.npy", y_test)
    
    # Save metadata
    metadata = {
        "num_classes": 2,
        "classes": ["Idle", "Active"],
        "num_features": X_train.shape[1],
        "train_samples": int(X_train.shape[0]),
        "test_samples": int(X_test.shape[0]),
        "train_active_ratio": float(np.mean(y_train)),
        "test_active_ratio": float(np.mean(y_test))
    }
    
    with open(output_dir / "metadata.json", 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"\n✓ Saved binary dataset to: {output_dir}")
    print(f"  - X_train_binary.npy: {X_train.shape}")
    print(f"  - y_train_binary.npy: {y_train.shape}")
    print(f"  - X_test_binary.npy: {X_test.shape}")
    print(f"  - y_test_binary.npy: {y_test.shape}")
    print(f"  - metadata.json")

def main():
    """Main processing pipeline."""
    
    print("="*60)
    print("UCI HAR → Binary (Active/Idle) Dataset Conversion")
    print("="*60)
    
    # Paths
    dataset_path = Path("data/uci_har/UCI HAR Dataset")
    output_dir = Path("data/binary_har")
    
    # Check if dataset exists
    if not dataset_path.exists():
        print(f"Error: Dataset not found at {dataset_path}")
        print("Please run: python scripts/download_uci_har.py")
        return
    
    # Load data
    X_train, y_train, X_test, y_test, activity_labels = load_uci_har_data(dataset_path)
    
    # Convert to binary
    y_train_binary = convert_to_binary(y_train, activity_labels)
    y_test_binary = convert_to_binary(y_test, activity_labels)
    
    # Select IMU features (optional - for now use all)
    # X_train_imu = select_imu_features(X_train)
    # X_test_imu = select_imu_features(X_test)
    
    # For now, keep all features
    X_train_imu = X_train
    X_test_imu = X_test
    
    # Save dataset
    save_binary_dataset(
        X_train_imu, y_train_binary,
        X_test_imu, y_test_binary,
        output_dir
    )
    
    print("\n" + "="*60)
    print("✅ Binary dataset preparation complete!")
    print("="*60)
    print("\nNext steps:")
    print("1. Run: python scripts/train_har_model.py")
    print("2. Run: python scripts/quantize_model.py")

if __name__ == "__main__":
    main()