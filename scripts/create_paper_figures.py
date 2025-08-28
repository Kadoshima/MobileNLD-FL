import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import os

# 日本語フォントの設定
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 12
plt.rcParams['figure.dpi'] = 150
plt.rcParams['savefig.dpi'] = 300

# カラーパレット
colors = {
    'fixed': '#2E86AB',
    'adaptive': '#E63946',
    'quiet': '#264653',
    'uncertain': '#E9C46A',
    'active': '#F4A261'
}

def create_packet_reduction_bar_chart():
    """パケット削減率の棒グラフ"""
    fig, ax = plt.subplots(figsize=(8, 6))
    
    methods = ['Fixed 100ms', 'Adaptive']
    reception_rates = [94.2, 18.6]
    
    bars = ax.bar(methods, reception_rates, color=[colors['fixed'], colors['adaptive']], width=0.6)
    
    # 値をバーの上に表示
    for bar, rate in zip(bars, reception_rates):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                f'{rate:.1f}%', ha='center', va='bottom', fontsize=14, fontweight='bold')
    
    # 削減率を表示
    reduction = (reception_rates[0] - reception_rates[1]) / reception_rates[0] * 100
    ax.annotate('', xy=(0.5, reception_rates[1]), xytext=(0.5, reception_rates[0]),
                arrowprops=dict(arrowstyle='<->', color='black', lw=2))
    ax.text(0.6, (reception_rates[0] + reception_rates[1])/2, 
            f'{reduction:.1f}%\nReduction', fontsize=12, fontweight='bold')
    
    ax.set_ylabel('Packet Reception Rate (%)', fontsize=14)
    ax.set_title('BLE Packet Reception Rate Comparison', fontsize=16, fontweight='bold')
    ax.set_ylim(0, 110)
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('letter/fig1_packet_reduction.png', bbox_inches='tight')
    plt.close()

