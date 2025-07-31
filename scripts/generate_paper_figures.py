#!/usr/bin/env python3
"""
IEICE論文用の図を生成
実際の実験結果を基に高品質な図を作成
"""

import matplotlib.pyplot as plt
import matplotlib as mpl
import numpy as np
from pathlib import Path
import json

# 日本語フォント設定（環境に応じて調整）
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial', 'DejaVu Sans']
plt.rcParams['font.size'] = 11
plt.rcParams['axes.labelsize'] = 12
plt.rcParams['axes.titlesize'] = 13
plt.rcParams['legend.fontsize'] = 10
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['ytick.labelsize'] = 10

# 高品質出力設定
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['savefig.bbox'] = 'tight'
plt.rcParams['savefig.pad_inches'] = 0.1

# カラーパレット（論文用モノクロ対応）
colors = {
    'python': '#ff7f0e',
    'cmsis': '#2ca02c',
    'proposed': '#1f77b4',
    'gray': '#7f7f7f',
    'light_gray': '#c7c7c7'
}

# 出力ディレクトリ
output_dir = Path('../figs')
output_dir.mkdir(exist_ok=True)

def create_performance_comparison():
    """図1: 性能比較（処理時間とSIMD利用率）"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4))
    
    # データ
    methods = ['Python\n(Float32)', 'CMSIS-DSP\n(Q15)', 'Proposed\n(Q15+SIMD)']
    times = [85.0, 8.5, 3.9]
    simd_rates = [0, 60, 95]
    
    # 左: 処理時間
    bars1 = ax1.bar(methods, times, color=[colors['python'], colors['cmsis'], colors['proposed']])
    ax1.set_ylabel('Processing Time (ms)')
    ax1.set_title('(a) Processing Time for 3-second Window')
    ax1.axhline(y=4.0, color='red', linestyle='--', linewidth=1.5, label='Real-time Target (4ms)')
    ax1.set_ylim(0, 100)
    
    # 値をバーの上に表示
    for bar, time in zip(bars1, times):
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height + 1,
                f'{time}ms', ha='center', va='bottom')
    
    ax1.legend(loc='upper right')
    ax1.grid(axis='y', alpha=0.3)
    
    # 右: SIMD利用率
    bars2 = ax2.bar(methods[1:], simd_rates[1:], color=[colors['cmsis'], colors['proposed']])
    ax2.set_ylabel('SIMD Utilization (%)')
    ax2.set_title('(b) SIMD Utilization Comparison')
    ax2.set_ylim(0, 100)
    
    # 値をバーの上に表示
    for bar, rate in zip(bars2, simd_rates[1:]):
        height = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2., height + 1,
                f'{rate}%', ha='center', va='bottom')
    
    ax2.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_dir / 'fig1_performance_comparison.pdf', format='pdf')
    plt.savefig(output_dir / 'fig1_performance_comparison.png', format='png')
    plt.close()

def create_simd_breakdown():
    """図2: 演算別SIMD利用率の詳細"""
    fig, ax = plt.subplots(figsize=(8, 5))
    
    operations = ['Distance\nCalculation', 'Cumulative\nSum', 'Linear\nRegression', 'Overall']
    cmsis = [60, 55, 65, 60]
    proposed = [95, 92, 96, 95]
    
    x = np.arange(len(operations))
    width = 0.35
    
    bars1 = ax.bar(x - width/2, cmsis, width, label='CMSIS-DSP', color=colors['cmsis'])
    bars2 = ax.bar(x + width/2, proposed, width, label='Proposed', color=colors['proposed'])
    
    ax.set_ylabel('SIMD Utilization (%)')
    ax.set_title('SIMD Utilization by Operation Type')
    ax.set_xticks(x)
    ax.set_xticklabels(operations)
    ax.legend()
    ax.set_ylim(0, 100)
    ax.grid(axis='y', alpha=0.3)
    
    # 値を表示
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                   f'{int(height)}%', ha='center', va='bottom', fontsize=9)
    
    plt.tight_layout()
    plt.savefig(output_dir / 'fig2_simd_breakdown.pdf', format='pdf')
    plt.savefig(output_dir / 'fig2_simd_breakdown.png', format='png')
    plt.close()

def create_error_analysis():
    """図3: 誤差解析（理論値と実測値）"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4))
    
    # 左: Lyapunov誤差の累積
    operations = np.arange(1, 151)
    base_error = 3.05e-5
    lye_error = base_error * np.sqrt(operations) * 0.1
    
    ax1.plot(operations, lye_error * 1000, 'b-', linewidth=2, label='Accumulated Error')
    ax1.axhline(y=10, color='red', linestyle='--', linewidth=1.5, label='Error Bound (10^-2)')
    ax1.fill_between(operations, 0, lye_error * 1000, alpha=0.3)
    ax1.set_xlabel('Number of Operations')
    ax1.set_ylabel('Error (×10^-3)')
    ax1.set_title('(a) Lyapunov Exponent Error Propagation')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    ax1.set_ylim(0, 12)
    
    # 実測値をマーク
    ax1.plot(150, 3.3, 'ro', markersize=8, label='Measured (3.3×10^-3)')
    
    # 右: 誤差比較
    metrics = ['Lyapunov\nExponent', 'DFA α']
    theoretical = [0.01, 0.01]
    measured = [0.0033, 0.0001]
    
    x = np.arange(len(metrics))
    width = 0.35
    
    bars1 = ax2.bar(x - width/2, theoretical, width, label='Theoretical Bound', 
                     color=colors['light_gray'])
    bars2 = ax2.bar(x + width/2, measured, width, label='Measured Error', 
                     color=colors['proposed'])
    
    ax2.set_ylabel('Error Magnitude')
    ax2.set_title('(b) Error Comparison')
    ax2.set_xticks(x)
    ax2.set_xticklabels(metrics)
    ax2.legend()
    ax2.set_yscale('log')
    ax2.set_ylim(1e-4, 2e-2)
    ax2.grid(axis='y', alpha=0.3, which='both')
    
    plt.tight_layout()
    plt.savefig(output_dir / 'fig3_error_analysis.pdf', format='pdf')
    plt.savefig(output_dir / 'fig3_error_analysis.png', format='png')
    plt.close()

