import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def analyze_power_log(csv_file):
    """フラッシュログのCSVを分析"""
    # CSVを読み込み
    df = pd.read_csv(csv_file)
    
    print(f"データ件数: {len(df)}")
    print(f"測定時間: {df['timestamp_ms'].max() / 60000:.1f} 分")
    
    # 状態ごとの統計
    print("\n=== 制御状態の分布 ===")
    state_names = {0: "QUIET (2000ms)", 1: "UNCERTAIN (500ms)", 2: "ACTIVE (100ms)"}
    for state, name in state_names.items():
        count = (df['control_state'] == state).sum()
        if len(df) > 0:
            percent = count / len(df) * 100
            print(f"{name}: {count} ({percent:.1f}%)")
    
    # 電力統計（電流が0でないデータのみ）
    power_data = df[df['current_mA'] != 0].copy()
    if len(power_data) > 0:
        print("\n=== 電力統計 ===")
        print(f"平均電流: {power_data['current_mA'].mean():.2f} mA")
        print(f"平均電力: {power_data['power_mW'].mean():.2f} mW")
        
        # 状態ごとの電力
        print("\n=== 状態別平均電流 ===")
        for state, name in state_names.items():
            state_data = power_data[power_data['control_state'] == state]
            if len(state_data) > 0:
                avg_current = state_data['current_mA'].mean()
                print(f"{name}: {avg_current:.2f} mA")
    else:
        print("\n注意: 電流データが0です。USB接続時のデータの可能性があります。")
    
    # グラフ作成
    fig, axes = plt.subplots(3, 1, figsize=(12, 10))
    
    # 1. 制御状態の推移
    ax1 = axes[0]
    ax1.plot(df['timestamp_ms'] / 1000, df['control_state'], 'b-', linewidth=0.5)
    ax1.set_ylabel('Control State')
    ax1.set_yticks([0, 1, 2])
    ax1.set_yticklabels(['QUIET', 'UNCERTAIN', 'ACTIVE'])
    ax1.set_title('制御状態の推移')
    ax1.grid(True, alpha=0.3)
    
    # 2. 広告間隔の推移
    ax2 = axes[1]
    ax2.plot(df['timestamp_ms'] / 1000, df['adv_interval_ms'], 'g-', linewidth=0.5)
    ax2.set_ylabel('Advertising Interval (ms)')
    ax2.set_title('BLE広告間隔の推移')
    ax2.set_yscale('log')
    ax2.grid(True, alpha=0.3)
    
    # 3. 電流の推移
    ax3 = axes[2]
    ax3.plot(df['timestamp_ms'] / 1000, df['current_mA'], 'r-', linewidth=0.5)
    ax3.set_xlabel('Time (s)')
    ax3.set_ylabel('Current (mA)')
    ax3.set_title('消費電流の推移')
    ax3.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('power_analysis.png', dpi=150)
    print("\nグラフを power_analysis.png に保存しました")
    
    # パケット削減率の計算
    total_time_ms = df['timestamp_ms'].max() - df['timestamp_ms'].min()
    if total_time_ms > 0:
        # Fixed 100ms での期待パケット数
        expected_packets_100ms = total_time_ms / 100
        # 実際のパケット数（最後のシーケンス番号）
        actual_packets = df['packets_sent'].max()
        reduction_rate = (1 - actual_packets / expected_packets_100ms) * 100
        
        print(f"\n=== パケット削減率 ===")
        print(f"期待パケット数 (100ms固定): {expected_packets_100ms:.0f}")
        print(f"実際のパケット数: {actual_packets}")
        print(f"削減率: {reduction_rate:.1f}%")
    
    return df

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    else:
        csv_file = input("CSVファイルのパスを入力してください: ")
    
    analyze_power_log(csv_file)