import pandas as pd
import numpy as np
import glob
import os
from datetime import datetime

def analyze_ble_log(csv_path):
    """BLEログの解析"""
    try:
        # CSVを読み込み
        df = pd.read_csv(csv_path, float_precision='round_trip')
        
        # タイムスタンプが科学的記数法の場合の対処
        if 'timestamp_phone_unix_ms' in df.columns:
            df['timestamp_phone_unix_ms'] = pd.to_numeric(df['timestamp_phone_unix_ms'])
            df['timestamp'] = pd.to_datetime(df['timestamp_phone_unix_ms'], unit='ms')
        
        # 受信間隔を計算
        if 'interval_ms' not in df.columns:
            df['interval_ms_calc'] = df['timestamp_phone_unix_ms'].diff()
        else:
            df['interval_ms_calc'] = df['interval_ms']
        
        # 測定時間
        duration_min = (df['timestamp'].max() - df['timestamp'].min()).total_seconds() / 60
        
        # 統計値計算
        stats = {
            'file': os.path.basename(csv_path),
            'data_count': len(df),
            'duration_min': duration_min,
            'interval_mean': df['interval_ms_calc'].mean(),
            'interval_median': df['interval_ms_calc'].median(),
            'interval_p95': df['interval_ms_calc'].quantile(0.95),
            'interval_max': df['interval_ms_calc'].max(),
            'packet_loss_count': (df['interval_ms_calc'] > 200).sum(),
            'packet_loss_rate': (df['interval_ms_calc'] > 200).sum() / len(df) * 100
        }
        
        # 期待パケット数（100ms間隔の場合）
        if duration_min > 0:
            expected_packets = duration_min * 60 * 10  # 10 packets/sec
            stats['expected_packets'] = expected_packets
            stats['actual_packets'] = len(df)
            stats['reception_rate'] = len(df) / expected_packets * 100
            stats['packet_reduction_rate'] = (1 - len(df) / expected_packets) * 100
        
        # 活動状態の分析（もしあれば）
        if 'state' in df.columns:
            state_counts = df['state'].value_counts()
            stats['state_idle'] = state_counts.get(0, 0)
            stats['state_active'] = state_counts.get(1, 0)
            stats['state_uncertain'] = state_counts.get(2, 0)
            stats['state_idle_pct'] = stats['state_idle'] / len(df) * 100
            stats['state_active_pct'] = stats['state_active'] / len(df) * 100
            stats['state_uncertain_pct'] = stats['state_uncertain'] / len(df) * 100
        
        return stats
    
    except Exception as e:
        print(f"Error processing {csv_path}: {e}")
        return None

