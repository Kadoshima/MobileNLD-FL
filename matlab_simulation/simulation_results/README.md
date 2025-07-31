# Mobile DFA Simulation - Reproducibility Package

This package contains all outputs from the `mobile_dfa_simulation_final.m` script.

## Contents

- `summary_results.csv`: Main performance comparison results in CSV format
- `full_simulation_data.mat`: Complete MATLAB workspace with all variables
- `summary_report.txt`: Comprehensive text summary of all findings
- `latex_table.tex`: LaTeX code for the results table
- `summary_plots.png`: PNG image of performance and energy plots
- `summary_plots.pdf`: PDF version for publication

## How to Reproduce

1. Ensure MATLAB R2020a or later is installed
2. Place all `.m` files in the same directory
3. Run `mobile_dfa_simulation_final.m`
4. Results will be generated in the `simulation_results/` folder

## Key Results Summary

- **Q15 Implementation Speedup**: 0.4x faster than naive MATLAB
- **Daily Battery Usage**: 77.36% of iPhone 13 battery
- **Processing Time**: 2.88 ms for 150-sample window
- **Statistical Significance**: p < 0.001 for all comparisons

## Citation

If you use this simulation in your research, please cite:

```bibtex
@article{mobilenld2025,
  title={Real-time Nonlinear Dynamics Analysis on Mobile Devices},
  author={MobileNLD-FL Team},
  journal={IEICE Transactions on Information and Systems},
  year={2025}
}
```

Generated: 31-Jul-2025 20:23:18
