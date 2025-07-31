#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import sys

# Simple analysis without numpy
def mean(data):
    return sum(data) / len(data) if data else 0

def std_dev(data):
    if not data or len(data) < 2:
        return 0
    m = mean(data)
    variance = sum((x - m) ** 2 for x in data) / (len(data) - 1)
    return variance ** 0.5

if len(sys.argv) < 2:
    print("Usage: python3 analyze_simple.py <xml_file>")
    sys.exit(1)

xml_file = sys.argv[1]
all_index = 0  # Default ALL counter index
simd_indices = [1, 2, 3]  # Default SIMD counter indices

values_list = []

try:
    tree = ET.parse(xml_file)
    root = tree.getroot()

    # Find counters-profile schema
    schema_found = False
    for elem in root.iter():
        if elem.tag == 'schema' and elem.get('name') == 'counters-profile':
            schema_found = True
            # Find parent table
            parent = elem.getparent()
            if parent is not None and parent.tag == 'table':
                rows = parent.findall('row')
                for row in rows:
                    time_elem = row.find('sample-time') or row.find('time')
                    pmc_elem = row.find('pmc-events') or row.find('counters-array')
                    
                    if pmc_elem is not None and pmc_elem.text:
                        values = [int(v) for v in pmc_elem.text.split() if v.strip().isdigit()]
                        if values and len(values) >= max([all_index] + simd_indices) + 1:
                            values_list.append(values)

    if not schema_found:
        print("Error: 'counters-profile' schema not found")
        sys.exit(1)

    if values_list:
        # Calculate sums
        num_counters = len(values_list[0])
        counters_sums = [0] * num_counters
        
        for values in values_list:
            for i in range(num_counters):
                counters_sums[i] += values[i]
        
        print(f"File: {xml_file}")
        print(f"Valid rows: {len(values_list)}")
        print(f"Counter sums: {counters_sums}")
        
        # Calculate SIMD utilization
        if counters_sums[all_index] > 0:
            simd_total = sum(counters_sums[i] for i in simd_indices if i < len(counters_sums))
            utilization = (simd_total / counters_sums[all_index]) * 100
            print(f"SIMD utilization: {utilization:.2f}%")
            print(f"  ALL counter (index {all_index}): {counters_sums[all_index]}")
            print(f"  SIMD counters (indices {simd_indices}): {simd_total}")
        else:
            print("Warning: ALL counter is 0")
    else:
        print("No valid data found")

except Exception as e:
    print(f"Error: {e}")