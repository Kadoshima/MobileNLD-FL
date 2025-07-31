#!/usr/bin/env python3
"""
Rösslerシステムのシミュレーションデータ生成スクリプト
実験計画 5.4 SIMD Optimization Effect Evaluation用

パラメータ: a=0.2, b=0.2, c=5.7
サンプリング: 100Hz相当
"""

import numpy as np
from scipy.integrate import odeint
import pandas as pd
import argparse
import os

def rossler_system(state, t, a=0.2, b=0.2, c=5.7):
    """
    Rösslerシステムの微分方程式
    dx/dt = -y - z
    dy/dt = x + a*y
    dz/dt = b + z*(x - c)
    """
    x, y, z = state
    dx = -y - z
    dy = x + a * y
    dz = b + z * (x - c)
    return [dx, dy, dz]

def generate_rossler_data(duration=10.0, sampling_rate=100, initial_state=[1, 1, 1],
                         a=0.2, b=0.2, c=5.7):
    """
    Rösslerシステムのデータを生成
    
    Args:
        duration: シミュレーション時間（秒）
        sampling_rate: サンプリングレート（Hz）
        initial_state: 初期状態 [x0, y0, z0]
        a, b, c: Rösslerシステムのパラメータ
    
    Returns:
        t: 時間配列
        solution: 状態変数の時系列 (N x 3)
    """
    # 時間配列の生成
    num_points = int(duration * sampling_rate)
    t = np.linspace(0, duration, num_points)
    
    # ODEを解く
    solution = odeint(rossler_system, initial_state, t, args=(a, b, c))
    
    # 過渡応答を除去（最初の20%をスキップ）
    skip_transient = int(num_points * 0.2)
    t = t[skip_transient:]
    solution = solution[skip_transient:]
    
    return t, solution

def save_data(t, solution, output_dir, prefix="rossler"):
    """
    データをCSVファイルとして保存
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # 各変数を別々のCSVファイルに保存
    for i, var_name in enumerate(['x', 'y', 'z']):
        filename = os.path.join(output_dir, f"{prefix}_{var_name}.csv")
        df = pd.DataFrame({
            'time': t,
            var_name: solution[:, i]
        })
        df.to_csv(filename, index=False, float_format='%.6f')
        print(f"Saved: {filename}")
    
    # 全データを1つのファイルにも保存
    filename_all = os.path.join(output_dir, f"{prefix}_all.csv")
    df_all = pd.DataFrame({
        'time': t,
        'x': solution[:, 0],
        'y': solution[:, 1],
        'z': solution[:, 2]
    })
    df_all.to_csv(filename_all, index=False, float_format='%.6f')
    print(f"Saved: {filename_all}")
    
    # Q15形式に変換したデータも保存（-1〜1の範囲に正規化）
    # 各変数の最大絶対値で正規化
    max_abs = np.max(np.abs(solution), axis=0)
    normalized = solution / max_abs
    
    # Q15スケール（2^15 - 1 = 32767）
    q15_scale = 32767
    q15_data = (normalized * q15_scale).astype(np.int16)
    
    filename_q15 = os.path.join(output_dir, f"{prefix}_q15.csv")
    df_q15 = pd.DataFrame({
        'time': t,
        'x_q15': q15_data[:, 0],
        'y_q15': q15_data[:, 1],
        'z_q15': q15_data[:, 2],
        'x_scale': [max_abs[0]] * len(t),
        'y_scale': [max_abs[1]] * len(t),
        'z_scale': [max_abs[2]] * len(t)
    })
    df_q15.to_csv(filename_q15, index=False)
    print(f"Saved: {filename_q15}")
    
    return max_abs

def generate_multi_dimensional_data(base_solution, dimensions=range(3, 21)):
    """
    次元を変えたテストデータを生成（3-20次元）
    基本的にはx変数を複製して高次元化
    """
    results = {}
    
    for dim in dimensions:
        if dim == 3:
            # 元の3次元データ
            results[dim] = base_solution
        else:
            # x変数に微小なノイズを加えて複製
            extended = np.zeros((len(base_solution), dim))
            extended[:, :3] = base_solution  # 最初の3次元は元のデータ
            
            # 残りの次元はxにノイズを加えたもの
            for i in range(3, dim):
                noise_level = 0.01 * (i - 2)  # 次元が増えるごとにノイズレベルを増加
                extended[:, i] = base_solution[:, 0] + np.random.normal(0, noise_level, len(base_solution))
            
            results[dim] = extended
    
    return results

def main():
    parser = argparse.ArgumentParser(description='Generate Rössler system data for experiments')
    parser.add_argument('--duration', type=float, default=100.0,
                       help='Simulation duration in seconds (default: 100)')
    parser.add_argument('--sampling-rate', type=int, default=100,
                       help='Sampling rate in Hz (default: 100)')
    parser.add_argument('--output-dir', type=str, default='../data/rossler',
                       help='Output directory (default: ../data/rossler)')
    parser.add_argument('--multi-dim', action='store_true',
                       help='Generate multi-dimensional test data (3-20 dims)')
    
    args = parser.parse_args()
    
    print(f"Generating Rössler system data...")
    print(f"Duration: {args.duration}s, Sampling rate: {args.sampling_rate}Hz")
    
    # 基本データの生成
    t, solution = generate_rossler_data(
        duration=args.duration,
        sampling_rate=args.sampling_rate
    )
    
    print(f"Generated {len(t)} data points")
    print(f"Data shape: {solution.shape}")
    
    # データの保存
    max_abs = save_data(t, solution, args.output_dir)
    print(f"\nNormalization scales: x={max_abs[0]:.3f}, y={max_abs[1]:.3f}, z={max_abs[2]:.3f}")
    
    # 多次元データの生成（オプション）
    if args.multi_dim:
        print("\nGenerating multi-dimensional data...")
        multi_dim_data = generate_multi_dimensional_data(solution)
        
        for dim, data in multi_dim_data.items():
            output_subdir = os.path.join(args.output_dir, f"dim_{dim}")
            save_data(t, data[:, :3], output_subdir, prefix=f"rossler_dim{dim}")
            
            # 高次元データ全体も保存
            if dim > 3:
                filename = os.path.join(output_subdir, f"rossler_dim{dim}_full.npy")
                np.save(filename, data)
                print(f"Saved {dim}D data: {filename}")
    
    # 統計情報の出力
    print("\nData statistics:")
    print(f"  X: min={solution[:, 0].min():.3f}, max={solution[:, 0].max():.3f}, "
          f"mean={solution[:, 0].mean():.3f}, std={solution[:, 0].std():.3f}")
    print(f"  Y: min={solution[:, 1].min():.3f}, max={solution[:, 1].max():.3f}, "
          f"mean={solution[:, 1].mean():.3f}, std={solution[:, 1].std():.3f}")
    print(f"  Z: min={solution[:, 2].min():.3f}, max={solution[:, 2].max():.3f}, "
          f"mean={solution[:, 2].mean():.3f}, std={solution[:, 2].std():.3f}")

if __name__ == "__main__":
    main()