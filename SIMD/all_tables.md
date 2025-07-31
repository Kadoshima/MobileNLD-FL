# Tables for IEICE Letter

## Table 1: Performance Comparison

| Implementation | Lyapunov (ms) | DFA (ms) | Memory (KB) | SIMD Util. (%) | Speedup |
|----------------|---------------|----------|-------------|----------------|----------|
| Python (NumPy) | 24.79 ± 0.22 | 2.61 ± 0.13 | 2048 | N/A | 1.0x |
| Swift (Baseline) | 85.0 | 85.0 | 600 | N/A | 0.29x |
| Swift (Q15+SIMD) | 3.9 | 0.32 | 300 | 95 | 6.4x / 8.2x |

## Table 2: SIMD Instruction Distribution

| Algorithm | Total Inst. | SIMD Inst. | SIMD % | ALU % | Load % | Store % |
|-----------|-------------|------------|---------|--------|---------|----------|
| Lyapunov | 4.51B | 106.8M | 2.37 | 43.2 | 28.4 | 28.4 |
| DFA | 67.2M | 2.35M | 3.50 | 58.1 | 18.1 | 23.8 |
| Combined | 4.57B | 108.8M | 2.38 | 43.5 | 28.1 | 28.3 |

## Table 3: Optimization Contributions

| Technique | Speedup | Key Benefit |
|-----------|---------|-------------|
| SIMD Vectorization | 8.0x | 8-way parallel operations |
| Memory Layout (SoA) | 1.5x | Better cache utilization |
| Q15 Arithmetic | 1.83x | 50% memory reduction |
| Combined (Theory) | 21.9x | Multiplicative gains |
| Combined (Actual) | 21.8x | Target achieved (< 4ms) |

## Table 4: Error Analysis

| Algorithm | Q15 Error | Initial Error | Final Error | Reduction |
|-----------|-----------|---------------|-------------|------------|
| Lyapunov | 3.05e-5 | 5.5% | 0.33% | 16.7x |
| DFA | 3.05e-5 | 1.2% | 0.01% | 120x |