def create_interval_distribution():
    """広告間隔の分布図"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
    
    # 固定100ms（デルタ関数的な分布）
    ax1.bar([100], [100], width=20, color=colors['fixed'], alpha=0.8)
    ax1.set_xlim(0, 2500)
    ax1.set_ylim(0, 110)
    ax1.set_xlabel('Advertising Interval (ms)', fontsize=12)
    ax1.set_ylabel('Frequency (%)', fontsize=12)
    ax1.set_title('Fixed 100ms', fontsize=14, fontweight='bold')
    ax1.grid(alpha=0.3)
    
    # 適応制御（実測値ベース）
    intervals = [100, 500, 2000]
    frequencies = [8.3, 4.4, 87.3]
    
    bars = ax2.bar(intervals, frequencies, width=[50, 200, 500], 
                    color=[colors['active'], colors['uncertain'], colors['quiet']], alpha=0.8)
    
    # ラベル追加
    for bar, freq, interval in zip(bars, frequencies, intervals):
        ax2.text(bar.get_x() + bar.get_width()/2., bar.get_height() + 1,
                f'{freq:.1f}%\n({interval}ms)', ha='center', va='bottom', fontsize=10)
    
    ax2.set_xlim(0, 2500)
    ax2.set_ylim(0, 110)
    ax2.set_xlabel('Advertising Interval (ms)', fontsize=12)
    ax2.set_ylabel('Frequency (%)', fontsize=12)
    ax2.set_title('Adaptive Control', fontsize=14, fontweight='bold')
    ax2.grid(alpha=0.3)
    
    plt.suptitle('Distribution of BLE Advertising Intervals', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig('letter/fig2_interval_distribution.png', bbox_inches='tight')
    plt.close()

def create_power_consumption_comparison():
    """消費電力比較グラフ"""
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # データ
    states = ['QUIET\n(2000ms)', 'UNCERTAIN\n(500ms)', 'ACTIVE\n(100ms)']
    currents = [20.1, 20.4, 22.0]
    time_ratios = [87.3, 4.4, 8.3]
    
    # 棒グラフ
    x = np.arange(len(states))
    width = 0.35
    
    bars1 = ax.bar(x - width/2, currents, width, label='Current (mA)', 
                    color=[colors['quiet'], colors['uncertain'], colors['active']], alpha=0.8)
    bars2 = ax.bar(x + width/2, time_ratios, width, label='Time Ratio (%)', 
                    color='gray', alpha=0.6)
    
    # 値を表示
    for bar, val in zip(bars1, currents):
        ax.text(bar.get_x() + bar.get_width()/2., bar.get_height() + 0.1,
                f'{val:.1f}', ha='center', va='bottom', fontsize=10)
    
    for bar, val in zip(bars2, time_ratios):
        ax.text(bar.get_x() + bar.get_width()/2., bar.get_height() + 0.5,
                f'{val:.1f}%', ha='center', va='bottom', fontsize=10)
    
    # 平均電流を計算して表示
    avg_current = sum(c * t / 100 for c, t in zip(currents, time_ratios))
    ax.axhline(y=avg_current, color='red', linestyle='--', linewidth=2, label=f'Weighted Average: {avg_current:.1f} mA')
    
    ax.set_xlabel('Control State', fontsize=14)
    ax.set_ylabel('Value', fontsize=14)
    ax.set_title('Power Consumption by Control State', fontsize=16, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(states)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    # 固定100msとの比較
    fixed_current = 22.0
    ax.text(0.02, 0.95, f'Fixed 100ms: {fixed_current:.1f} mA (constant)', 
            transform=ax.transAxes, fontsize=12, 
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    plt.tight_layout()
    plt.savefig('letter/fig3_power_consumption.png', bbox_inches='tight')
    plt.close()

def create_battery_life_projection():
    """バッテリー持続時間の予測グラフ"""
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # パラメータ
    battery_capacity = 135  # mAh
    fixed_current = 22.0  # mA
    adaptive_current = 20.28  # mA
    
    # 時間軸（0-8時間）
    time_hours = np.linspace(0, 8, 100)
    
    # バッテリー残量計算
    fixed_remaining = 100 - (fixed_current * time_hours / battery_capacity * 100)
    adaptive_remaining = 100 - (adaptive_current * time_hours / battery_capacity * 100)
    
    # プロット
    ax.plot(time_hours, fixed_remaining, color=colors['fixed'], linewidth=3, 
            label=f'Fixed 100ms ({fixed_current:.1f} mA)', linestyle='--')
    ax.plot(time_hours, adaptive_remaining, color=colors['adaptive'], linewidth=3, 
            label=f'Adaptive ({adaptive_current:.1f} mA)')
    
    # バッテリー切れの時間を表示
    fixed_life = battery_capacity / fixed_current
    adaptive_life = battery_capacity / adaptive_current
    
    ax.axvline(x=fixed_life, color=colors['fixed'], linestyle=':', alpha=0.5)
    ax.axvline(x=adaptive_life, color=colors['adaptive'], linestyle=':', alpha=0.5)
    
    ax.text(fixed_life, 5, f'{fixed_life:.1f}h', ha='center', fontsize=10, 
            color=colors['fixed'], fontweight='bold')
    ax.text(adaptive_life, 5, f'{adaptive_life:.1f}h', ha='center', fontsize=10, 
            color=colors['adaptive'], fontweight='bold')
    
    # 改善率
    improvement = (adaptive_life - fixed_life) / fixed_life * 100
    ax.text(0.5, 0.5, f'Battery Life Extension:\n+{improvement:.1f}%\n({adaptive_life - fixed_life:.2f} hours)', 
            transform=ax.transAxes, fontsize=14, fontweight='bold',
            bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.7),
            ha='center', va='center')
    
    ax.set_xlabel('Time (hours)', fontsize=14)
    ax.set_ylabel('Battery Level (%)', fontsize=14)
    ax.set_title('Battery Life Comparison', fontsize=16, fontweight='bold')
    ax.set_xlim(0, 8)
    ax.set_ylim(0, 110)
    ax.legend(loc='upper right', fontsize=12)
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('letter/fig4_battery_life.png', bbox_inches='tight')
    plt.close()

def create_latency_cdf():
    """遅延のCDF（累積分布関数）グラフ"""
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # 固定100ms - ほぼ100%が100ms
    fixed_x = [0, 100, 100, 2500]
    fixed_y = [0, 0, 100, 100]
    
    # 適応制御 - 実測値ベース
    adaptive_x = [0, 100, 100, 500, 500, 2000, 2000, 2500]
    adaptive_y = [0, 0, 8.3, 8.3, 12.7, 12.7, 100, 100]
    
    ax.plot(fixed_x, fixed_y, color=colors['fixed'], linewidth=3, 
            label='Fixed 100ms', linestyle='--')
    ax.plot(adaptive_x, adaptive_y, color=colors['adaptive'], linewidth=3, 
            label='Adaptive')
    
    # p50, p95マーカー
    ax.axhline(y=50, color='gray', linestyle=':', alpha=0.5)
    ax.axhline(y=95, color='gray', linestyle=':', alpha=0.5)
    ax.text(2400, 50, 'p50', fontsize=10, va='center')
    ax.text(2400, 95, 'p95', fontsize=10, va='center')
    
    # p50, p95の値を表示
    ax.plot([100], [50], 'o', color=colors['fixed'], markersize=8)
    ax.plot([2000], [50], 'o', color=colors['adaptive'], markersize=8)
    ax.plot([100], [95], 's', color=colors['fixed'], markersize=8)
    ax.plot([2000], [95], 's', color=colors['adaptive'], markersize=8)
    
    ax.set_xlabel('Notification Latency (ms)', fontsize=14)
    ax.set_ylabel('Cumulative Probability (%)', fontsize=14)
    ax.set_title('Cumulative Distribution of Notification Latency', fontsize=16, fontweight='bold')
    ax.set_xlim(0, 2500)
    ax.set_ylim(0, 110)
    ax.legend(fontsize=12)
    ax.grid(True, alpha=0.3)
    
    # 注釈
    ax.text(0.02, 0.02, 'Note: Adaptive control trades latency for power savings', 
            transform=ax.transAxes, fontsize=10, style='italic')
    
    plt.tight_layout()
    plt.savefig('letter/fig5_latency_cdf.png', bbox_inches='tight')
    plt.close()

def create_summary_tables():
    """論文用の表をCSV形式で作成"""
    
    # Table 1: System Performance Comparison
    table1_data = {
        'Metric': [
            'Packet Reception Rate (%)',
            'Mean Interval (ms)',
            'p50 Latency (ms)',
            'p95 Latency (ms)',
            'Packet Reduction (%)',
            'Estimated Current (mA)',
            'Battery Life (hours)',
            'Power Savings (%)'
        ],
        'Fixed 100ms': [
            '94.2',
            '100',
            '100',
            '100',
            '0',
            '22.0',
            '6.14',
            '0'
        ],
        'Adaptive Control': [
            '18.6',
            '880',
            '2000',
            '2000',
            '81.4',
            '20.3',
            '6.66',
            '7.8'
        ]
    }
    
    df_table1 = pd.DataFrame(table1_data)
    df_table1.to_csv('letter/table1_performance_comparison.csv', index=False)
    
    # Table 2: Control State Distribution
    table2_data = {
        'Control State': ['QUIET', 'UNCERTAIN', 'ACTIVE'],
        'Advertising Interval (ms)': [2000, 500, 100],
        'Time Ratio (%)': [87.3, 4.4, 8.3],
        'Current Consumption (mA)': [20.1, 20.4, 22.0],
        'Weighted Current (mA)': [17.55, 0.90, 1.83]
    }
    
    df_table2 = pd.DataFrame(table2_data)
    df_table2.to_csv('letter/table2_state_distribution.csv', index=False)
    
    # Table 3: Experimental Setup
    table3_data = {
        'Parameter': [
            'Device',
            'MCU',
            'BLE Version',
            'Battery Capacity',
            'Sampling Rate',
            'Window Size',
            'Activity Threshold',
            'EWMA Alpha',
            'Rate Limit'
        ],
        'Value': [
            'M5StickC Plus2',
            'ESP32-PICO-V3-02',
            'Bluetooth 4.2 / BLE',
            '135 mAh',
            '50 Hz',
            '100 samples (2 seconds)',
            '0.15',
            '0.2',
            '2000 ms'
        ]
    }
    
    df_table3 = pd.DataFrame(table3_data)
    df_table3.to_csv('letter/table3_experimental_setup.csv', index=False)
    
    print("Tables created:")
    print("- table1_performance_comparison.csv")
    print("- table2_state_distribution.csv")
    print("- table3_experimental_setup.csv")

def main():
    # 出力ディレクトリ確認
    os.makedirs('letter', exist_ok=True)
    
    print("Creating figures for paper...")
    
    # 図の作成
    print("1. Creating packet reduction bar chart...")
    create_packet_reduction_bar_chart()
    
    print("2. Creating interval distribution...")
    create_interval_distribution()
    
    print("3. Creating power consumption comparison...")
    create_power_consumption_comparison()
    
    print("4. Creating battery life projection...")
    create_battery_life_projection()
    
    print("5. Creating latency CDF...")
    create_latency_cdf()
    
    print("6. Creating summary tables...")
    create_summary_tables()
    
    print("\nAll figures and tables created successfully!")
    print("Files saved in 'letter/' directory")

if __name__ == "__main__":
    main()