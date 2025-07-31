#!/usr/bin/env python3
"""
実験結果の統計分析とグラフ化スクリプト
実験計画 5.4 SIMD Optimization Effect Evaluation用
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
import argparse
import os
from datetime import datetime

# Set style for publication-quality figures
plt.style.use('seaborn-v0_8-paper')
sns.set_palette("Set2")

def load_experiment_data(csv_path):
    """実験結果CSVファイルを読み込む"""
    df = pd.read_csv(csv_path)
    return df

def calculate_statistics(df):
    """統計量を計算"""
    # 実装ごとの平均処理時間
    time_stats = df.groupby('implementation')['time_ms'].agg(['mean', 'std', 'min', 'max'])
    
    # スカラー実装に対するスピードアップ
    scalar_times = df[df['implementation'] == 'Scalar'].groupby(['config_length', 'config_dim'])['time_ms'].mean()
    
    speedup_data = []
    for impl in df['implementation'].unique():
        if impl != 'Scalar':
            impl_times = df[df['implementation'] == impl].groupby(['config_length', 'config_dim'])['time_ms'].mean()
            speedup = scalar_times / impl_times
            speedup_data.append({
                'implementation': impl,
                'mean_speedup': speedup.mean(),
                'std_speedup': speedup.std(),
                'max_speedup': speedup.max(),
                'min_speedup': speedup.min()
            })
    
    speedup_df = pd.DataFrame(speedup_data)
    
    return time_stats, speedup_df

def plot_performance_comparison(df, output_dir):
    """パフォーマンス比較グラフを作成"""
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # 1. 処理時間 vs データ長
    ax = axes[0, 0]
    for impl in df['implementation'].unique():
        impl_data = df[df['implementation'] == impl]
        grouped = impl_data.groupby('config_length')['time_ms'].mean()
        ax.plot(grouped.index, grouped.values, marker='o', label=impl, linewidth=2)
    
    ax.set_xlabel('Data Length')
    ax.set_ylabel('Processing Time (ms)')
    ax.set_title('Processing Time vs Data Length')
    ax.set_xscale('log')
    ax.set_yscale('log')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 2. SIMD利用率
    ax = axes[0, 1]
    simd_data = df.groupby('implementation')['simd_percent'].mean().sort_values(ascending=False)
    bars = ax.bar(range(len(simd_data)), simd_data.values)
    ax.set_xticks(range(len(simd_data)))
    ax.set_xticklabels(simd_data.index, rotation=45, ha='right')
    ax.set_ylabel('SIMD Utilization (%)')
    ax.set_title('Average SIMD Utilization by Implementation')
    ax.set_ylim(0, 100)
    
    # 値をバーの上に表示
    for i, (bar, value) in enumerate(zip(bars, simd_data.values)):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1, 
                f'{value:.1f}%', ha='center', va='bottom')
    
    # 3. スピードアップ vs 埋め込み次元
    ax = axes[1, 0]
    for impl in ['SIMD Only', 'Adaptive Only', 'SIMD + Adaptive']:
        impl_data = df[df['implementation'] == impl]
        scalar_data = df[df['implementation'] == 'Scalar']
        
        speedups = []
        dims = sorted(df['config_dim'].unique())
        
        for dim in dims:
            scalar_time = scalar_data[scalar_data['config_dim'] == dim]['time_ms'].mean()
            impl_time = impl_data[impl_data['config_dim'] == dim]['time_ms'].mean()
            speedup = scalar_time / impl_time
            speedups.append(speedup)
        
        ax.plot(dims, speedups, marker='s', label=impl, linewidth=2)
    
    ax.set_xlabel('Embedding Dimension')
    ax.set_ylabel('Speedup vs Scalar')
    ax.set_title('Speedup vs Embedding Dimension')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 4. エネルギー効率
    ax = axes[1, 1]
    energy_data = df.groupby('implementation')['energy_mj'].mean().sort_values()
    bars = ax.barh(range(len(energy_data)), energy_data.values)
    ax.set_yticks(range(len(energy_data)))
    ax.set_yticklabels(energy_data.index)
    ax.set_xlabel('Energy Consumption (mJ)')
    ax.set_title('Average Energy Consumption')
    
    # 値を表示
    for i, (bar, value) in enumerate(zip(bars, energy_data.values)):
        ax.text(bar.get_width() + 0.01, bar.get_y() + bar.get_height()/2, 
                f'{value:.3f}', ha='left', va='center')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'performance_comparison.png'), dpi=300, bbox_inches='tight')
    plt.savefig(os.path.join(output_dir, 'performance_comparison.pdf'), bbox_inches='tight')
    plt.close()

def plot_detailed_speedup(df, output_dir):
    """詳細なスピードアップ分析グラフ"""
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # データ長ごとのスピードアップをボックスプロットで表示
    speedup_data = []
    
    for length in sorted(df['config_length'].unique()):
        scalar_times = df[(df['implementation'] == 'Scalar') & (df['config_length'] == length)]['time_ms']
        proposed_times = df[(df['implementation'] == 'SIMD + Adaptive') & (df['config_length'] == length)]['time_ms']
        
        if len(scalar_times) > 0 and len(proposed_times) > 0:
            speedups = scalar_times.values[:, np.newaxis] / proposed_times.values
            speedup_data.append({
                'length': length,
                'speedups': speedups.flatten()
            })
    
    # ボックスプロット
    positions = []
    speedup_values = []
    labels = []
    
    for i, data in enumerate(speedup_data):
        positions.extend([i] * len(data['speedups']))
        speedup_values.extend(data['speedups'])
        labels.append(f"{data['length']}")
    
    box_data = pd.DataFrame({'position': positions, 'speedup': speedup_values})
    
    bp = ax.boxplot([box_data[box_data['position'] == i]['speedup'].values 
                     for i in range(len(speedup_data))],
                    positions=range(len(speedup_data)),
                    widths=0.6,
                    patch_artist=True)
    
    # ボックスの色設定
    for patch in bp['boxes']:
        patch.set_facecolor('lightblue')
        patch.set_alpha(0.7)
    
    ax.set_xlabel('Data Length')
    ax.set_ylabel('Speedup (Proposed vs Scalar)')
    ax.set_title('Speedup Distribution across Different Data Lengths')
    ax.set_xticks(range(len(speedup_data)))
    ax.set_xticklabels(labels)
    
    # 目標ライン（例：4倍）
    ax.axhline(y=4, color='red', linestyle='--', alpha=0.5, label='Target (4x)')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'speedup_distribution.png'), dpi=300, bbox_inches='tight')
    plt.close()

def plot_simd_efficiency(df, output_dir):
    """SIMD効率の詳細分析"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
    
    # 1. SIMD利用率 vs ILP
    implementations = ['SIMD Only', 'SIMD + Adaptive']
    colors = ['blue', 'red']
    
    for impl, color in zip(implementations, colors):
        impl_data = df[df['implementation'] == impl]
        ax1.scatter(impl_data['simd_percent'], impl_data['ilp'], 
                   label=impl, alpha=0.6, s=100, color=color)
    
    ax1.set_xlabel('SIMD Utilization (%)')
    ax1.set_ylabel('Instructions per Cycle (ILP)')
    ax1.set_title('SIMD Utilization vs ILP')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # 2. キャッシュヒット率の比較
    cache_data = df.groupby(['implementation', 'config_length'])['cache_percent'].mean().unstack()
    cache_data.plot(kind='bar', ax=ax2)
    ax2.set_xlabel('Implementation')
    ax2.set_ylabel('Cache Hit Rate (%)')
    ax2.set_title('Cache Hit Rate by Implementation and Data Length')
    ax2.legend(title='Data Length', bbox_to_anchor=(1.05, 1), loc='upper left')
    ax2.set_xticklabels(ax2.get_xticklabels(), rotation=45, ha='right')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'simd_efficiency.png'), dpi=300, bbox_inches='tight')
    plt.close()

