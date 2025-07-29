#!/bin/bash
# MHEALTHデータセットをダウンロード・解凍するスクリプト

echo "📥 Downloading MHEALTH dataset..."

# データディレクトリ作成
mkdir -p data/raw

# MHEALTHデータセットをダウンロード
if [ ! -f "data/raw/mhealth+dataset.zip" ]; then
    echo "Downloading from UCI repository..."
    curl -L "https://archive.ics.uci.edu/static/public/319/mhealth+dataset.zip" -o "data/raw/mhealth+dataset.zip"
else
    echo "Dataset already downloaded."
fi

# 解凍
if [ ! -d "data/raw/MHEALTH_Dataset" ]; then
    echo "Extracting dataset..."
    unzip -q data/raw/mhealth+dataset.zip -d data/raw/
    mv data/raw/mHealth_subject* data/raw/MHEALTH_Dataset/ 2>/dev/null || mkdir -p data/raw/MHEALTH_Dataset && mv data/raw/mHealth_subject* data/raw/MHEALTH_Dataset/
else
    echo "Dataset already extracted."
fi

echo "✅ Dataset ready at: data/raw/MHEALTH_Dataset/"
echo ""
echo "Dataset info:"
echo "- 10 subjects"
echo "- 23 sensor channels"
echo "- Activities: L1-L12"
echo "- Sampling rate: 50Hz"