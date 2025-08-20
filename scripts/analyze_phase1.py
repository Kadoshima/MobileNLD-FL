#!/usr/bin/env python3
"""
Phase 1 実験データ解析スクリプト
M5StickC Plus2のBLE/IMU/電力データを解析
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import json
from datetime import datetime

def analyze_power_data(csv_file):
    """電力測定データの解析"""
    print(f"\n=== 電力データ解析: {csv_file} ===")
    
    # CSVを読み込み
    df = pd.read_csv(csv_file)
    
    # 条件ごとに集計
    conditions = df['condition'].unique() if 'condition' in df.columns else ['all']
    
    results = {}
    for condition in conditions:
        if condition == 'all':
            data = df
        else:
            data = df[df['condition'] == condition]
        
        if 'current_mA' in data.columns:
            current = data['current_mA']
        elif 'current_ma' in data.columns:
            current = data['current_ma']
        else:
            print(f"Warning: No current column found")
            continue
            
        results[condition] = {
            'avg_current_mA': current.mean(),
            'std_current_mA': current.std(),
            'max_current_mA': current.max(),
            'min_current_mA': current.min(),
            'samples': len(current)
        }
        
        print(f"\n条件: {condition}")
        print(f"  平均電流: {results[condition]['avg_current_mA']:.2f} mA")
        print(f"  標準偏差: {results[condition]['std_current_mA']:.2f} mA")
        print(f"  最大電流: {results[condition]['max_current_mA']:.2f} mA")
        print(f"  最小電流: {results[condition]['min_current_mA']:.2f} mA")
        
    # 削減率計算
    if 'ble_100ms' in results and 'ble_2000ms' in results:
        i_100 = results['ble_100ms']['avg_current_mA']
        i_2000 = results['ble_2000ms']['avg_current_mA']
        reduction = (i_100 - i_2000) / i_100 * 100
        print(f"\n削減率: {reduction:.1f}%")
        print(f"  100ms: {i_100:.2f} mA")
        print(f"  2000ms: {i_2000:.2f} mA")
        
        # バッテリー寿命推定
        battery_mah = 135  # M5StickC Plus2
        life_100 = battery_mah / i_100
        life_2000 = battery_mah / i_2000
        print(f"\nバッテリー寿命推定:")
        print(f"  100ms: {life_100:.1f} 時間")
        print(f"  2000ms: {life_2000:.1f} 時間")
        print(f"  延長率: {life_2000/life_100:.1f}倍")
    
    return results

def analyze_imu_data(csv_file):
    """IMU状態遷移データの解析"""
    print(f"\n=== IMU状態遷移解析: {csv_file} ===")
    
    df = pd.read_csv(csv_file)
    
    # 状態ごとのuncertainty統計
    if 'display_state' in df.columns and 'uncertainty' in df.columns:
        states = df['display_state'].unique()
        
        for state in states:
            state_data = df[df['display_state'] == state]['uncertainty']
            if len(state_data) > 0:
                print(f"\n{state}:")
                print(f"  Uncertainty範囲: {state_data.min():.2f} - {state_data.max():.2f}")
                print(f"  平均: {state_data.mean():.2f}")
                print(f"  サンプル数: {len(state_data)}")
    
    # 精度計算
    if 'expected_state' in df.columns and 'display_state' in df.columns:
        correct = df['expected_state'] == df['display_state']
        accuracy = correct.sum() / len(correct) * 100
        print(f"\n判定精度: {accuracy:.1f}% ({correct.sum()}/{len(correct)})")
        
        # 混同行列
        from sklearn.metrics import confusion_matrix
        cm = confusion_matrix(df['expected_state'], df['display_state'])
        print("\n混同行列:")
        print(cm)
    
    return df

def analyze_ble_packets(csv_file):
    """BLEパケット受信データの解析"""
    print(f"\n=== BLEパケット解析: {csv_file} ===")
    
    df = pd.read_csv(csv_file)
    
    # パケット間隔計算
    if 'timestamp' in df.columns:
        df['timestamp_ms'] = pd.to_datetime(df['timestamp']).astype(int) / 1e6
        df['interval_ms'] = df['timestamp_ms'].diff()
        
        # 外れ値除去（最初のパケットと5秒以上の間隔）
        intervals = df['interval_ms'][1:][df['interval_ms'][1:] < 5000]
        
        if len(intervals) > 0:
            print(f"\nパケット間隔統計:")
            print(f"  平均: {intervals.mean():.1f} ms")
            print(f"  中央値: {intervals.median():.1f} ms")
            print(f"  p95: {intervals.quantile(0.95):.1f} ms")
            print(f"  p99: {intervals.quantile(0.99):.1f} ms")
            
            # パケット損失率推定
            expected_interval = 100  # ms (仮定)
            expected_packets = (df['timestamp_ms'].max() - df['timestamp_ms'].min()) / expected_interval
            actual_packets = len(df)
            loss_rate = max(0, (1 - actual_packets / expected_packets)) * 100
            print(f"\n推定パケット損失率: {loss_rate:.1f}%")
            print(f"  期待パケット数: {expected_packets:.0f}")
            print(f"  実際のパケット数: {actual_packets}")
    
    # RSSI統計
    if 'rssi_dbm' in df.columns:
        rssi = df['rssi_dbm']
        print(f"\nRSSI統計:")
        print(f"  平均: {rssi.mean():.1f} dBm")
        print(f"  最大: {rssi.max()} dBm")
        print(f"  最小: {rssi.min()} dBm")
    
    return df

def create_plots(power_data, imu_data, ble_data, output_dir="results/phase1"):
    """結果のグラフ作成"""
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # 1. 電力比較
    if power_data:
        ax = axes[0, 0]
        conditions = list(power_data.keys())
        currents = [power_data[c]['avg_current_mA'] for c in conditions]
        errors = [power_data[c]['std_current_mA'] for c in conditions]
        
        ax.bar(conditions, currents, yerr=errors, capsize=5)
        ax.set_ylabel('Current (mA)')
        ax.set_title('Power Consumption Comparison')
        ax.grid(True, alpha=0.3)
    
    # 2. IMU状態分布
    if imu_data is not None and 'display_state' in imu_data.columns:
        ax = axes[0, 1]
        state_counts = imu_data['display_state'].value_counts()
        ax.pie(state_counts.values, labels=state_counts.index, autopct='%1.1f%%')
        ax.set_title('HAR State Distribution')
    
    # 3. BLEパケット間隔ヒストグラム
    if ble_data is not None and 'interval_ms' in ble_data.columns:
        ax = axes[1, 0]
        intervals = ble_data['interval_ms'].dropna()
        intervals = intervals[intervals < 1000]  # 1秒以下のみ表示
        ax.hist(intervals, bins=50, edgecolor='black', alpha=0.7)
        ax.set_xlabel('Interval (ms)')
        ax.set_ylabel('Count')
        ax.set_title('BLE Packet Interval Distribution')
        ax.axvline(100, color='r', linestyle='--', label='Expected (100ms)')
        ax.legend()
    
    # 4. 時系列プロット（電流）
    ax = axes[1, 1]
    # ダミーデータ（実際のデータがあれば置き換え）
    time = np.linspace(0, 300, 300)
    current = np.random.normal(10, 2, 300)
    current[100:200] = np.random.normal(15, 3, 100)  # Active期間
    ax.plot(time, current, alpha=0.7)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Current (mA)')
    ax.set_title('Current Profile Over Time')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    output_file = Path(output_dir) / f"phase1_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
    plt.savefig(output_file, dpi=100)
    print(f"\nグラフ保存: {output_file}")
    plt.show()

def generate_summary_report(power_results, output_dir="results/phase1"):
    """サマリーレポート生成"""
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    report = {
        "experiment_date": datetime.now().isoformat(),
        "device": "M5StickC Plus2",
        "phase": "Phase 1 - Feasibility Test",
        "results": {}
    }
    
    # 電力削減率
    if power_results and 'ble_100ms' in power_results and 'ble_2000ms' in power_results:
        i_100 = power_results['ble_100ms']['avg_current_mA']
        i_2000 = power_results['ble_2000ms']['avg_current_mA']
        reduction = (i_100 - i_2000) / i_100 * 100
        
        report["results"]["power_reduction"] = {
            "value": round(reduction, 1),
            "unit": "%",
            "baseline_mA": round(i_100, 2),
            "optimized_mA": round(i_2000, 2)
        }
    
    # 判定基準
    if "power_reduction" in report["results"]:
        reduction = report["results"]["power_reduction"]["value"]
        if reduction >= 30:
            decision = "ESP32で本実装継続（優秀）"
        elif reduction >= 20:
            decision = "ESP32で改善検討（良好）"
        elif reduction >= 10:
            decision = "アルゴリズム改善必要（可）"
        else:
            decision = "Nordic検討（要再考）"
        
        report["decision"] = decision
        report["next_action"] = "Phase 2へ進む" if reduction >= 20 else "アルゴリズム改善"
    
    # JSON保存
    output_file = Path(output_dir) / f"summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"\n=== サマリーレポート ===")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    print(f"\nレポート保存: {output_file}")
    
    return report

def main():
    """メイン処理"""
    print("Phase 1 実験データ解析")
    print("=" * 50)
    
    # データファイルのパス（実際のパスに置き換え）
    power_csv = "data/phase1/power_measurement.csv"
    imu_csv = "data/phase1/imu_states.csv"
    ble_csv = "data/phase1/ble_packets.csv"
    
    power_results = None
    imu_data = None
    ble_data = None
    
    # 各データの解析
    if Path(power_csv).exists():
        power_results = analyze_power_data(power_csv)
    else:
        print(f"\n電力データなし: {power_csv}")
    
    if Path(imu_csv).exists():
        imu_data = analyze_imu_data(imu_csv)
    else:
        print(f"\nIMUデータなし: {imu_csv}")
    
    if Path(ble_csv).exists():
        ble_data = analyze_ble_packets(ble_csv)
    else:
        print(f"\nBLEデータなし: {ble_csv}")
    
    # グラフ作成
    if any([power_results, imu_data is not None, ble_data is not None]):
        create_plots(power_results, imu_data, ble_data)
    
    # サマリーレポート
    if power_results:
        generate_summary_report(power_results)
    
    print("\n解析完了！")

if __name__ == "__main__":
    main()