#!/usr/bin/env python3
"""
MHEALTHデータセットの前処理スクリプト
- TXTファイルからpandas DataFrameへ変換
- ECGからRR間隔を抽出
- 3秒窓で特徴量を計算
"""

import os
import numpy as np
import pandas as pd
from scipy import signal
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# 列名定義（MHEALTHデータセットの仕様）
COLUMN_NAMES = [
    'chest_acc_x', 'chest_acc_y', 'chest_acc_z',
    'ecg_1', 'ecg_2',
    'ankle_acc_x', 'ankle_acc_y', 'ankle_acc_z',
    'ankle_gyro_x', 'ankle_gyro_y', 'ankle_gyro_z',
    'ankle_mag_x', 'ankle_mag_y', 'ankle_mag_z',
    'arm_acc_x', 'arm_acc_y', 'arm_acc_z',
    'arm_gyro_x', 'arm_gyro_y', 'arm_gyro_z',
    'arm_mag_x', 'arm_mag_y', 'arm_mag_z',
    'label'
]

SAMPLING_RATE = 50  # Hz

def detect_r_peaks(ecg_signal, fs=50):
    """
    簡易的なR波検出
    NeuroKit2が使えない場合の代替実装
    """
    # バンドパスフィルタ (5-15 Hz)
    b, a = signal.butter(2, [5, 15], btype='band', fs=fs)
    filtered = signal.filtfilt(b, a, ecg_signal)
    
    # 微分
    diff = np.diff(filtered)
    
    # 二乗
    squared = diff ** 2
    
    # 移動平均
    window = int(0.12 * fs)  # 120ms window
    ma = np.convolve(squared, np.ones(window)/window, mode='same')
    
    # 閾値設定とピーク検出
    threshold = np.mean(ma) + 2 * np.std(ma)
    peaks, _ = signal.find_peaks(ma, height=threshold, distance=int(0.4*fs))
    
    return peaks

def extract_rr_intervals(ecg_signal, fs=50):
    """ECG信号からRR間隔を抽出"""
    r_peaks = detect_r_peaks(ecg_signal, fs)
    if len(r_peaks) < 2:
        return np.array([])
    
    # RR間隔をミリ秒単位で計算
    rr_intervals = np.diff(r_peaks) * (1000 / fs)
    
    # 外れ値除去（300ms < RR < 2000ms）
    valid_rr = rr_intervals[(rr_intervals > 300) & (rr_intervals < 2000)]
    
    return valid_rr

def calculate_hrv_features(rr_intervals):
    """HRV特徴量の計算"""
    if len(rr_intervals) < 2:
        return {'rmssd': 0, 'lf_hf_ratio': 0}
    
    # RMSSD
    diff_rr = np.diff(rr_intervals)
    rmssd = np.sqrt(np.mean(diff_rr ** 2))
    
    # 簡易的なLF/HF比（実際の実装では適切な周波数解析が必要）
    # ここでは単純化のため標準偏差の比を使用
    lf_hf_ratio = np.std(rr_intervals) / (rmssd + 1e-6)
    
    return {
        'rmssd': rmssd,
        'lf_hf_ratio': lf_hf_ratio
    }

def extract_window_features(data_window, rr_window):
    """3秒窓から特徴量を抽出"""
    features = {}
    
    # 基本統計量（加速度の大きさ）
    acc_mag = np.sqrt(data_window['chest_acc_x']**2 + 
                      data_window['chest_acc_y']**2 + 
                      data_window['chest_acc_z']**2)
    
    features['acc_mean'] = np.mean(acc_mag)
    features['acc_std'] = np.std(acc_mag)
    features['acc_rms'] = np.sqrt(np.mean(acc_mag**2))
    features['acc_max'] = np.max(acc_mag)
    features['acc_min'] = np.min(acc_mag)
    features['acc_range'] = features['acc_max'] - features['acc_min']
    
    # HRV特徴量
    if len(rr_window) > 0:
        hrv = calculate_hrv_features(rr_window)
        features['hrv_rmssd'] = hrv['rmssd']
        features['hrv_lf_hf'] = hrv['lf_hf_ratio']
    else:
        features['hrv_rmssd'] = 0
        features['hrv_lf_hf'] = 0
    
    # 活動ラベル（最頻値）
    features['label'] = int(data_window['label'].mode()[0])
    
    return features

def process_subject(subject_file):
    """被験者データの処理"""
    print(f"Processing {subject_file.name}...")
    
    # データ読み込み
    data = pd.read_csv(subject_file, sep='\s+', header=None, names=COLUMN_NAMES)
    
    # RR間隔の抽出
    ecg_signal = data['ecg_1'].values
    r_peaks = detect_r_peaks(ecg_signal, SAMPLING_RATE)
    rr_intervals = extract_rr_intervals(ecg_signal, SAMPLING_RATE)
    
    # 3秒窓での特徴抽出（1秒ホップ）
    window_size = 3 * SAMPLING_RATE  # 3秒
    hop_size = 1 * SAMPLING_RATE     # 1秒
    
    features_list = []
    
    for start in range(0, len(data) - window_size, hop_size):
        end = start + window_size
        
        # データ窓
        data_window = data.iloc[start:end]
        
        # 対応するRR間隔を取得
        window_r_peaks = r_peaks[(r_peaks >= start) & (r_peaks < end)]
        if len(window_r_peaks) > 1:
            window_rr = np.diff(window_r_peaks) * (1000 / SAMPLING_RATE)
        else:
            window_rr = np.array([])
        
        # 特徴量抽出
        features = extract_window_features(data_window, window_rr)
        features['window_start'] = start / SAMPLING_RATE  # 秒単位
        features_list.append(features)
    
    # DataFrameに変換
    features_df = pd.DataFrame(features_list)
    
    return features_df

def main():
    """メイン処理"""
    # パス設定
    raw_dir = Path('data/raw/MHEALTHDATASET')
    processed_dir = Path('data/processed')
    processed_dir.mkdir(exist_ok=True)
    
    # 被験者ファイルの処理
    subject_files = sorted(raw_dir.glob('mHealth_subject*.log'))
    
    if not subject_files:
        print("❌ No subject files found. Please run 00_download.sh first.")
        return
    
    print(f"Found {len(subject_files)} subject files")
    
    for subject_file in subject_files:
        # 特徴量抽出
        features_df = process_subject(subject_file)
        
        # 保存
        subject_num = subject_file.stem.split('_')[-1]
        output_file = processed_dir / f'subject_{subject_num}_features.csv'
        features_df.to_csv(output_file, index=False)
        print(f"✅ Saved features to {output_file}")
        
        # RR間隔も別途保存（後の解析用）
        ecg_signal = pd.read_csv(subject_file, sep='\s+', header=None, 
                                 names=COLUMN_NAMES)['ecg_1'].values
        rr_intervals = extract_rr_intervals(ecg_signal, SAMPLING_RATE)
        
        if len(rr_intervals) > 0:
            rr_file = processed_dir / f'subject_{subject_num}_rri.csv'
            pd.DataFrame({'rr_interval_ms': rr_intervals}).to_csv(rr_file, index=False)
            print(f"✅ Saved RR intervals to {rr_file}")
    
    print("\n🎉 Preprocessing completed!")
    print(f"Processed files saved to: {processed_dir}")

if __name__ == "__main__":
    main()