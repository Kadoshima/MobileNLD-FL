#!/usr/bin/env python3
import re
import sys

def extract_pmc_events(filename):
    """Extract PMC event values from Instruments XML file"""
    
    pmc_values = []
    total_events = 0
    
    # Pattern to match pmc-events elements
    # Example: <pmc-events id="20" fmt="(579,622)">579622</pmc-events>
    pmc_pattern = re.compile(r'<pmc-events[^>]*>(\d+)</pmc-events>')
    
    print(f"Analyzing file: {filename}")
    print("Extracting PMC event values...")
    
    with open(filename, 'r') as f:
        content = f.read()
        
    matches = pmc_pattern.findall(content)
    
    if matches:
        for value in matches:
            val = int(value)
            pmc_values.append(val)
            total_events += val
        
        # Statistics
        avg = sum(pmc_values) / len(pmc_values) if pmc_values else 0
        max_val = max(pmc_values) if pmc_values else 0
        min_val = min(pmc_values) if pmc_values else 0
        
        print(f"\nResults:")
        print(f"Total PMC events found: {len(pmc_values)}")
        print(f"Sum of all events: {total_events:,}")
        print(f"Average per sample: {avg:,.2f}")
        print(f"Max value: {max_val:,}")
        print(f"Min value: {min_val:,}")
        
        # Look for patterns in the XML to understand counter structure
        print("\nLooking for counter array structure...")
        
        # Pattern for counters-array which might contain multiple values
        array_pattern = re.compile(r'<counters-array[^>]*>([^<]+)</counters-array>')
        array_matches = array_pattern.findall(content)
        
        if array_matches:
            print(f"Found {len(array_matches)} counter arrays")
            # Analyze first few arrays
            for i, array in enumerate(array_matches[:5]):
                values = array.strip().split()
                print(f"Array {i}: {len(values)} values - {array}")
    else:
        print("No PMC events found in the file")
        
        # Try to find counter arrays directly
        print("\nLooking for counter arrays...")
        array_pattern = re.compile(r'Counter Value Array[^>]*>([^<]+)</')
        array_matches = array_pattern.findall(content)
        if array_matches:
            print(f"Found {len(array_matches)} counter arrays")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 extract_pmc.py <xml_file>")
        sys.exit(1)
    
    extract_pmc_events(sys.argv[1])