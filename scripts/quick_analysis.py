import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime
import sys

def analyze_ble_log(csv_path):
    """BLEログの簡易解析"""
    # CSVを読み込み（科学的記数法を避けるため float_precision を指定）
    df = pd.read_csv(csv_path, float_precision='round_trip')
    print(f"データ件数: {len(df)}")
    
    # タイムスタンプが科学的記数法の場合の対処
    if df['timestamp_phone_unix_ms'].dtype == 'object' or df['timestamp_phone_unix_ms'].astype(str).str.contains('E').any():
        df['timestamp_phone_unix_ms'] = pd.to_numeric(df['timestamp_phone_unix_ms'])
    
    # タイムスタンプを datetime に変換
    df['timestamp'] = pd.to_datetime(df['timestamp_phone_unix_ms'], unit='ms')
    
    # 受信間隔を計算（ミリ秒） - 既存の interval_ms カラムがあるか確認
    if 'interval_ms' not in df.columns:
        df['interval_ms_calc'] = df['timestamp_phone_unix_ms'].diff()
    else:
        df['interval_ms_calc'] = df['interval_ms']
    
    # 基本統計（計算した間隔を使用）
    print("\n=== 受信間隔統計 ===")
    print(f"平均: {df['interval_ms_calc'].mean():.1f} ms")
    print(f"中央値 (p50): {df['interval_ms_calc'].median():.1f} ms")
    print(f"p95: {df['interval_ms_calc'].quantile(0.95):.1f} ms")
    print(f"最大: {df['interval_ms_calc'].max():.1f} ms")
    
    # パケット損失推定（200ms以上の間隔をカウント）
    lost_packets = (df['interval_ms_calc'] > 200).sum()
    loss_rate = lost_packets / len(df) * 100
    print(f"\n推定パケット損失: {lost_packets} ({loss_rate:.1f}%)")
    
    # 測定時間
    duration_min = (df['timestamp'].max() - df['timestamp'].min()).total_seconds() / 60
    print(f"\n測定時間: {duration_min:.1f} 分")
    
    # 期待パケット数（100ms間隔の場合）
    if duration_min > 0:
        expected_packets = duration_min * 60 * 10  # 10 packets/sec
        actual_packets = len(df)
        print(f"期待パケット数: {expected_packets:.0f}")
        print(f"実際のパケット数: {actual_packets}")
        print(f"受信率: {actual_packets/expected_packets*100:.1f}%")
    else:
        print("測定時間が0のため受信率を計算できません")
    
    # グラフ作成
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
    
    # 受信間隔の時系列
    ax1.plot(df['timestamp'], df['interval_ms_calc'])
    ax1.set_ylabel('受信間隔 (ms)')
    ax1.set_title('BLE パケット受信間隔の推移')
    ax1.axhline(y=100, color='r', linestyle='--', label='期待値 100ms')
    ax1.axhline(y=200, color='orange', linestyle='--', label='損失閾値 200ms')
    ax1.legend()
    ax1.grid(True)
    
    # 受信間隔のヒストグラム
    ax2.hist(df['interval_ms_calc'].dropna(), bins=50, edgecolor='black')
    ax2.set_xlabel('受信間隔 (ms)')
    ax2.set_ylabel('頻度')
    ax2.set_title('受信間隔の分布')
    ax2.axvline(x=100, color='r', linestyle='--', label='期待値 100ms')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('analysis_result.png')
    print("\n結果を analysis_result.png に保存しました")
    
    # 活動状態の確認（加速度データがある場合）
    if 'state' in df.columns:
        print("\n=== 活動状態 ===")
        state_counts = df['state'].value_counts()
        for state, count in state_counts.items():
            state_name = ['IDLE', 'ACTIVE', 'UNCERTAIN'][state] if state in [0,1,2] else f'Unknown({state})'
            print(f"{state_name}: {count} ({count/len(df)*100:.1f}%)")
    
    return df

if __name__ == "__main__":
    if len(sys.argv) > 1:
        csv_path = sys.argv[1]
    else:
        # デフォルトパス（適宜変更）
        csv_path = input("CSVファイルのパスを入力: ")
    
    analyze_ble_log(csv_path)