"""
適応制御BLEログから1秒間の通信頻度を時系列でプロット
"""
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime
import os

# 設定
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 12
plt.rcParams['figure.dpi'] = 150
plt.rcParams['savefig.dpi'] = 300

# カラースキーム
COLOR_QUIET = '#4CAF50'      # 緑: QUIET状態
COLOR_UNCERTAIN = '#FF9800'  # オレンジ: UNCERTAIN状態  
COLOR_ACTIVE = '#F44336'     # 赤: ACTIVE状態
COLOR_AVERAGE = '#2196F3'    # 青: 平均線

def load_and_process_adaptive_log(csv_path):
    """適応制御BLEログを読み込み、通信頻度を計算"""
    print(f"Loading: {csv_path}")
    
    # CSVファイル読み込み
    df = pd.read_csv(csv_path, float_precision='round_trip')
    
    # タイムスタンプをdatetimeに変換（ミリ秒単位）
    df['timestamp'] = pd.to_numeric(df['timestamp_phone_unix_ms'])
    df['datetime'] = pd.to_datetime(df['timestamp'], unit='ms')
    
    # 最初のパケットからの経過時間（秒）
    df['elapsed_sec'] = (df['timestamp'] - df['timestamp'].iloc[0]) / 1000
    
    return df

def calculate_frequency_per_second(df, window_sec=1):
    """1秒ごとの通信頻度を計算"""
    # 1秒ごとのビンを作成
    max_time = int(df['elapsed_sec'].max()) + 1
    bins = np.arange(0, max_time + window_sec, window_sec)
    
    # 各ビンでのパケット数をカウント
    freq_per_bin = pd.cut(df['elapsed_sec'], bins=bins, include_lowest=True)
    frequency = df.groupby(freq_per_bin).size()
    
    # ビンの中心時刻を計算
    bin_centers = [(b.left + b.right) / 2 for b in frequency.index]
    
    return bin_centers, frequency.values

def estimate_control_state(frequency):
    """通信頻度から制御状態を推定"""
    states = []
    colors = []
    
    for f in frequency:
        if f <= 1:  # ~1Hz = QUIET (2000ms間隔)
            states.append('QUIET')
            colors.append(COLOR_QUIET)
        elif f <= 3:  # ~2Hz = UNCERTAIN (500ms間隔)
            states.append('UNCERTAIN')
            colors.append(COLOR_UNCERTAIN)
        else:  # >=4Hz = ACTIVE (100-250ms間隔)
            states.append('ACTIVE')
            colors.append(COLOR_ACTIVE)
    
    return states, colors

def plot_adaptive_frequency(csv_path, output_dir):
    """適応制御の通信頻度を時系列プロット"""
    # データ読み込み
    df = load_and_process_adaptive_log(csv_path)
    
    # 1秒ごとの通信頻度を計算
    time_bins, frequency = calculate_frequency_per_second(df)
    
    # 制御状態を推定
    states, colors = estimate_control_state(frequency)
    
    # プロット作成
    fig, ax = plt.subplots(figsize=(14, 8))
    
    # 棒グラフで通信頻度を表示（制御状態で色分け）
    bars = ax.bar(time_bins, frequency, width=0.8, edgecolor='black', linewidth=0.5)
    
    # 各バーに制御状態に応じた色を設定
    for bar, color in zip(bars, colors):
        bar.set_facecolor(color)
    
    # 移動平均線を追加（30秒窓）
    if len(frequency) > 30:
        window = min(30, len(frequency) // 4)
        ma = pd.Series(frequency).rolling(window=window, center=True).mean()
        ax.plot(time_bins, ma, color=COLOR_AVERAGE, linewidth=2.5, 
                label=f'{window}s Moving Average', alpha=0.8)
    
    # 制御状態の参照線
    ax.axhline(y=0.5, color=COLOR_QUIET, linestyle='--', alpha=0.5, label='QUIET (~0.5 Hz)')
    ax.axhline(y=2, color=COLOR_UNCERTAIN, linestyle='--', alpha=0.5, label='UNCERTAIN (~2 Hz)')
    ax.axhline(y=10, color=COLOR_ACTIVE, linestyle='--', alpha=0.5, label='ACTIVE (~10 Hz)')
    
    # グラフ設定
    ax.set_xlabel('Time (seconds)', fontsize=14)
    ax.set_ylabel('Communication Frequency (packets/sec)', fontsize=14)
    ax.set_title('Adaptive BLE Advertising Frequency Over Time', fontsize=16, pad=20)
    
    # y軸の範囲を設定
    ax.set_ylim(0, max(15, max(frequency) * 1.1))
    
    # グリッド
    ax.grid(True, axis='y', alpha=0.3)
    
    # 凡例
    legend_elements = [
        plt.Rectangle((0,0),1,1, fc=COLOR_QUIET, label='QUIET State'),
        plt.Rectangle((0,0),1,1, fc=COLOR_UNCERTAIN, label='UNCERTAIN State'),
        plt.Rectangle((0,0),1,1, fc=COLOR_ACTIVE, label='ACTIVE State')
    ]
    if len(frequency) > 30:
        legend_elements.append(plt.Line2D([0], [0], color=COLOR_AVERAGE, linewidth=2.5, 
                                        label=f'{window}s Moving Average'))
    
    ax.legend(handles=legend_elements, loc='upper right', framealpha=0.9)
    
    # 統計情報を追加
    stats_text = f'Total Duration: {df["elapsed_sec"].max():.1f}s\n'
    stats_text += f'Total Packets: {len(df)}\n'
    stats_text += f'Avg Frequency: {len(df) / df["elapsed_sec"].max():.2f} Hz\n'
    
    # 各状態の時間割合
    state_counts = pd.Series(states).value_counts()
    total_bins = len(states)
    for state in ['QUIET', 'UNCERTAIN', 'ACTIVE']:
        if state in state_counts:
            percentage = (state_counts[state] / total_bins) * 100
            stats_text += f'{state}: {percentage:.1f}%\n'
    
    ax.text(0.02, 0.98, stats_text, transform=ax.transAxes, 
            verticalalignment='top', bbox=dict(boxstyle='round', 
            facecolor='wheat', alpha=0.8), fontsize=10)
    
    # 保存
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'adaptive_frequency_timeline.png')
    plt.savefig(output_path, bbox_inches='tight')
    print(f"Saved: {output_path}")
    
    plt.close()
    
    # 統計情報を返す
    return {
        'total_duration': df['elapsed_sec'].max(),
        'total_packets': len(df),
        'avg_frequency': len(df) / df['elapsed_sec'].max(),
        'state_distribution': state_counts.to_dict() if len(state_counts) > 0 else {}
    }

