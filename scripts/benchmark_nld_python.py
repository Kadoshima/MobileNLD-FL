#!/usr/bin/env python3
"""
Benchmark Nonlinear Dynamics calculations in Python
for fair comparison with Swift Q15 implementation
"""

import numpy as np
import time
from scipy.spatial.distance import cdist
from scipy.stats import linregress
import warnings
warnings.filterwarnings('ignore')

def lyapunov_exponent(signal, embedding_dim=5, delay=4, sampling_rate=50):
    """
    Calculate Lyapunov exponent using Rosenstein method
    This is the actual algorithm implemented in Swift
    """
    # Create embedded matrix
    n = len(signal)
    m = embedding_dim
    tau = delay
    
    N = n - (m - 1) * tau
    if N <= 0:
        return 0.0
    
    # Embedding
    embedded = np.zeros((N, m))
    for i in range(N):
        for j in range(m):
            embedded[i, j] = signal[i + j * tau]
    
    # Find nearest neighbors
    min_sep = 10  # Minimum temporal separation
    divergence = []
    
    for i in range(N - min_sep):
        # Current point
        current = embedded[i]
        
        # Find nearest neighbor with temporal separation
        min_dist = float('inf')
        nearest_idx = -1
        
        for j in range(N):
            if abs(i - j) >= min_sep:
                dist = np.linalg.norm(current - embedded[j])
                if dist < min_dist and dist > 0:
                    min_dist = dist
                    nearest_idx = j
        
        if nearest_idx >= 0:
            # Track divergence
            div_series = []
            for k in range(min(10, min(N - i - 1, N - nearest_idx - 1))):
                d1 = embedded[i + k]
                d2 = embedded[nearest_idx + k]
                dist = np.linalg.norm(d1 - d2)
                if dist > 0:
                    div_series.append(np.log(dist))
            
            if len(div_series) > 0:
                divergence.append(div_series)
    
    # Calculate average divergence
    if len(divergence) == 0:
        return 0.0
    
    # Average across all reference points
    max_len = max(len(d) for d in divergence)
    avg_divergence = []
    
    for k in range(max_len):
        values = [d[k] for d in divergence if k < len(d)]
        if values:
            avg_divergence.append(np.mean(values))
    
    # Linear regression to get slope (Lyapunov exponent)
    if len(avg_divergence) < 2:
        return 0.0
    
    x = np.arange(len(avg_divergence))
    slope, _, _, _, _ = linregress(x, avg_divergence)
    
    return slope * sampling_rate

def dfa_alpha(signal, min_box_size=4, max_box_size=64):
    """
    Calculate DFA (Detrended Fluctuation Analysis) alpha
    This is the actual algorithm implemented in Swift
    """
    n = len(signal)
    
    # Cumulative sum
    mean_val = np.mean(signal)
    y = np.cumsum(signal - mean_val)
    
    # Box sizes
    box_sizes = []
    current = min_box_size
    while current <= min(max_box_size, n // 4):
        box_sizes.append(current)
        current = int(current * 1.5)
    
    if len(box_sizes) < 2:
        return 1.0
    
    fluctuations = []
    
    for box_size in box_sizes:
        n_boxes = n // box_size
        if n_boxes == 0:
            continue
            
        # Calculate fluctuation for this box size
        f_box = []
        
        for i in range(n_boxes):
            start = i * box_size
            end = start + box_size
            
            if end > n:
                break
                
            # Local trend (linear fit)
            x_fit = np.arange(box_size)
            y_segment = y[start:end]
            
            # Linear regression
            coef = np.polyfit(x_fit, y_segment, 1)
            fit = np.polyval(coef, x_fit)
            
            # Detrended fluctuation
            residual = y_segment - fit
            f_box.append(np.sqrt(np.mean(residual**2)))
        
        if f_box:
            fluctuations.append((box_size, np.mean(f_box)))
    
    # Log-log regression to find alpha
    if len(fluctuations) < 2:
        return 1.0
    
    log_n = np.log([f[0] for f in fluctuations])
    log_f = np.log([f[1] for f in fluctuations])
    
    alpha, _, _, _, _ = linregress(log_n, log_f)
    return alpha

def generate_test_signal(length=150, sampling_rate=50):
    """Generate test signal similar to Swift implementation"""
    t = np.arange(length) / sampling_rate
    # Sinusoidal with noise
    signal = 0.5 * np.sin(2 * np.pi * 0.5 * t) + 0.1 * np.random.randn(length)
    return signal

def benchmark_lyapunov():
    """Benchmark Lyapunov exponent calculation"""
    print("Benchmarking Lyapunov Exponent (Python Float32)...")
    
    # 3-second window
    signal = generate_test_signal(150, 50)
    
    # Warm up
    for _ in range(3):
        lyapunov_exponent(signal)
    
    # Measure
    times = []
    for _ in range(10):
        start = time.time()
        result = lyapunov_exponent(signal, embedding_dim=5, delay=4)
        end = time.time()
        times.append((end - start) * 1000)  # ms
    
    avg_time = np.mean(times)
    std_time = np.std(times)
    
    print(f"  Average time: {avg_time:.2f}ms ± {std_time:.2f}ms")
    print(f"  Result: {result:.4f}")
    
    return avg_time

def benchmark_dfa():
    """Benchmark DFA calculation"""
    print("\nBenchmarking DFA (Python Float32)...")
    
    # 3-second window
    signal = generate_test_signal(150, 50)
    
    # Warm up
    for _ in range(3):
        dfa_alpha(signal)
    
    # Measure
    times = []
    for _ in range(10):
        start = time.time()
        result = dfa_alpha(signal, min_box_size=4, max_box_size=32)
        end = time.time()
        times.append((end - start) * 1000)  # ms
    
    avg_time = np.mean(times)
    std_time = np.std(times)
    
    print(f"  Average time: {avg_time:.2f}ms ± {std_time:.2f}ms")
    print(f"  Result: {result:.4f}")
    
    return avg_time

def benchmark_large_dfa():
    """Benchmark DFA with larger data"""
    print("\nBenchmarking DFA with 1000 samples (Python Float32)...")
    
    signal = generate_test_signal(1000, 50)
    
    start = time.time()
    result = dfa_alpha(signal, min_box_size=4, max_box_size=64)
    end = time.time()
    
    elapsed = (end - start) * 1000
    print(f"  Time: {elapsed:.2f}ms")
    print(f"  Result: {result:.4f}")
    
    return elapsed

if __name__ == "__main__":
    print("=== Python NLD Benchmark ===")
    print("Running on standard Python with NumPy/SciPy")
    print("Algorithm implementations match Swift version")
    print()
    
    # Run benchmarks
    lye_time = benchmark_lyapunov()
    dfa_time = benchmark_dfa()
    dfa_large_time = benchmark_large_dfa()
    
    print("\n=== Summary ===")
    print(f"Lyapunov (150 samples): {lye_time:.2f}ms")
    print(f"DFA (150 samples): {dfa_time:.2f}ms")
    print(f"DFA (1000 samples): {dfa_large_time:.2f}ms")
    
    # Compare with Swift results
    print("\n=== Comparison with Swift Q15+SIMD ===")
    swift_lye = 8.58  # ms
    swift_dfa = 0.32  # ms
    
    print(f"Lyapunov speedup: {lye_time/swift_lye:.1f}x")
    print(f"DFA speedup: {dfa_time/swift_dfa:.1f}x")