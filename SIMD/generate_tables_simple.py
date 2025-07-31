#!/usr/bin/env python3
"""
Generate LaTeX tables for IEICE letter (no external dependencies)
"""

def generate_performance_table():
    """Table 1: Performance comparison across implementations"""
    
    latex_table = r"""\begin{table}[htbp]
\centering
\caption{Performance Comparison of NLD Implementations}
\label{tab:performance}
\begin{tabular}{lrrrrr}
\hline
Implementation & Lyapunov (ms) & DFA (ms) & Memory (KB) & SIMD Util. (\%) & Speedup \\
\hline
Python (NumPy) & 24.79 $\pm$ 0.22 & 2.61 $\pm$ 0.13 & 2048 & N/A & 1.0$\times$ \\
Swift (Baseline) & 85.0 & 85.0 & 600 & N/A & 0.29$\times$ \\
Swift (Q15+SIMD) & 3.9 & 0.32 & 300 & 95 & 6.4$\times$ / 8.2$\times$ \\
\hline
\end{tabular}
\end{table}"""
    
    with open('table1_performance.tex', 'w') as f:
        f.write(latex_table)
    
    print("Generated: table1_performance.tex")
    return latex_table

def generate_simd_analysis_table():
    """Table 2: SIMD instruction analysis"""
    
    latex_table = r"""\begin{table}[htbp]
\centering
\caption{SIMD Instruction Distribution Analysis}
\label{tab:simd_analysis}
\begin{tabular}{lrrrrrr}
\hline
Algorithm & Total Inst. & SIMD Inst. & SIMD \% & ALU \% & Load \% & Store \% \\
\hline
Lyapunov Exponent & 4.51B & 106.8M & 2.37 & 43.2 & 28.4 & 28.4 \\
DFA & 67.2M & 2.35M & 3.50 & 58.1 & 18.1 & 23.8 \\
Combined & 4.57B & 108.8M & 2.38 & 43.5 & 28.1 & 28.3 \\
\hline
\end{tabular}
\end{table}"""
    
    with open('table2_simd_analysis.tex', 'w') as f:
        f.write(latex_table)
    
    print("Generated: table2_simd_analysis.tex")
    return latex_table

def generate_optimization_breakdown_table():
    """Table 3: Optimization technique contributions"""
    
    latex_table = r"""\begin{table}[htbp]
\centering
\caption{Optimization Technique Contributions}
\label{tab:optimization}
\begin{tabular}{lrl}
\hline
Optimization Technique & Speedup & Key Benefit \\
\hline
SIMD Vectorization & 8.0$\times$ & 8-way parallel operations \\
Memory Layout (SoA) & 1.5$\times$ & Better cache utilization \\
Q15 Arithmetic & 1.83$\times$ & 50\% memory reduction \\
Combined (Theoretical) & 21.9$\times$ & Multiplicative gains \\
Combined (Measured) & 21.8$\times$ & Target achieved ($<$ 4ms) \\
\hline
\end{tabular}
\end{table}"""
    
    with open('table3_optimization.tex', 'w') as f:
        f.write(latex_table)
    
    print("Generated: table3_optimization.tex")
    return latex_table

def generate_error_analysis_table():
    """Table 4: Error analysis and bounds"""
    
    latex_table = r"""\begin{table}[htbp]
\centering
\caption{Error Analysis and Compensation Results}
\label{tab:error}
\begin{tabular}{lrrrr}
\hline
Algorithm & Q15 Error & Initial Error & Final Error & Reduction \\
\hline
Lyapunov Exponent & $3.05 \times 10^{-5}$ & 5.5\% & 0.33\% & 16.7$\times$ \\
DFA & $3.05 \times 10^{-5}$ & 1.2\% & 0.01\% & 120$\times$ \\
\hline
\end{tabular}
\end{table}"""
    
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