def main():
    # 結果を格納するリスト
    results_100ms = []
    results_adaptive = []
    
    # 100ms固定のファイルを分析
    print("=== Analyzing 100ms Fixed Interval Files ===")
    for file in glob.glob("datas/100ms/*.csv"):
        print(f"Processing: {file}")
        result = analyze_ble_log(file)
        if result:
            result['mode'] = 'fixed_100ms'
            results_100ms.append(result)
    
    # 適応制御のファイルを分析
    print("\n=== Analyzing Adaptive Control Files ===")
    for file in glob.glob("datas/adaptive/*.csv"):
        print(f"Processing: {file}")
        result = analyze_ble_log(file)
        if result:
            result['mode'] = 'adaptive'
            results_adaptive.append(result)
    
    # データフレームに変換
    df_100ms = pd.DataFrame(results_100ms)
    df_adaptive = pd.DataFrame(results_adaptive)
    df_all = pd.concat([df_100ms, df_adaptive], ignore_index=True)
    
    # 統計サマリー
    print("\n=== Summary Statistics ===")
    print("\n--- Fixed 100ms ---")
    if len(df_100ms) > 0:
        print(f"Files analyzed: {len(df_100ms)}")
        print(f"Average reception rate: {df_100ms['reception_rate'].mean():.1f}%")
        print(f"Average interval: {df_100ms['interval_mean'].mean():.1f} ms")
        print(f"Average p95 interval: {df_100ms['interval_p95'].mean():.1f} ms")
    
    print("\n--- Adaptive Control ---")
    if len(df_adaptive) > 0:
        print(f"Files analyzed: {len(df_adaptive)}")
        print(f"Average reception rate: {df_adaptive['reception_rate'].mean():.1f}%")
        print(f"Average interval: {df_adaptive['interval_mean'].mean():.1f} ms")
        print(f"Average p95 interval: {df_adaptive['interval_p95'].mean():.1f} ms")
        print(f"Average packet reduction: {df_adaptive['packet_reduction_rate'].mean():.1f}%")
    
    # 比較統計
    print("\n=== Comparison ===")
    if len(df_100ms) > 0 and len(df_adaptive) > 0:
        fixed_rate = df_100ms['reception_rate'].mean()
        adaptive_rate = df_adaptive['reception_rate'].mean()
        reduction = (fixed_rate - adaptive_rate) / fixed_rate * 100
        print(f"Packet reduction by adaptive control: {reduction:.1f}%")
    
    # CSVファイルに保存
    os.makedirs("letter", exist_ok=True)
    
    # 詳細データ
    df_all.to_csv("letter/analysis_detailed_results.csv", index=False)
    print("\nDetailed results saved to: letter/analysis_detailed_results.csv")
    
    # サマリーデータ
    summary_data = []
    
    if len(df_100ms) > 0:
        summary_data.append({
            'mode': 'Fixed 100ms',
            'files_count': len(df_100ms),
            'total_duration_min': df_100ms['duration_min'].sum(),
            'avg_reception_rate': df_100ms['reception_rate'].mean(),
            'avg_interval_ms': df_100ms['interval_mean'].mean(),
            'avg_p95_interval_ms': df_100ms['interval_p95'].mean(),
            'avg_packet_loss_rate': df_100ms['packet_loss_rate'].mean()
        })
    
    if len(df_adaptive) > 0:
        summary_data.append({
            'mode': 'Adaptive',
            'files_count': len(df_adaptive),
            'total_duration_min': df_adaptive['duration_min'].sum(),
            'avg_reception_rate': df_adaptive['reception_rate'].mean(),
            'avg_interval_ms': df_adaptive['interval_mean'].mean(),
            'avg_p95_interval_ms': df_adaptive['interval_p95'].mean(),
            'avg_packet_loss_rate': df_adaptive['packet_loss_rate'].mean(),
            'avg_packet_reduction_rate': df_adaptive['packet_reduction_rate'].mean()
        })
    
    df_summary = pd.DataFrame(summary_data)
    df_summary.to_csv("letter/analysis_summary.csv", index=False)
    print("Summary results saved to: letter/analysis_summary.csv")
    
    # 論文用の表形式データ
    paper_table = pd.DataFrame({
        'Metric': ['Reception Rate (%)', 'Mean Interval (ms)', 'p95 Interval (ms)', 
                   'Packet Loss Rate (%)', 'Packet Reduction (%)'],
        'Fixed 100ms': [
            f"{df_100ms['reception_rate'].mean():.1f}" if len(df_100ms) > 0 else "N/A",
            f"{df_100ms['interval_mean'].mean():.1f}" if len(df_100ms) > 0 else "N/A",
            f"{df_100ms['interval_p95'].mean():.1f}" if len(df_100ms) > 0 else "N/A",
            f"{df_100ms['packet_loss_rate'].mean():.1f}" if len(df_100ms) > 0 else "N/A",
            "0.0"
        ],
        'Adaptive': [
            f"{df_adaptive['reception_rate'].mean():.1f}" if len(df_adaptive) > 0 else "N/A",
            f"{df_adaptive['interval_mean'].mean():.1f}" if len(df_adaptive) > 0 else "N/A",
            f"{df_adaptive['interval_p95'].mean():.1f}" if len(df_adaptive) > 0 else "N/A",
            f"{df_adaptive['packet_loss_rate'].mean():.1f}" if len(df_adaptive) > 0 else "N/A",
            f"{df_adaptive['packet_reduction_rate'].mean():.1f}" if len(df_adaptive) > 0 else "N/A"
        ]
    })
    
    paper_table.to_csv("letter/paper_comparison_table.csv", index=False)
    print("Paper comparison table saved to: letter/paper_comparison_table.csv")

if __name__ == "__main__":
    main()