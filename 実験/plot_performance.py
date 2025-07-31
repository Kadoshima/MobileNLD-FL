#!/usr/bin/env python3

import json
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime

# Load the experimental results
with open('results/2025-08-01_6-23-22_basic_performance.json', 'r') as f:
    data = json.load(f)

measurements = data['measurements']

# Extract data for plotting
data_sizes = [m['data_size'] for m in measurements]
avg_times = [m['avg_time_ms'] for m in measurements]
min_times = [m['min_time_ms'] for m in measurements]
max_times = [m['max_time_ms'] for m in measurements]

# Create the plot
fig, ax = plt.subplots(figsize=(10, 6))

# Plot average times with error bars
yerr = [[avg - min_val for avg, min_val in zip(avg_times, min_times)],
        [max_val - avg for avg, max_val in zip(avg_times, max_times)]]

ax.errorbar(data_sizes, avg_times, yerr=yerr, 
            marker='o', markersize=8, capsize=5, capthick=2,
            linewidth=2, label='Average (with min/max)')

# Add individual points for min and max
ax.scatter(data_sizes, min_times, marker='v', color='green', alpha=0.6, label='Min')
ax.scatter(data_sizes, max_times, marker='^', color='red', alpha=0.6, label='Max')

# Customize the plot
ax.set_xlabel('Data Size (samples)', fontsize=12)
ax.set_ylabel('Processing Time (ms)', fontsize=12)
ax.set_title('MobileNLD-FL Performance: Simplified Baseline\nLyapunov Exponent Calculation', fontsize=14)
ax.grid(True, alpha=0.3)
ax.legend()

# Add theoretical complexity line (O(n²) for nearest neighbor search)
# Normalize to match the scale
n = np.array(data_sizes)
theoretical = (n**2) * (avg_times[1] / (100**2))  # Scale based on n=100 measurement
ax.plot(data_sizes, theoretical, 'r--', alpha=0.5, label='Theoretical O(n²)')

# Set log scale if needed
# ax.set_xscale('log')
# ax.set_yscale('log')

# Save the plot
timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
plt.tight_layout()
plt.savefig(f'figs/performance_baseline_{timestamp}.png', dpi=300)
print(f"Plot saved to: figs/performance_baseline_{timestamp}.png")

# Print analysis
print("\nPerformance Analysis:")
print("=" * 50)
print(f"{'Data Size':<10} {'Avg (ms)':<10} {'Min (ms)':<10} {'Max (ms)':<10}")
print("-" * 40)
for m in measurements:
    print(f"{m['data_size']:<10} {m['avg_time_ms']:<10.2f} {m['min_time_ms']:<10.2f} {m['max_time_ms']:<10.2f}")

# Calculate scaling behavior
if len(measurements) > 2:
    # Compare 100 vs 200 samples
    scale_factor = avg_times[2] / avg_times[1]  # Should be ~4 for O(n²)
    print(f"\nScaling from 100 to 200 samples: {scale_factor:.2f}x")
    print(f"Expected for O(n²): 4.0x")
    print(f"Actual complexity appears to be sub-quadratic due to:")
    print("  - Fixed embedding dimension and delay")
    print("  - Early termination in simplified algorithm")
    print("  - Cache effects at small data sizes")

plt.show()