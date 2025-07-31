#!/usr/bin/env python3
"""
Generate LaTeX tables for IEICE letter
"""

import pandas as pd
import numpy as np

def generate_performance_table():
    """Table 1: Performance comparison across implementations"""
    
    data = {
        'Implementation': ['Python (NumPy)', 'Swift (Baseline)', 'Swift (Q15+SIMD)'],
        'Lyapunov (ms)': ['24.79 ± 0.22', '85.0', '3.9'],
        'DFA (ms)': ['2.61 ± 0.13', '85.0', '0.32'],
        'Memory (KB)': ['2048', '600', '300'],
        'SIMD Util. (%)': ['N/A', 'N/A', '95'],
        'Speedup': ['1.0x', '0.29x', '6.4x / 8.2x']
    }
    
    df = pd.DataFrame(data)
    
    # Generate LaTeX table
    latex_table = r"""
\begin{table}[htbp]
\centering
\caption{Performance Comparison of NLD Implementations}
\label{tab:performance}
\begin{tabular}{lrrrrr}
\hline
Implementation & Lyapunov (ms) & DFA (ms) & Memory (KB) & SIMD Util. (\%) & Speedup \\
\hline
"""
    
    for _, row in df.iterrows():
        latex_table += f"{row['Implementation']} & {row['Lyapunov (ms)']} & {row['DFA (ms)']} & {row['Memory (KB)']} & {row['SIMD Util. (%)']} & {row['Speedup']} \\\\\n"
    
    latex_table += r"""\hline
\end{tabular}
\end{table}
"""
    
    with open('table1_performance.tex', 'w') as f:
        f.write(latex_table)
    
    print("Generated: table1_performance.tex")
    return latex_table

def generate_simd_analysis_table():
    """Table 2: SIMD instruction analysis"""
    
    data = {
        'Algorithm': ['Lyapunov Exponent', 'DFA', 'Combined'],
        'Total Inst.': ['4.51B', '67.2M', '4.57B'],
        'SIMD Inst.': ['106.8M', '2.35M', '108.8M'],
        'SIMD Ratio (%)': ['2.37', '3.50', '2.38'],
        'ALU (%)': ['43.2', '58.1', '43.5'],
        'Load (%)': ['28.4', '18.1', '28.1'],
        'Store (%)': ['28.4', '23.8', '28.3']
    }
    
    df = pd.DataFrame(data)
    
    latex_table = r"""
\begin{table}[htbp]
\centering
\caption{SIMD Instruction Distribution Analysis}
\label{tab:simd_analysis}
\begin{tabular}{lrrrrrr}
\hline
Algorithm & Total Inst. & SIMD Inst. & SIMD \% & ALU \% & Load \% & Store \% \\
\hline
"""
    
    for _, row in df.iterrows():
        latex_table += f"{row['Algorithm']} & {row['Total Inst.']} & {row['SIMD Inst.']} & {row['SIMD Ratio (%)']} & {row['ALU (%)']} & {row['Load (%)']} & {row['Store (%)']} \\\\\n"
    
    latex_table += r"""\hline
\end{tabular}
\end{table}
"""
    
    with open('table2_simd_analysis.tex', 'w') as f:
        f.write(latex_table)
    
    print("Generated: table2_simd_analysis.tex")
    return latex_table

def generate_optimization_breakdown_table():
    """Table 3: Optimization technique contributions"""
    
    data = {
        'Optimization Technique': [
            'SIMD Vectorization',
            'Memory Layout (SoA)',
            'Q15 Arithmetic',
            'Combined (Theoretical)',
            'Combined (Measured)'
        ],
        'Speedup Factor': ['8.0x', '1.5x', '1.83x', '21.9x', '21.8x'],
        'Key Benefit': [
            '8-way parallel operations',
            'Better cache utilization',
            '50% memory reduction',
            'Multiplicative gains',
            'Target achieved (< 4ms)'
        ]
    }
    
    df = pd.DataFrame(data)
    
    latex_table = r"""
\begin{table}[htbp]
\centering
\caption{Optimization Technique Contributions}
\label{tab:optimization}
\begin{tabular}{lrl}
\hline
Optimization Technique & Speedup & Key Benefit \\
\hline
"""
    
    for _, row in df.iterrows():
        latex_table += f"{row['Optimization Technique']} & {row['Speedup Factor']} & {row['Key Benefit']} \\\\\n"
    
    latex_table += r"""\hline
\end{tabular}
\end{table}
"""
    
    with open('table3_optimization.tex', 'w') as f:
        f.write(latex_table)
    
    print("Generated: table3_optimization.tex")
    return latex_table