def generate_latex_table(df, output_dir):
    """LaTeX形式の結果テーブルを生成"""
    # 平均値を計算
    summary = df.groupby('implementation').agg({
        'time_ms': ['mean', 'std'],
        'simd_percent': 'mean',
        'cache_percent': 'mean',
        'ilp': 'mean',
        'energy_mj': 'mean'
    }).round(2)
    
    # スピードアップを計算
    scalar_time = summary.loc['Scalar', ('time_ms', 'mean')]
    summary['speedup'] = scalar_time / summary[('time_ms', 'mean')]
    
    # LaTeX形式で出力
    latex_content = """\\begin{table}[htbp]
\\centering
\\caption{Performance Comparison of Different Implementations}
\\label{tab:performance_comparison}
\\begin{tabular}{lccccccc}
\\hline
Implementation & Time (ms) & Speedup & SIMD (\\%) & Cache (\\%) & ILP & Energy (mJ) \\\\
\\hline
"""
    
    for impl in ['Scalar', 'SIMD Only', 'Adaptive Only', 'SIMD + Adaptive']:
        if impl in summary.index:
            row = summary.loc[impl]
            time_mean = row[('time_ms', 'mean')]
            time_std = row[('time_ms', 'std')]
            speedup = row['speedup']
            simd = row[('simd_percent', 'mean')]
            cache = row[('cache_percent', 'mean')]
            ilp = row[('ilp', 'mean')]
            energy = row[('energy_mj', 'mean')]
            
            latex_content += f"{impl} & {time_mean:.2f} ± {time_std:.2f} & {speedup:.2f}× & "
            latex_content += f"{simd:.1f} & {cache:.1f} & {ilp:.2f} & {energy:.3f} \\\\\n"
    
    latex_content += """\\hline
\\end{tabular}
\\end{table}"""
    
    # ファイルに保存
    with open(os.path.join(output_dir, 'performance_table.tex'), 'w') as f:
        f.write(latex_content)
    
    print("LaTeX table saved to performance_table.tex")

