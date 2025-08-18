#!/bin/bash
# Python環境セットアップスクリプト
# BLE適応広告制御プロジェクト用

set -e

echo "==================================="
echo "Python環境セットアップ開始"
echo "==================================="

# Python version check
PYTHON_VERSION=$(python3 --version 2>&1 | grep -Po '(?<=Python )\d+\.\d+')
echo "Python version: $PYTHON_VERSION"

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install required packages
echo "Installing required packages..."
pip install tensorflow==2.13.0
pip install scikit-learn==1.3.0
pip install pandas==2.0.3
pip install numpy==1.24.3
pip install matplotlib==3.7.2
pip install seaborn==0.12.2
pip install scipy==1.11.1
pip install jupyter==1.0.0
pip install notebook==7.0.2

# For data processing
pip install h5py==3.9.0
pip install tables==3.8.0

# For TensorFlow Lite
pip install tflite==2.13.0
pip install flatbuffers==23.5.26

# For power analysis
pip install pyserial==3.5  # For UART communication

echo ""
echo "==================================="
echo "インストール完了パッケージ:"
echo "==================================="
pip list

echo ""
echo "==================================="
echo "セットアップ完了!"
echo "==================================="
echo "仮想環境を有効化するには:"
echo "  source venv/bin/activate"
echo ""
echo "Jupyterを起動するには:"
echo "  jupyter notebook"
echo "==================================="