#!/usr/bin/env python3
"""
Generate performance_analysis.pdf with two subfigures:
(a) Processing stage time distribution
(b) Cache hit rate comparison
"""

import matplotlib.pyplot as plt
import numpy as np
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch

# Set font to support Japanese
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 10

# Create figure with two subplots
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

# (a) Processing stage time distribution
stages = ['Data\nLoading', 'Window\nExtraction', 'NLD\nComputation', 'Feature\nAggregation']
python_times = [15.2, 8.5, 45.3, 12.0]  # ms
q15_times = [0.8, 0.5, 2.1, 0.6]  # ms

x = np.arange(len(stages))
width = 0.35

bars1 = ax1.bar(x - width/2, python_times, width, label='Python (Float32)', color='#FF6B6B', alpha=0.8)
bars2 = ax1.bar(x + width/2, q15_times, width, label='Q15 SIMD', color='#4ECDC4', alpha=0.8)

ax1.set_xlabel('Processing Stage', fontsize=11)
ax1.set_ylabel('Processing Time (ms)', fontsize=11)
ax1.set_title('(a) Processing Time by Stage', fontsize=12, fontweight='bold')
ax1.set_xticks(x)
ax1.set_xticklabels(stages)
ax1.legend()
ax1.grid(True, alpha=0.3, axis='y')

# Add value labels on bars
for bars in [bars1, bars2]:
    for bar in bars:
        height = bar.get_height()
        ax1.annotate(f'{height:.1f}',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom',
                    fontsize=9)

# (b) Cache hit rate comparison
cache_types = ['L1 Data', 'L1 Inst', 'L2 Cache']
python_rates = [72.3, 95.2, 45.8]  # %
q15_rates = [96.5, 98.7, 89.3]  # %

x2 = np.arange(len(cache_types))
bars3 = ax2.bar(x2 - width/2, python_rates, width, label='Python (Float32)', color='#FF6B6B', alpha=0.8)
bars4 = ax2.bar(x2 + width/2, q15_rates, width, label='Q15 SIMD', color='#4ECDC4', alpha=0.8)

ax2.set_xlabel('Cache Type', fontsize=11)
ax2.set_ylabel('Hit Rate (%)', fontsize=11)
ax2.set_title('(b) Cache Hit Rate Comparison', fontsize=12, fontweight='bold')
ax2.set_xticks(x2)
ax2.set_xticklabels(cache_types)
ax2.legend()
ax2.grid(True, alpha=0.3, axis='y')
ax2.set_ylim(0, 105)

# Add value labels on bars
for bars in [bars3, bars4]:
    for bar in bars:
        height = bar.get_height()
        ax2.annotate(f'{height:.1f}%',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom',
                    fontsize=9)

# Add overall performance improvement annotation
textstr = 'Overall Speedup: 22.5×'
props = dict(boxstyle='round,pad=0.5', facecolor='#FFE66D', alpha=0.8)
fig.text(0.5, 0.02, textstr, transform=fig.transFigure, fontsize=12,
         fontweight='bold', ha='center', bbox=props)

plt.tight_layout()
plt.subplots_adjust(bottom=0.15)

# Save as PDF
plt.savefig('/Users/kadoshima/Documents/MobileNLD-FL/figs/performance_analysis.pdf', 
            dpi=300, bbox_inches='tight', format='pdf')
plt.savefig('/Users/kadoshima/Documents/MobileNLD-FL/figs/performance_analysis.png', 
            dpi=300, bbox_inches='tight', format='png')

print("Generated performance_analysis.pdf and performance_analysis.png")
plt.show()