def generate_error_analysis_table():
    """Table 4: Error analysis and bounds"""
    
    data = {
        'Algorithm': ['Lyapunov Exponent', 'DFA'],
        'Q15 Quant. Error': ['3.05e-5', '3.05e-5'],
        'Algorithmic Error': ['5.5%', '1.2%'],
        'Final Error Bound': ['0.33%', '0.01%'],
        'Error Reduction': ['16.7x', '120x']
    }
    
    df = pd.DataFrame(data)
    
    latex_table = r"""
\begin{table}[htbp]
\centering
\caption{Error Analysis and Compensation Results}
\label{tab:error}
\begin{tabular}{lrrrr}
\hline
Algorithm & Q15 Error & Initial Error & Final Error & Reduction \\
\hline
"""
    
    for _, row in df.iterrows():
        latex_table += f"{row['Algorithm']} & {row['Q15 Quant. Error']} & {row['Algorithmic Error']} & {row['Final Error Bound']} & {row['Error Reduction']} \\\\\n"
    
    latex_table += r"""\hline
\end{tabular}
\end{table}
"""
    
    with open('table4_error_analysis.tex', 'w') as f:
        f.write(latex_table)
    
    print("Generated: table4_error_analysis.tex")
    return latex_table

def generate_all_tables():
    """Generate all tables for the paper"""
    
    print("Generating LaTeX tables for IEICE letter...")
    print("=" * 50)
    
    # Performance comparison
    table1 = generate_performance_table()
    print("\nTable 1 Preview:")
    print(table1[:200] + "...")
    
    # SIMD analysis
    table2 = generate_simd_analysis_table()
    print("\nTable 2 Preview:")
    print(table2[:200] + "...")
    
    # Optimization breakdown
    table3 = generate_optimization_breakdown_table()
    print("\nTable 3 Preview:")
    print(table3[:200] + "...")
    
    # Error analysis
    table4 = generate_error_analysis_table()
    print("\nTable 4 Preview:")
    print(table4[:200] + "...")
    
    print("\n" + "=" * 50)
    print("All tables generated successfully!")
    print("\nFiles created:")
    print("- table1_performance.tex")
    print("- table2_simd_analysis.tex")
    print("- table3_optimization.tex")
    print("- table4_error_analysis.tex")
    
    # Also create a combined markdown version for easy viewing
    with open('all_tables.md', 'w') as f:
        f.write("# Tables for IEICE Letter\n\n")
        
        f.write("## Table 1: Performance Comparison\n\n")
        f.write("| Implementation | Lyapunov (ms) | DFA (ms) | Memory (KB) | SIMD Util. (%) | Speedup |\n")
        f.write("|----------------|---------------|----------|-------------|----------------|----------|\n")
        f.write("| Python (NumPy) | 24.79 ± 0.22 | 2.61 ± 0.13 | 2048 | N/A | 1.0x |\n")
        f.write("| Swift (Baseline) | 85.0 | 85.0 | 600 | N/A | 0.29x |\n")
        f.write("| Swift (Q15+SIMD) | 3.9 | 0.32 | 300 | 95 | 6.4x / 8.2x |\n\n")
        
        f.write("## Table 2: SIMD Instruction Distribution\n\n")
        f.write("| Algorithm | Total Inst. | SIMD Inst. | SIMD % | ALU % | Load % | Store % |\n")
        f.write("|-----------|-------------|------------|---------|--------|---------|----------|\n")
        f.write("| Lyapunov | 4.51B | 106.8M | 2.37 | 43.2 | 28.4 | 28.4 |\n")
        f.write("| DFA | 67.2M | 2.35M | 3.50 | 58.1 | 18.1 | 23.8 |\n")
        f.write("| Combined | 4.57B | 108.8M | 2.38 | 43.5 | 28.1 | 28.3 |\n\n")
        
        f.write("## Table 3: Optimization Contributions\n\n")
        f.write("| Technique | Speedup | Key Benefit |\n")
        f.write("|-----------|---------|-------------|\n")
        f.write("| SIMD Vectorization | 8.0x | 8-way parallel operations |\n")
        f.write("| Memory Layout (SoA) | 1.5x | Better cache utilization |\n")
        f.write("| Q15 Arithmetic | 1.83x | 50% memory reduction |\n")
        f.write("| Combined (Theory) | 21.9x | Multiplicative gains |\n")
        f.write("| Combined (Actual) | 21.8x | Target achieved (< 4ms) |\n\n")
        
        f.write("## Table 4: Error Analysis\n\n")
        f.write("| Algorithm | Q15 Error | Initial Error | Final Error | Reduction |\n")
        f.write("|-----------|-----------|---------------|-------------|------------|\n")
        f.write("| Lyapunov | 3.05e-5 | 5.5% | 0.33% | 16.7x |\n")
        f.write("| DFA | 3.05e-5 | 1.2% | 0.01% | 120x |\n")
    
    print("\nAlso created: all_tables.md (Markdown version)")

if __name__ == "__main__":
    generate_all_tables()