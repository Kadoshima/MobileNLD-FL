#!/usr/bin/env python3
"""
PhysioNet CHB-MIT Scalp EEG Databaseのダウンロードと変換スクリプト
実験計画 5.4 SIMD Optimization Effect Evaluation用

データソース: https://physionet.org/content/chbmit/1.0.0/
対象ファイル: chb01_03.edf (5分脳波データ, 256Hzサンプリング)
"""

import os
import requests
import pandas as pd
import numpy as np
import argparse

# PhysioNetデータのダウンロード用にwfdbパッケージを使用
try:
    import wfdb
except ImportError:
    print("WFDB package not installed. Installing...")
    import subprocess
    subprocess.check_call(["pip", "install", "wfdb"])
    import wfdb

def download_chb_mit_data(patient='chb01', record='chb01_03', output_dir='../data/physionet'):
    """
    CHB-MIT EEGデータをダウンロード
    
    Args:
        patient: 患者ID (例: 'chb01')
        record: レコードID (例: 'chb01_03')
        output_dir: 出力ディレクトリ
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # PhysioNetからデータをダウンロード
    database = 'chbmit'
    path = f'{patient}/'
    
    print(f"Downloading {record} from PhysioNet CHB-MIT database...")
    
    try:
        # レコードをダウンロード
        record_data = wfdb.rdrecord(record, pn_dir=f'{database}/{path}')
        
        # アノテーションがある場合はダウンロード
        try:
            annotation = wfdb.rdann(record, 'seizure', pn_dir=f'{database}/{path}')
            has_annotation = True
        except:
            has_annotation = False
            print("No seizure annotations found for this record")
        
        return record_data, annotation if has_annotation else None
        
    except Exception as e:
        print(f"Error downloading data: {e}")
        print("Alternative: Please download manually from https://physionet.org/content/chbmit/1.0.0/")
        return None, None

def convert_to_csv(record_data, output_dir, record_name):
    """
    WFDBレコードをCSVに変換
    """
    if record_data is None:
        return None
    
    # データの取得
    signals = record_data.p_signal
    channel_names = record_data.sig_name
    fs = record_data.fs
    
    print(f"Record info:")
    print(f"  Sampling rate: {fs} Hz")
    print(f"  Duration: {len(signals) / fs:.1f} seconds")
    print(f"  Channels: {len(channel_names)}")
    print(f"  Signal shape: {signals.shape}")
    
    # DataFrameの作成
    df = pd.DataFrame(signals, columns=channel_names)
    
    # 時間軸の追加
    time = np.arange(len(signals)) / fs
    df.insert(0, 'time', time)
    
    # CSVとして保存
    csv_path = os.path.join(output_dir, f"{record_name}.csv")
    df.to_csv(csv_path, index=False, float_format='%.6f')
    print(f"Saved full data to: {csv_path}")
    
    # Q15形式に変換したデータも保存
    # 各チャンネルの最大絶対値で正規化
    max_abs = np.max(np.abs(signals), axis=0)
    normalized = signals / max_abs
    
    # Q15スケール
    q15_scale = 32767
    q15_data = (normalized * q15_scale).astype(np.int16)
    
    # Q15データの保存
    q15_df = pd.DataFrame(q15_data, columns=[f"{ch}_q15" for ch in channel_names])
    q15_df.insert(0, 'time', time)
    
    # スケール情報も追加
    for i, ch in enumerate(channel_names):
        q15_df[f"{ch}_scale"] = max_abs[i]
    
    q15_path = os.path.join(output_dir, f"{record_name}_q15.csv")
    q15_df.to_csv(q15_path, index=False)
    print(f"Saved Q15 data to: {q15_path}")
    
    return df, fs, channel_names

def extract_windows(df, fs, window_duration=3.0, overlap=0.5):
    """
    データを指定した長さのウィンドウに分割
    
    Args:
        df: データフレーム
        fs: サンプリングレート
        window_duration: ウィンドウの長さ（秒）
        overlap: オーバーラップ率（0-1）
    """
    window_samples = int(window_duration * fs)
    step_samples = int(window_samples * (1 - overlap))
    
    windows = []
    num_samples = len(df)
    
    start = 0
    while start + window_samples <= num_samples:
        window = df.iloc[start:start + window_samples].copy()
        window.reset_index(drop=True, inplace=True)
        windows.append(window)
        start += step_samples
    
    return windows

def save_sample_windows(df, fs, output_dir, record_name, num_samples=10):
    """
    実験用のサンプルウィンドウを保存
    """
    # 3秒ウィンドウを抽出
    windows = extract_windows(df, fs, window_duration=3.0, overlap=0.5)
    
    print(f"\nExtracted {len(windows)} windows")
    
    # サンプルウィンドウの保存
    sample_dir = os.path.join(output_dir, 'sample_windows')
    os.makedirs(sample_dir, exist_ok=True)
    
    # 最初のnum_samplesウィンドウを保存
    for i in range(min(num_samples, len(windows))):
        window_path = os.path.join(sample_dir, f"{record_name}_window_{i:04d}.csv")
        windows[i].to_csv(window_path, index=False, float_format='%.6f')
    
    print(f"Saved {min(num_samples, len(windows))} sample windows to {sample_dir}")

def create_summary(record_data, annotation, output_dir, record_name):
    """
    データの要約情報を作成
    """
    if record_data is None:
        return
    
    summary = {
        'record_name': record_name,
        'sampling_rate_hz': record_data.fs,
        'duration_seconds': record_data.sig_len / record_data.fs,
        'num_channels': record_data.n_sig,
        'channels': record_data.sig_name,
        'num_samples': record_data.sig_len,
    }
    
    if annotation is not None:
        summary['seizure_start_times'] = annotation.sample / record_data.fs
        summary['seizure_durations'] = annotation.aux_note
    
    # 統計情報
    signals = record_data.p_signal
    summary['signal_stats'] = {}
    for i, ch in enumerate(record_data.sig_name):
        summary['signal_stats'][ch] = {
            'min': float(signals[:, i].min()),
            'max': float(signals[:, i].max()),
            'mean': float(signals[:, i].mean()),
            'std': float(signals[:, i].std())
        }
    
    # JSON形式で保存
    import json
    summary_path = os.path.join(output_dir, f"{record_name}_summary.json")
    with open(summary_path, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\nSaved summary to: {summary_path}")

def main():
    parser = argparse.ArgumentParser(description='Download and convert PhysioNet CHB-MIT EEG data')
    parser.add_argument('--patient', type=str, default='chb01',
                       help='Patient ID (default: chb01)')
    parser.add_argument('--record', type=str, default='chb01_03',
                       help='Record ID (default: chb01_03)')
    parser.add_argument('--output-dir', type=str, default='../data/physionet',
                       help='Output directory (default: ../data/physionet)')
    parser.add_argument('--sample-windows', type=int, default=10,
                       help='Number of sample windows to extract (default: 10)')
    
    args = parser.parse_args()
    
    # データのダウンロード
    record_data, annotation = download_chb_mit_data(
        patient=args.patient,
        record=args.record,
        output_dir=args.output_dir
    )
    
    if record_data is not None:
        # CSVに変換
        df, fs, channels = convert_to_csv(record_data, args.output_dir, args.record)
        
        # サンプルウィンドウの保存
        save_sample_windows(df, fs, args.output_dir, args.record, args.sample_windows)
        
        # 要約情報の作成
        create_summary(record_data, annotation, args.output_dir, args.record)
        
        print("\nData processing completed successfully!")
    else:
        print("\nFailed to download data. Please check your internet connection or download manually.")

if __name__ == "__main__":
    main()