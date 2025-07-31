#!/usr/bin/env python3
"""
Analyze SIMD utilization from Instruments CPU Counters data
Based on the actual counter configuration from the trace files
"""

import re
import sys
import os

def analyze_trace_files():
    """
    Analyze SIMD utilization from Instruments trace data
    
    Two traces available:
    1. all_counters_fixed.xml - tracks INST_ALL (all instructions)
    2. alu_counters_fixed.xml - tracks INST_SIMD_ALU, INST_SIMD_ST, INST_SIMD_LD
    """
    
    print("=== Instruments SIMD Utilization Analysis ===")
    print("Analysis based on iPhone 13 (A15 Bionic) CPU counters\n")
    
    # First, analyze the all instructions trace
    all_inst_file = "all_counters_fixed.xml"
    simd_inst_file = "alu_counters_fixed.xml"
    
    results = {}
    
    # Analyze ALL instructions trace
    if os.path.exists(all_inst_file):
        print(f"1. Analyzing {all_inst_file} (INST_ALL counter)")
        with open(all_inst_file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Extract PMC events - these are INST_ALL counts
        pmc_pattern = re.compile(r'<pmc-events[^>]*>(\d+)</pmc-events>')
        matches = pmc_pattern.findall(content)
        
        if matches:
            all_instructions = [int(m) for m in matches]
            total_all_inst = sum(all_instructions)
            
            results['all'] = {
                'samples': len(all_instructions),
                'total': total_all_inst,
                'average': total_all_inst / len(all_instructions) if all_instructions else 0
            }
            
            print(f"  Samples: {len(all_instructions):,}")
            print(f"  Total instructions: {total_all_inst:,}")
            print(f"  Average per sample: {results['all']['average']:,.0f}")
    
    # Analyze SIMD instructions trace
    if os.path.exists(simd_inst_file):
        print(f"\n2. Analyzing {simd_inst_file} (SIMD counters)")
        print("   Counters: INST_SIMD_ALU, INST_SIMD_ST, INST_SIMD_LD")
        
        with open(simd_inst_file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # For multiple counters, the format might be space-separated values
        # Extract counters-array or pmc-events
        array_pattern = re.compile(r'<counters-array[^>]*>([^<]+)</counters-array>')
        pmc_pattern = re.compile(r'<pmc-events[^>]*>([^<]+)</pmc-events>')
        
        array_matches = array_pattern.findall(content)
        pmc_matches = pmc_pattern.findall(content)
        
        simd_data = []
        
        # Try counters-array first (multiple values)
        if array_matches:
            for match in array_matches:
                values = match.strip().split()
                if len(values) >= 3:  # Should have 3 counters
                    simd_alu = int(values[0]) if values[0].isdigit() else 0
                    simd_st = int(values[1]) if values[1].isdigit() else 0
                    simd_ld = int(values[2]) if values[2].isdigit() else 0
                    simd_data.append({
                        'alu': simd_alu,
                        'st': simd_st,
                        'ld': simd_ld,
                        'total': simd_alu + simd_st + simd_ld
                    })
        elif pmc_matches:
            # Fallback to single values
            for match in pmc_matches:
                value = int(match.strip()) if match.strip().isdigit() else 0
                simd_data.append({'total': value})
        
        if simd_data:
            total_simd_alu = sum(d.get('alu', 0) for d in simd_data)
            total_simd_st = sum(d.get('st', 0) for d in simd_data)
            total_simd_ld = sum(d.get('ld', 0) for d in simd_data)
            total_simd = sum(d.get('total', 0) for d in simd_data)
            
            results['simd'] = {
                'samples': len(simd_data),
                'alu': total_simd_alu,
                'st': total_simd_st,
                'ld': total_simd_ld,
                'total': total_simd
            }
            
            print(f"  Samples: {len(simd_data):,}")
            print(f"  SIMD ALU instructions: {total_simd_alu:,}")
            print(f"  SIMD Store instructions: {total_simd_st:,}")
            print(f"  SIMD Load instructions: {total_simd_ld:,}")
            print(f"  Total SIMD instructions: {total_simd:,}")
            
            if total_simd > 0:
                print(f"\n  SIMD instruction breakdown:")
                print(f"    ALU: {total_simd_alu/total_simd*100:.1f}%")
                print(f"    Store: {total_simd_st/total_simd*100:.1f}%")
                print(f"    Load: {total_simd_ld/total_simd*100:.1f}%")
    
    # Calculate SIMD utilization if we have both traces
    print("\n=== SIMD Utilization Calculation ===")
    
    if 'all' in results and 'simd' in results:
        # Note: These traces might be from different runs, so direct comparison may not be perfect
        print("Note: Comparing data from different trace runs")
        print(f"All instructions trace: {results['all']['samples']} samples")
        print(f"SIMD instructions trace: {results['simd']['samples']} samples")
        
        # Estimate based on averages
        if results['all']['average'] > 0:
            avg_simd_per_sample = results['simd']['total'] / results['simd']['samples']
            estimated_utilization = (avg_simd_per_sample / results['all']['average']) * 100
            
            print(f"\nEstimated SIMD utilization: {estimated_utilization:.1f}%")
            print(f"(Based on average instructions per sample)")
    
    # Look for specific function patterns in the trace
    print("\n=== Function Analysis ===")
    
    # Check for our NLD functions in any available trace file
    for filename in ['a.txt', 'all_counters_fixed.xml', 'alu_counters_fixed.xml']:
        if os.path.exists(filename):
            print(f"\nSearching for NLD functions in {filename}...")
            
            nld_patterns = {
                'euclideanDistanceSIMD': 0,
                'lyapunovExponentOptimized': 0,
                'dfaAlphaOptimized': 0,
                'cumulativeSumSIMD': 0,
                'SIMDOptimizations': 0,
                'OptimizedNonlinearDynamics': 0,
                'vDSP': 0,
                'Accelerate': 0
            }
            
            with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
            for pattern in nld_patterns:
                count = len(re.findall(pattern, content, re.IGNORECASE))
                if count > 0:
                    nld_patterns[pattern] = count
            
            found_any = False
            for func, count in sorted(nld_patterns.items(), key=lambda x: x[1], reverse=True):
                if count > 0:
                    found_any = True
                    print(f"  {func}: {count} occurrences")
            
            if not found_any:
                print("  No NLD-specific functions found in trace")
            
            break  # Only check first available file

if __name__ == "__main__":
    analyze_trace_files()