def create_comparison_plot(adaptive_files, fixed_file, output_dir):
    """複数の適応制御ファイルと固定間隔の比較プロット"""
    fig, axes = plt.subplots(len(adaptive_files) + 1, 1, figsize=(14, 4 * (len(adaptive_files) + 1)))
    
    if len(adaptive_files) == 1:
        axes = [axes]
    
    # 適応制御ファイルをプロット
    for i, csv_path in enumerate(adaptive_files):
        ax = axes[i]
        df = load_and_process_adaptive_log(csv_path)
        time_bins, frequency = calculate_frequency_per_second(df)
        states, colors = estimate_control_state(frequency)
        
        bars = ax.bar(time_bins, frequency, width=0.8, edgecolor='black', linewidth=0.5)
        for bar, color in zip(bars, colors):
            bar.set_facecolor(color)
        
        ax.set_ylabel('Freq (Hz)')
        ax.set_title(f'Adaptive Control - {os.path.basename(csv_path)}')
        ax.set_ylim(0, 15)
        ax.grid(True, axis='y', alpha=0.3)
    
    # 固定間隔の参照線をプロット
    if fixed_file and os.path.exists(fixed_file):
        ax = axes[-1]
        df_fixed = load_and_process_adaptive_log(fixed_file)
        time_bins, frequency = calculate_frequency_per_second(df_fixed)
        
        ax.bar(time_bins, frequency, width=0.8, color='gray', 
               edgecolor='black', linewidth=0.5, alpha=0.7)
        ax.axhline(y=10, color='red', linestyle='--', label='Fixed 100ms (~10Hz)')
        ax.set_ylabel('Freq (Hz)')
        ax.set_xlabel('Time (seconds)')
        ax.set_title('Fixed 100ms Interval (Reference)')
        ax.set_ylim(0, 15)
        ax.grid(True, axis='y', alpha=0.3)
        ax.legend()
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'adaptive_vs_fixed_comparison.png')
    plt.savefig(output_path, bbox_inches='tight')
    print(f"Saved: {output_path}")
    plt.close()

if __name__ == '__main__':
    # パス設定
    adaptive_file = r"C:\Users\tp240\Documents\letter202507\MobileNLD-FL\datas\adaptive\ble_log_20250821_055619.csv"
    output_dir = r"C:\Users\tp240\Documents\letter202507\MobileNLD-FL\letter"
    
    # 単一ファイルのプロット
    if os.path.exists(adaptive_file):
        stats = plot_adaptive_frequency(adaptive_file, output_dir)
        print("\nStatistics:")
        print(f"Duration: {stats['total_duration']:.1f}s")
        print(f"Packets: {stats['total_packets']}")
        print(f"Avg Frequency: {stats['avg_frequency']:.2f} Hz")
        print(f"State Distribution: {stats['state_distribution']}")
    
    # 複数ファイルの比較（利用可能な場合）
    adaptive_dir = os.path.dirname(adaptive_file)
    adaptive_files = [os.path.join(adaptive_dir, f) for f in os.listdir(adaptive_dir) 
                     if f.endswith('.csv')][:3]  # 最大3ファイル
    
    fixed_dir = r"C:\Users\tp240\Documents\letter202507\MobileNLD-FL\datas\100ms"
    fixed_files = [os.path.join(fixed_dir, f) for f in os.listdir(fixed_dir) 
                   if f.endswith('.csv')] if os.path.exists(fixed_dir) else []
    fixed_file = fixed_files[0] if fixed_files else None
    
    if len(adaptive_files) > 0:
        create_comparison_plot(adaptive_files, fixed_file, output_dir)