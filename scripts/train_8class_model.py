#!/usr/bin/env python3
"""
Train detailed 8-class model for M5Stack
"""

import numpy as np
import tensorflow as tf
from pathlib import Path
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns

def load_uci_har_data():
    """Load UCI HAR dataset for 8-class classification"""
    
    data_dir = Path("../data/uci_har/UCI_HAR_Dataset")
    
    # Load training data
    X_train = np.loadtxt(data_dir / "train/X_train.txt")
    y_train = np.loadtxt(data_dir / "train/y_train.txt") - 1  # Convert to 0-indexed
    
    # Load test data
    X_test = np.loadtxt(data_dir / "test/X_test.txt")
    y_test = np.loadtxt(data_dir / "test/y_test.txt") - 1  # Convert to 0-indexed
    
    # Activity labels
    activities = [
        "Walking", "Walking_Upstairs", "Walking_Downstairs",
        "Sitting", "Standing", "Laying"
    ]
    
    # We'll add synthetic data for Running and Jumping later
    # For now, work with 6 classes from UCI HAR
    
    print(f"Training samples: {X_train.shape[0]}")
    print(f"Test samples: {X_test.shape[0]}")
    print(f"Features: {X_train.shape[1]}")
    print(f"Classes: {len(np.unique(y_train))}")
    
    return X_train, y_train, X_test, y_test, activities

