#!/usr/bin/env python3
"""
Performance Analysis for 4-Implementation Comparison
Analyzes when adaptive optimization pays off
"""

import json
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import glob

def load_experiment_results(results_dir):
    """Load all JSON result files"""
    results = []
    json_files = glob.glob(f"{results_dir}/*.json")
    
    for file in json_files:
        try:
            with open(file, 'r') as f:
                data = json.load(f)
                results.append(data)
        except Exception as e:
            print(f"Error loading {file}: {e}")
    
    return results

def analyze_crossover_point(results):
    """Find where Proposed method becomes better than SIMD Only"""
    data_sizes = []
    simd_times = []
    proposed_times = []
    
    for result in results:
        size = result['dataSize']
        implementations = result['implementations']
        
        simd_result = next((impl for impl in implementations if impl['name'] == 'SIMD Only'), None)
        proposed_result = next((impl for impl in implementations if impl['name'] == 'Proposed'), None)
        
        if simd_result and proposed_result:
            data_sizes.append(size)
            simd_times.append(simd_result['avgTime'])
            proposed_times.append(proposed_result['avgTime'])
    
    # Sort by data size
    sorted_indices = np.argsort(data_sizes)
    data_sizes = [data_sizes[i] for i in sorted_indices]
    simd_times = [simd_times[i] for i in sorted_indices]
    proposed_times = [proposed_times[i] for i in sorted_indices]
    
    return data_sizes, simd_times, proposed_times

def calculate_overhead_model(data_sizes, simd_times, proposed_times):
    """Model the overhead of adaptive optimization"""
    if len(data_sizes) < 2:
        return None
    
    # Calculate overhead ratio
    overhead_ratios = []
    for i in range(len(data_sizes)):
        if simd_times[i] > 0:
            ratio = proposed_times[i] / simd_times[i]
            overhead_ratios.append(ratio)
    
    # Fit a model: overhead = base_overhead + adaptive_cost * log(n)
    # For small n, overhead dominates; for large n, benefits emerge
    
    print("\n📊 Overhead Analysis:")
    print(f"{'Data Size':<12} {'SIMD (ms)':<12} {'Proposed (ms)':<15} {'Overhead Ratio':<15}")
    print("-" * 60)
    
    for i in range(len(data_sizes)):
        print(f"{data_sizes[i]:<12} {simd_times[i]:<12.2f} {proposed_times[i]:<15.2f} {overhead_ratios[i]:<15.2f}")
    
    # Estimate crossover point
    for i in range(1, len(data_sizes)):
        if proposed_times[i] < simd_times[i]:
            print(f"\n✅ Crossover detected between {data_sizes[i-1]} and {data_sizes[i]} samples")
            return data_sizes[i]
    
    # Extrapolate if no crossover found
    if len(data_sizes) >= 2:
        # Linear extrapolation of overhead reduction
        slope = (overhead_ratios[-1] - overhead_ratios[0]) / (data_sizes[-1] - data_sizes[0])
        if slope < 0:  # Overhead is decreasing
            crossover = int(data_sizes[-1] + (1.0 - overhead_ratios[-1]) / (-slope))
            print(f"\n📈 Estimated crossover at ~{crossover} samples (extrapolated)")
            return crossover
    
    return None

def generate_recommendations(data_sizes, simd_times, proposed_times):
    """Generate optimization recommendations"""
    print("\n🎯 Optimization Recommendations:")
    print("-" * 50)
    
    if len(data_sizes) == 0:
        print("❌ No data available for analysis")
        return
    
    # Small data recommendation
    small_threshold = 500
    small_data = [(s, st, pt) for s, st, pt in zip(data_sizes, simd_times, proposed_times) if s <= small_threshold]
    
    if small_data:
        avg_overhead = np.mean([pt/st for s, st, pt in small_data if st > 0])
        print(f"\n1. Small data (≤{small_threshold} samples):")
        print(f"   - Average overhead: {avg_overhead:.2f}x")
        print(f"   - Recommendation: Use SIMD Only for minimal latency")
        print(f"   - Reason: Adaptive overhead ({avg_overhead-1:.1%}) not justified")
    
    # Large data potential
    if max(data_sizes) < 1000:
        print(f"\n2. Large data (>1000 samples):")
        print(f"   - Status: Not tested yet")
        print(f"   - Recommendation: Test with 1000, 2000, 5000 samples")
        print(f"   - Expected: Adaptive benefits emerge as O(n²) dominates")
    
    # Adaptive threshold
    if len(data_sizes) >= 3:
        print(f"\n3. Adaptive switching strategy:")
        print(f"   - Switch threshold: ~{int(np.mean(data_sizes))*2} samples")
        print(f"   - Implementation: if (n < threshold) use SIMD; else use Proposed")
    
    # NLD-specific insights
    print(f"\n4. NLD-specific optimizations:")
    print(f"   - Phase space reconstruction: Limited SIMD (sequential dependencies)")
    print(f"   - Distance matrix: Good SIMD potential (independent calculations)")
    print(f"   - Nearest neighbor: Poor SIMD (data-dependent branches)")
    print(f"   - Consider: Hybrid approach focusing SIMD on distance calculations only")