def perform_statistical_tests(df):
    """統計的有意性検定"""
    print("\n=== Statistical Significance Tests ===")
    
    # 各実装間の処理時間の有意差検定
    implementations = df['implementation'].unique()
    
    # Kruskal-Wallis test (non-parametric)
    groups = [df[df['implementation'] == impl]['time_ms'].values for impl in implementations]
    h_stat, p_value = stats.kruskal(*groups)
    
    print(f"\nKruskal-Wallis H-test for processing times:")
    print(f"  H-statistic: {h_stat:.4f}")
    print(f"  p-value: {p_value:.6f}")
    
    if p_value < 0.05:
        print("  Result: Significant differences exist between implementations (p < 0.05)")
        
        # Post-hoc pairwise comparisons
        print("\nPost-hoc pairwise comparisons (Mann-Whitney U test):")
        for i in range(len(implementations)):
            for j in range(i+1, len(implementations)):
                impl1, impl2 = implementations[i], implementations[j]
                data1 = df[df['implementation'] == impl1]['time_ms'].values
                data2 = df[df['implementation'] == impl2]['time_ms'].values
                
                u_stat, p_val = stats.mannwhitneyu(data1, data2, alternative='two-sided')
                print(f"  {impl1} vs {impl2}: p = {p_val:.6f}", end="")
                if p_val < 0.05:
                    print(" *")
                else:
                    print()

def main():
    parser = argparse.ArgumentParser(description='Analyze SIMD optimization experiment results')
    parser.add_argument('csv_file', help='Path to experiment results CSV file')
    parser.add_argument('--output-dir', default='analysis_results', 
                       help='Output directory for figures and tables')
    
    args = parser.parse_args()
    
    # 出力ディレクトリ作成
    os.makedirs(args.output_dir, exist_ok=True)
    
    # データ読み込み
    print(f"Loading data from {args.csv_file}...")
    df = load_experiment_data(args.csv_file)
    
    # 統計量計算
    print("\nCalculating statistics...")
    time_stats, speedup_df = calculate_statistics(df)
    
    print("\nProcessing Time Statistics:")
    print(time_stats)
    
    print("\nSpeedup Statistics:")
    print(speedup_df)
    
    # グラフ作成
    print("\nGenerating plots...")
    plot_performance_comparison(df, args.output_dir)
    plot_detailed_speedup(df, args.output_dir)
    plot_simd_efficiency(df, args.output_dir)
    
    # LaTeXテーブル生成
    print("\nGenerating LaTeX table...")
    generate_latex_table(df, args.output_dir)
    
    # 統計的検定
    perform_statistical_tests(df)
    
    print(f"\nAnalysis complete! Results saved to {args.output_dir}/")

if __name__ == "__main__":
    main()