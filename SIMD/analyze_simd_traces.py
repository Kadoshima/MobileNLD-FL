#!/usr/bin/env python3
import re
import sys
import os

def parse_instruments_data(directory):
    """
    Parse Instruments trace data to extract SIMD utilization metrics
    """
    
    print("=== SIMD Utilization Analysis from Instruments ===")
    print(f"Analyzing traces in: {directory}\n")
    
    # Analysis results
    results = {
        'all_counters': {'file': 'all_counters_fixed.xml', 'events': []},
        'alu_counters': {'file': 'alu_counters_fixed.xml', 'events': []}
    }
    
    # Process each XML file
    for key, info in results.items():
        filepath = os.path.join(directory, info['file'])
        if os.path.exists(filepath):
            print(f"Processing {info['file']}...")
            
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Extract PMC events
            pmc_pattern = re.compile(r'<pmc-events[^>]*>(\d+)</pmc-events>')
            matches = pmc_pattern.findall(content)
            
            if matches:
                info['events'] = [int(m) for m in matches]
                info['total'] = sum(info['events'])
                info['count'] = len(info['events'])
                info['avg'] = info['total'] / info['count'] if info['count'] > 0 else 0
                
                print(f"  Found {info['count']:,} samples")
                print(f"  Total events: {info['total']:,}")
                print(f"  Average: {info['avg']:,.0f}\n")
    
    # Look for specific function traces
    print("Searching for SIMD-related function calls...")
    
    # Common SIMD function patterns in ARM
    simd_patterns = [
        r'euclideanDistance',
        r'lyapunovExponent',
        r'dfaAlpha',
        r'SIMD',
        r'vDSP',
        r'Accelerate',
        r'NEON',
        r'vector'
    ]
    
    # Search in a.txt for detailed traces
    txt_file = os.path.join(directory, 'a.txt')
    if os.path.exists(txt_file):
        print(f"\nAnalyzing detailed traces in a.txt...")
        
        simd_functions = {}
        total_samples = 0
        
        with open(txt_file, 'r') as f:
            for line in f:
                total_samples += 1
                for pattern in simd_patterns:
                    if re.search(pattern, line, re.IGNORECASE):
                        if pattern not in simd_functions:
                            simd_functions[pattern] = 0
                        simd_functions[pattern] += 1
        
        if simd_functions:
            print("\nSIMD-related function occurrences:")
            for func, count in sorted(simd_functions.items(), key=lambda x: x[1], reverse=True):
                percentage = (count / total_samples * 100) if total_samples > 0 else 0
                print(f"  {func}: {count} ({percentage:.2f}%)")
    
    # Calculate estimated SIMD utilization
    print("\n=== SIMD Utilization Estimate ===")
    
    # Based on the PMC counter analysis
    if 'all_counters' in results and results['all_counters']['events']:
        all_events = results['all_counters']['events']
        
        # Filter out zero values and very small values (likely idle)
        active_events = [e for e in all_events if e > 1000]
        
        if active_events:
            avg_active = sum(active_events) / len(active_events)
            
            # Estimate SIMD utilization based on event patterns
            # High event counts often indicate SIMD operations
            high_activity = [e for e in active_events if e > avg_active * 0.8]
            simd_estimate = len(high_activity) / len(active_events) * 100
            
            print(f"Active samples: {len(active_events)}/{len(all_events)}")
            print(f"Average active event count: {avg_active:,.0f}")
            print(f"High activity samples: {len(high_activity)}")
            print(f"Estimated SIMD utilization: {simd_estimate:.1f}%")
            
            # Additional analysis for specific SIMD indicators
            very_high_activity = [e for e in active_events if e > avg_active * 1.5]
            if very_high_activity:
                print(f"\nVery high activity samples (>1.5x avg): {len(very_high_activity)}")
                print(f"These likely represent SIMD-heavy operations: {len(very_high_activity)/len(active_events)*100:.1f}%")

if __name__ == "__main__":
    directory = sys.argv[1] if len(sys.argv) > 1 else "."
    parse_instruments_data(directory)