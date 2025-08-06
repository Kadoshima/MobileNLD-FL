#!/usr/bin/env python3
"""
Train lightweight 2-class model (Active/Idle) for M5Stack
"""

import numpy as np
import tensorflow as tf
from pathlib import Path
import pandas as pd

def load_uci_har_data():
    """Load and preprocess UCI HAR dataset for 2-class classification"""
    
    data_dir = Path("../data/uci_har/UCI_HAR_Dataset")
    
    # Load training data
    X_train = np.loadtxt(data_dir / "train/X_train.txt")
    y_train = np.loadtxt(data_dir / "train/y_train.txt")
    
    # Load test data
    X_test = np.loadtxt(data_dir / "test/X_test.txt")
    y_test = np.loadtxt(data_dir / "test/y_test.txt")
    
    # Convert to 2-class: Active (1,2,3,7) vs Idle (4,5,6)
    # 1=Walking, 2=Walking_Upstairs, 3=Walking_Downstairs, 
    # 4=Sitting, 5=Standing, 6=Laying, 7=Running (if exists)
    
    y_train_2class = np.where(np.isin(y_train, [1, 2, 3]), 1, 0)  # 1=Active, 0=Idle
    y_test_2class = np.where(np.isin(y_test, [1, 2, 3]), 1, 0)
    
    print(f"Training samples: {X_train.shape[0]}")
    print(f"Test samples: {X_test.shape[0]}")
    print(f"Features: {X_train.shape[1]}")
    print(f"Active samples in training: {np.sum(y_train_2class)}")
    print(f"Idle samples in training: {len(y_train_2class) - np.sum(y_train_2class)}")
    
    return X_train, y_train_2class, X_test, y_test_2class

def create_lightweight_model(input_shape):
    """Create a lightweight 2-class model suitable for M5Stack"""
    
    model = tf.keras.Sequential([
        # Use only 6 key features (mean accelerometer XYZ, std accelerometer XYZ)
        tf.keras.layers.Dense(16, activation='relu', input_shape=(input_shape,)),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(8, activation='relu'),
        tf.keras.layers.Dense(2, activation='softmax')
    ])
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

def select_key_features(X, feature_indices=None):
    """Select only key features to reduce model size"""
    
    if feature_indices is None:
        # Select indices for mean and std of accelerometer data
        # These are typically the first 6 features in UCI HAR
        feature_indices = list(range(6))  # Simplified feature selection
    
    return X[:, feature_indices]

def quantize_model(model, X_test):
    """Quantize model for TensorFlow Lite Micro"""
    
    # Convert to TFLite with quantization
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Representative dataset for full integer quantization
    def representative_dataset():
        for i in range(100):
            yield [X_test[i:i+1].astype(np.float32)]
    
    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.int8
    converter.inference_output_type = tf.int8
    
    tflite_model = converter.convert()
    
    return tflite_model

def main():
    """Main training pipeline"""
    
    print("Loading UCI HAR dataset...")
    X_train, y_train, X_test, y_test = load_uci_har_data()
    
    # Select key features
    print("\nSelecting key features...")
    X_train_selected = select_key_features(X_train)
    X_test_selected = select_key_features(X_test)
    print(f"Selected features: {X_train_selected.shape[1]}")
    
    # Normalize data
    mean = X_train_selected.mean(axis=0)
    std = X_train_selected.std(axis=0)
    X_train_norm = (X_train_selected - mean) / std
    X_test_norm = (X_test_selected - mean) / std
    
    # Create and train model
    print("\nCreating lightweight model...")
    model = create_lightweight_model(X_train_norm.shape[1])
    model.summary()
    
    print("\nTraining model...")
    history = model.fit(
        X_train_norm, y_train,
        validation_split=0.2,
        epochs=20,
        batch_size=32,
        verbose=1
    )
    
    # Evaluate model
    print("\nEvaluating model...")
    test_loss, test_acc = model.evaluate(X_test_norm, y_test)
    print(f"Test accuracy: {test_acc:.4f}")
    
    # Save Keras model
    model_dir = Path("../models")
    model_dir.mkdir(exist_ok=True)
    model.save(model_dir / "2class_model.h5")
    print(f"\nKeras model saved to {model_dir / '2class_model.h5'}")
    
    # Quantize and save TFLite model
    print("\nQuantizing model for TFLite Micro...")
    tflite_model = quantize_model(model, X_test_norm)
    
    tflite_path = model_dir / "2class_model.tflite"
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"TFLite model saved to {tflite_path}")
    print(f"Model size: {len(tflite_model) / 1024:.2f} KB")
    
    # Save normalization parameters
    np.savez(model_dir / "2class_norm_params.npz", mean=mean, std=std)
    print("Normalization parameters saved")
    
    # Generate C header file for M5Stack
    print("\nGenerating C header file...")
    with open(model_dir / "2class_model.h", 'w') as f:
        f.write("// Auto-generated TFLite model for M5Stack\n")
        f.write(f"const unsigned int model_2class_len = {len(tflite_model)};\n")
        f.write("const unsigned char model_2class[] = {\n")
        for i, byte in enumerate(tflite_model):
            if i % 12 == 0:
                f.write("  ")
            f.write(f"0x{byte:02x}, ")
            if (i + 1) % 12 == 0:
                f.write("\n")
        f.write("\n};\n")
    
    print("C header file generated successfully!")
    print("\nTraining complete! Model ready for deployment on M5Stack.")

if __name__ == "__main__":
    main()