def create_8class_model(input_shape, num_classes):
    """Create 8-class model for detailed activity recognition"""
    
    model = tf.keras.Sequential([
        tf.keras.layers.Dense(128, activation='relu', input_shape=(input_shape,)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

def select_important_features(X_train, X_test, n_features=50):
    """Select most important features using variance threshold"""
    
    from sklearn.feature_selection import SelectKBest, f_classif
    
    # Select top n features based on ANOVA F-value
    selector = SelectKBest(f_classif, k=n_features)
    X_train_selected = selector.fit_transform(X_train, y_train)
    X_test_selected = selector.transform(X_test)
    
    # Get selected feature indices
    feature_indices = selector.get_support(indices=True)
    
    return X_train_selected, X_test_selected, feature_indices

def augment_data_for_8_classes(X_train, y_train, X_test, y_test):
    """Augment dataset to simulate 8 classes (add Running and Jumping)"""
    
    # Simulate Running as faster Walking with higher variance
    walking_indices = np.where(y_train == 0)[0]
    n_running = len(walking_indices) // 2
    running_data = X_train[walking_indices[:n_running]] * 1.5 + np.random.normal(0, 0.1, X_train[walking_indices[:n_running]].shape)
    running_labels = np.full(n_running, 6)  # Class 6 = Running
    
    # Simulate Jumping as high-variance combination of Walking_Upstairs and Walking_Downstairs
    upstairs_indices = np.where(y_train == 1)[0]
    downstairs_indices = np.where(y_train == 2)[0]
    n_jumping = min(len(upstairs_indices), len(downstairs_indices)) // 3
    jumping_data = (X_train[upstairs_indices[:n_jumping]] + X_train[downstairs_indices[:n_jumping]]) / 2
    jumping_data *= 1.8 + np.random.normal(0, 0.2, jumping_data.shape)
    jumping_labels = np.full(n_jumping, 7)  # Class 7 = Jumping
    
    # Combine original and augmented data
    X_train_aug = np.vstack([X_train, running_data, jumping_data])
    y_train_aug = np.hstack([y_train, running_labels, jumping_labels])
    
    # Add some test samples for new classes
    test_running = X_test[np.where(y_test == 0)[0][:50]] * 1.5 + np.random.normal(0, 0.1, (50, X_test.shape[1]))
    test_jumping = (X_test[np.where(y_test == 1)[0][:25]] + X_test[np.where(y_test == 2)[0][:25]]) / 2 * 1.8
    
    X_test_aug = np.vstack([X_test, test_running, test_jumping])
    y_test_aug = np.hstack([y_test, np.full(50, 6), np.full(25, 7)])
    
    activities_8 = [
        "Walking", "Walking_Upstairs", "Walking_Downstairs",
        "Sitting", "Standing", "Laying", "Running", "Jumping"
    ]
    
    return X_train_aug, y_train_aug, X_test_aug, y_test_aug, activities_8

def quantize_model(model, X_test):
    """Quantize model for TensorFlow Lite Micro"""
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    def representative_dataset():
        for i in range(min(100, len(X_test))):
            yield [X_test[i:i+1].astype(np.float32)]
    
    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.int8
    converter.inference_output_type = tf.int8
    
    tflite_model = converter.convert()
    return tflite_model

def plot_confusion_matrix(y_true, y_pred, activities, save_path):
    """Plot and save confusion matrix"""
    
    cm = confusion_matrix(y_true, y_pred)
    
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                xticklabels=activities, yticklabels=activities)
    plt.title('Confusion Matrix - 8-Class HAR Model')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.tight_layout()
    plt.savefig(save_path)
    plt.close()
    
    return cm

def main():
    """Main training pipeline"""
    
    print("Loading UCI HAR dataset...")
    X_train, y_train, X_test, y_test, activities = load_uci_har_data()
    
    print("\nAugmenting data for 8 classes...")
    X_train, y_train, X_test, y_test, activities_8 = augment_data_for_8_classes(
        X_train, y_train, X_test, y_test
    )
    print(f"Augmented training samples: {X_train.shape[0]}")
    print(f"Classes: {activities_8}")
    
    # Feature selection
    print("\nSelecting important features...")
    X_train_selected, X_test_selected, feature_indices = select_important_features(
        X_train, X_test, n_features=50
    )
    print(f"Selected features: {X_train_selected.shape[1]}")
    
    # Normalize data
    mean = X_train_selected.mean(axis=0)
    std = X_train_selected.std(axis=0)
    X_train_norm = (X_train_selected - mean) / (std + 1e-8)
    X_test_norm = (X_test_selected - mean) / (std + 1e-8)
    
    # Create and train model
    print("\nCreating 8-class model...")
    model = create_8class_model(X_train_norm.shape[1], num_classes=8)
    model.summary()
    
    # Callbacks
    early_stopping = tf.keras.callbacks.EarlyStopping(
        monitor='val_loss', patience=5, restore_best_weights=True
    )
    
    print("\nTraining model...")
    history = model.fit(
        X_train_norm, y_train,
        validation_split=0.2,
        epochs=50,
        batch_size=64,
        callbacks=[early_stopping],
        verbose=1
    )
    
    # Evaluate model
    print("\nEvaluating model...")
    test_loss, test_acc = model.evaluate(X_test_norm, y_test)
    print(f"Test accuracy: {test_acc:.4f}")
    
    # Predictions and classification report
    y_pred = model.predict(X_test_norm).argmax(axis=1)
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=activities_8))
    
    # Save results
    model_dir = Path("../models")
    model_dir.mkdir(exist_ok=True)
    results_dir = Path("../results/figures")
    results_dir.mkdir(parents=True, exist_ok=True)
    
    # Save Keras model
    model.save(model_dir / "8class_model.h5")
    print(f"\nKeras model saved to {model_dir / '8class_model.h5'}")
    
    # Plot confusion matrix
    cm = plot_confusion_matrix(y_test, y_pred, activities_8, 
                               results_dir / "confusion_matrix_8class.png")
    print(f"Confusion matrix saved to {results_dir / 'confusion_matrix_8class.png'}")
    
    # Quantize model
    print("\nQuantizing model for TFLite Micro...")
    tflite_model = quantize_model(model, X_test_norm)
    
    tflite_path = model_dir / "8class_model.tflite"
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"TFLite model saved to {tflite_path}")
    print(f"Model size: {len(tflite_model) / 1024:.2f} KB")
    
    # Save preprocessing parameters
    np.savez(model_dir / "8class_preprocessing.npz", 
             mean=mean, std=std, feature_indices=feature_indices)
    print("Preprocessing parameters saved")
    
    # Generate C header file
    print("\nGenerating C header file...")
    with open(model_dir / "8class_model.h", 'w') as f:
        f.write("// Auto-generated TFLite model for M5Stack (8-class HAR)\n")
        f.write(f"const unsigned int model_8class_len = {len(tflite_model)};\n")
        f.write("const unsigned char model_8class[] = {\n")
        for i, byte in enumerate(tflite_model):
            if i % 12 == 0:
                f.write("  ")
            f.write(f"0x{byte:02x}, ")
            if (i + 1) % 12 == 0:
                f.write("\n")
        f.write("\n};\n")
    
    print("C header file generated successfully!")
    
    # Plot training history
    plt.figure(figsize=(12, 4))
    
    plt.subplot(1, 2, 1)
    plt.plot(history.history['loss'], label='Training Loss')
    plt.plot(history.history['val_loss'], label='Validation Loss')
    plt.title('Model Loss')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.legend()
    
    plt.subplot(1, 2, 2)
    plt.plot(history.history['accuracy'], label='Training Accuracy')
    plt.plot(history.history['val_accuracy'], label='Validation Accuracy')
    plt.title('Model Accuracy')
    plt.xlabel('Epoch')
    plt.ylabel('Accuracy')
    plt.legend()
    
    plt.tight_layout()
    plt.savefig(results_dir / "training_history_8class.png")
    plt.close()
    
    print(f"Training history saved to {results_dir / 'training_history_8class.png'}")
    print("\nTraining complete! 8-class model ready for deployment.")

if __name__ == "__main__":
    main()