def plot_performance_comparison(data_sizes, simd_times, proposed_times):
    """Create performance comparison plot"""
    if len(data_sizes) < 2:
        print("Not enough data for plotting")
        return
    
    plt.figure(figsize=(10, 6))
    
    # Plot measured data
    plt.plot(data_sizes, simd_times, 'b-o', label='SIMD Only', linewidth=2)
    plt.plot(data_sizes, proposed_times, 'r-s', label='Proposed (Adaptive)', linewidth=2)
    
    # Add theoretical projections for larger sizes
    if max(data_sizes) < 1000:
        # Extrapolate to larger sizes
        extended_sizes = list(data_sizes) + [1000, 2000, 5000]
        
        # SIMD: roughly O(n²) for NLD
        simd_factor = simd_times[-1] / (data_sizes[-1] ** 2)
        extended_simd = list(simd_times) + [simd_factor * (n**2) for n in [1000, 2000, 5000]]
        
        # Proposed: O(n log n) with approximate algorithms
        proposed_factor = proposed_times[-1] / (data_sizes[-1] * np.log(data_sizes[-1]))
        extended_proposed = list(proposed_times) + [proposed_factor * (n * np.log(n)) for n in [1000, 2000, 5000]]
        
        plt.plot(extended_sizes[len(data_sizes):], extended_simd[len(data_sizes):], 
                'b--', alpha=0.5, label='SIMD (projected)')
        plt.plot(extended_sizes[len(data_sizes):], extended_proposed[len(data_sizes):], 
                'r--', alpha=0.5, label='Proposed (projected)')
    
    plt.xlabel('Data Size (samples)')
    plt.ylabel('Processing Time (ms)')
    plt.title('4-Implementation Performance Comparison')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.xscale('log')
    plt.yscale('log')
    
    # Add annotations
    for i, size in enumerate(data_sizes):
        if simd_times[i] > 0 and proposed_times[i] > 0:
            overhead = (proposed_times[i] / simd_times[i] - 1) * 100
            plt.annotate(f'{overhead:+.0f}%', 
                        xy=(size, proposed_times[i]), 
                        xytext=(5, 5), 
                        textcoords='offset points',
                        fontsize=8)
    
    plt.tight_layout()
    plt.savefig('/Users/kadoshima/Documents/MobileNLD-FL/実験/analysis/performance_comparison.png', dpi=150)
    print("\n📈 Plot saved to: analysis/performance_comparison.png")

def main():
    results_dir = "/Users/kadoshima/Documents/MobileNLD-FL/実験/results"
    
    print("🔍 Analyzing 4-Implementation Comparison Results")
    print("=" * 60)
    
    # Load results
    results = load_experiment_results(results_dir)
    
    if not results:
        print("❌ No results found in", results_dir)
        return
    
    print(f"\n📊 Found {len(results)} experiment results")
    
    # Analyze crossover point
    data_sizes, simd_times, proposed_times = analyze_crossover_point(results)
    
    if data_sizes:
        # Calculate overhead model
        crossover = calculate_overhead_model(data_sizes, simd_times, proposed_times)
        
        # Generate recommendations
        generate_recommendations(data_sizes, simd_times, proposed_times)
        
        # Plot results
        plot_performance_comparison(data_sizes, simd_times, proposed_times)
        
        # Summary
        print("\n" + "=" * 60)
        print("📝 Summary:")
        print(f"- Tested data sizes: {data_sizes}")
        print(f"- Current winner: {'SIMD Only' if all(p >= s for p, s in zip(proposed_times, simd_times)) else 'Mixed'}")
        print(f"- Recommendation: Test with larger data sizes (1000+ samples)")
        print(f"- Key insight: NLD's O(n²) complexity needs adaptive optimization for larger n")
    
if __name__ == "__main__":
    main()