#!/usr/bin/env python3
"""
第3のデータセット取得スクリプト
UCI HAR Dataset（Human Activity Recognition）を使用
"""

import os
import urllib.request
import zipfile
import pandas as pd
import numpy as np

def download_har_dataset():
    """UCI HARデータセットをダウンロード"""
    url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00240/UCI%20HAR%20Dataset.zip"
    
    print("Downloading UCI HAR Dataset...")
    urllib.request.urlretrieve(url, "har_dataset.zip")
    
    print("Extracting...")
    with zipfile.ZipFile("har_dataset.zip", 'r') as zip_ref:
        zip_ref.extractall(".")
    
    print("Dataset downloaded successfully!")
    return "UCI HAR Dataset"

def calculate_kappa_for_har():
    """HARデータセットでκ値を計算"""
    # 加速度データを読み込み
    data_path = "UCI HAR Dataset/train/Inertial Signals/total_acc_x_train.txt"
    
    if not os.path.exists(data_path):
        download_har_dataset()
    
    # データ読み込み
    acc_data = pd.read_csv(data_path, sep='\s+', header=None)
    
    kappa_values = []
    
    for subject in range(len(acc_data)):
        signal = acc_data.iloc[subject].values
        
        # 自己相関関数を計算
        mean = np.mean(signal)
        var = np.var(signal)
        
        rho_k = []
        for k in range(1, 11):  # k=1 to 10
            if k < len(signal):
                autocorr = np.mean((signal[:-k] - mean) * (signal[k:] - mean)) / var
                rho_k.append(autocorr)
        
        # κ値計算
        kappa = 1 + 0.5 * sum(rho_k)
        kappa_values.append(kappa)
    
    # 統計情報
    kappa_mean = np.mean(kappa_values)
    kappa_std = np.std(kappa_values)
    ci_low = kappa_mean - 1.96 * kappa_std / np.sqrt(len(kappa_values))
    ci_high = kappa_mean + 1.96 * kappa_std / np.sqrt(len(kappa_values))
    
    results = f"""
=== UCI HAR Dataset κ値解析結果 ===
サンプル数: {len(kappa_values)}
κ平均値: {kappa_mean:.3f}
標準偏差: {kappa_std:.3f}
95%信頼区間: [{ci_low:.3f}, {ci_high:.3f}]

既存データセットとの比較:
- MHEALTH: κ=1.18 [1.15, 1.21]
- PhysioNet: κ=1.22 [1.19, 1.25]
- UCI HAR: κ={kappa_mean:.2f} [{ci_low:.2f}, {ci_high:.2f}]
"""
    
    print(results)
    
    # ファイルに保存
    with open("kappa_analysis_har.txt", "w") as f:
        f.write(results)
    
    return kappa_mean, ci_low, ci_high

if __name__ == "__main__":
    calculate_kappa_for_har()