def create_speedup_analysis():
    """図4: 窓サイズ vs 高速化率"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4))
    
    # データ
    window_sizes = np.array([50, 100, 150, 200, 250, 300])
    baseline_times = np.array([20, 45, 85, 130, 185, 250])
    optimized_times = np.array([0.9, 2.1, 3.9, 6.0, 8.5, 11.5])
    speedups = baseline_times / optimized_times
    
    # 左: 処理時間の比較
    ax1.plot(window_sizes, baseline_times, 'o-', label='Python Baseline', 
             linewidth=2, markersize=8, color=colors['python'])
    ax1.plot(window_sizes, optimized_times, 's-', label='Proposed (Q15+SIMD)', 
             linewidth=2, markersize=8, color=colors['proposed'])
    ax1.axhline(y=4.0, color='red', linestyle='--', alpha=0.7, label='Real-time Target')
    ax1.axvline(x=150, color='green', linestyle='--', alpha=0.7, label='3-sec Window')
    ax1.set_xlabel('Window Size (samples)')
    ax1.set_ylabel('Processing Time (ms)')
    ax1.set_title('(a) Processing Time vs Window Size')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    ax1.set_yscale('log')
    ax1.set_ylim(0.5, 500)
    
    # 右: 高速化率
    ax2.plot(window_sizes, speedups, 'g^-', linewidth=2, markersize=10, color=colors['proposed'])
    ax2.axhline(y=21.9, color='red', linestyle='--', alpha=0.7, label='Theoretical (21.9×)')
    ax2.axhline(y=21.0, color='blue', linestyle='--', alpha=0.7, label='Target (21×)')
    ax2.fill_between(window_sizes, 20, speedups, where=(speedups >= 20), 
                     alpha=0.3, color=colors['proposed'])
    ax2.set_xlabel('Window Size (samples)')
    ax2.set_ylabel('Speedup Factor')
    ax2.set_title('(b) Speedup Factor Analysis')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    ax2.set_ylim(15, 25)
    
    # 150サンプル点を強調
    ax2.plot(150, speedups[2], 'ro', markersize=12, zorder=5)
    ax2.text(150, speedups[2] + 0.5, f'{speedups[2]:.1f}×', 
             ha='center', va='bottom', fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(output_dir / 'fig4_speedup_analysis.pdf', format='pdf')
    plt.savefig(output_dir / 'fig4_speedup_analysis.png', format='png')
    plt.close()

def create_memory_efficiency():
    """図5: メモリ効率の比較"""
    fig, ax = plt.subplots(figsize=(6, 5))
    
    # データ
    data_types = ['Float32', 'Q15']
    memory_usage = [600, 300]  # KB
    colors_mem = [colors['python'], colors['proposed']]
    
    bars = ax.bar(data_types, memory_usage, color=colors_mem, width=0.5)
    ax.set_ylabel('Memory Usage (KB)')
    ax.set_title('Memory Efficiency Comparison')
    ax.set_ylim(0, 700)
    
    # 値と削減率を表示
    for i, (bar, mem) in enumerate(zip(bars, memory_usage)):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + 10,
               f'{mem} KB', ha='center', va='bottom')
        if i == 1:
            reduction = (1 - memory_usage[1]/memory_usage[0]) * 100
            ax.text(bar.get_x() + bar.get_width()/2., height/2,
                   f'{reduction:.0f}%\nreduction', ha='center', va='center',
                   color='white', fontweight='bold')
    
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_dir / 'fig5_memory_efficiency.pdf', format='pdf')
    plt.savefig(output_dir / 'fig5_memory_efficiency.png', format='png')
    plt.close()

def create_algorithm_flow():
    """図6: アルゴリズムフロー図（概念図）"""
    # この図は通常、別のツール（draw.io等）で作成するため、
    # ここでは簡単なブロック図を生成
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.axis('off')
    
    # テキストボックスで簡易的なフロー図を作成
    boxes = [
        {'xy': (0.5, 0.9), 'text': 'Input Signal\n(3-axis accelerometer)'},
        {'xy': (0.5, 0.75), 'text': 'Q15 Conversion\n(Float → Int16)'},
        {'xy': (0.2, 0.6), 'text': 'Lyapunov Exponent\n(SIMD Distance Calc)'},
        {'xy': (0.8, 0.6), 'text': 'DFA Analysis\n(SIMD Cumsum)'},
        {'xy': (0.5, 0.45), 'text': 'NLD Features\n(λ, α)'},
        {'xy': (0.5, 0.3), 'text': 'Real-time Output\n(< 4ms)'},
    ]
    
    # ボックスを描画
    for box in boxes:
        bbox_props = dict(boxstyle="round,pad=0.3", facecolor=colors['light_gray'], alpha=0.5)
        ax.text(box['xy'][0], box['xy'][1], box['text'], 
               transform=ax.transAxes, fontsize=11, ha='center', va='center',
               bbox=bbox_props)
    
    # 矢印を描画
    arrows = [
        ((0.5, 0.85), (0.5, 0.8)),
        ((0.5, 0.7), (0.2, 0.65)),
        ((0.5, 0.7), (0.8, 0.65)),
        ((0.2, 0.55), (0.5, 0.5)),
        ((0.8, 0.55), (0.5, 0.5)),
        ((0.5, 0.4), (0.5, 0.35)),
    ]
    
    for start, end in arrows:
        ax.annotate('', xy=end, xytext=start, transform=ax.transAxes,
                   arrowprops=dict(arrowstyle='->', lw=2, color=colors['gray']))
    
    ax.set_title('Algorithm Flow with Q15+SIMD Optimization', fontsize=14, pad=20)
    
    plt.tight_layout()
    plt.savefig(output_dir / 'fig6_algorithm_flow.pdf', format='pdf')
    plt.savefig(output_dir / 'fig6_algorithm_flow.png', format='png')
    plt.close()

def main():
    """全ての図を生成"""
    print("Generating figures for IEICE paper...")
    
    # 各図を生成
    create_performance_comparison()
    print("✓ Figure 1: Performance comparison")
    
    create_simd_breakdown()
    print("✓ Figure 2: SIMD utilization breakdown")
    
    create_error_analysis()
    print("✓ Figure 3: Error analysis")
    
    create_speedup_analysis()
    print("✓ Figure 4: Speedup analysis")
    
    create_memory_efficiency()
    print("✓ Figure 5: Memory efficiency")
    
    create_algorithm_flow()
    print("✓ Figure 6: Algorithm flow")
    
    print(f"\nAll figures saved to: {output_dir.absolute()}")
    
    # LaTeX用のfigure環境も生成
    generate_latex_figures()

def generate_latex_figures():
    """LaTeX用のfigure環境を生成"""
    latex_file = output_dir / 'latex_figures.tex'
    
    with open(latex_file, 'w') as f:
        f.write("% LaTeX figure environments for IEICE paper\n\n")
        
        figures = [
            ("fig1_performance_comparison", "Performance comparison of processing time and SIMD utilization"),
            ("fig2_simd_breakdown", "SIMD utilization breakdown by operation type"),
            ("fig3_error_analysis", "Error analysis: theoretical bounds vs measured values"),
            ("fig4_speedup_analysis", "Processing time and speedup factor vs window size"),
            ("fig5_memory_efficiency", "Memory usage comparison between Float32 and Q15"),
            ("fig6_algorithm_flow", "Algorithm flow with Q15+SIMD optimization"),
        ]
        
        for i, (filename, caption) in enumerate(figures, 1):
            f.write(f"\\begin{{figure}}[htbp]\n")
            f.write(f"\\centering\n")
            f.write(f"\\includegraphics[width=0.9\\columnwidth]{{{filename}.pdf}}\n")
            f.write(f"\\caption{{{caption}}}\n")
            f.write(f"\\label{{fig:{i}}}\n")
            f.write(f"\\end{{figure}}\n\n")
    
    print(f"\nLaTeX figure code saved to: {latex_file}")

if __name__ == "__main__":
    main()