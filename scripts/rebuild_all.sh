#!/bin/bash
# rebuild_all.sh - Regenerate all analysis results from raw data

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     COMPLETE ANALYSIS REGENERATION${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Check if analysis notebooks exist
NOTEBOOK_DIR="analysis/notebooks"
if [ ! -d "$NOTEBOOK_DIR" ]; then
    echo -e "${RED}Error: Analysis notebooks directory not found: $NOTEBOOK_DIR${NC}"
    exit 1
fi

# Clean previous results (with confirmation)
echo -e "${YELLOW}This will delete and regenerate all results. Continue? (y/N)${NC}"
read -r CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

# Backup existing results
if [ -d "results" ]; then
    BACKUP_DIR="results_backup_$(date +%Y%m%d_%H%M%S)"
    mv results "$BACKUP_DIR"
    echo -e "${GREEN}✓ Backed up existing results to: $BACKUP_DIR${NC}"
fi

if [ -d "figs" ]; then
    BACKUP_DIR="figs_backup_$(date +%Y%m%d_%H%M%S)"
    mv figs "$BACKUP_DIR"
    echo -e "${GREEN}✓ Backed up existing figures to: $BACKUP_DIR${NC}"
fi

# Create fresh directories
mkdir -p results
mkdir -p figs
mkdir -p logs/analysis

echo ""
echo -e "${YELLOW}Step 1: Processing raw data...${NC}"

# Check for Python environment
if [ ! -f "analysis/requirements.txt" ]; then
    echo -e "${RED}Warning: requirements.txt not found${NC}"
else
    echo "Checking Python dependencies..."
    pip install -q -r analysis/requirements.txt
fi

# Run main analysis notebook (if exists)
if [ -f "$NOTEBOOK_DIR/main_analysis.ipynb" ]; then
    echo "Running main_analysis.ipynb..."
    jupyter nbconvert --to notebook --execute \
        --ExecutePreprocessor.timeout=600 \
        --output-dir=logs/analysis \
        "$NOTEBOOK_DIR/main_analysis.ipynb"
    echo -e "${GREEN}✓ Main analysis complete${NC}"
else
    echo -e "${YELLOW}main_analysis.ipynb not found, skipping${NC}"
fi

echo ""
echo -e "${YELLOW}Step 2: Generating summary tables...${NC}"

# Run Python script to generate summary CSVs
python3 << 'EOF'
import pandas as pd
import json
from pathlib import Path
import sys

# Find all runs in catalog
catalog_path = Path("catalog.csv")
if not catalog_path.exists():
    print("No catalog.csv found, creating empty summaries")
    pd.DataFrame().to_csv("results/summary_by_run.csv")
    pd.DataFrame().to_csv("results/summary_by_condition.csv")
    sys.exit(0)

catalog = pd.read_csv(catalog_path)

# Collect all run summaries
run_summaries = []

for _, row in catalog.iterrows():
    run_id = row['run_id']
    data_path = Path(row['path'])
    
    # Load meta
    meta_path = data_path / f"meta_{run_id}.json"
    if meta_path.exists():
        with open(meta_path) as f:
            meta = json.load(f)
        
        # Check if QC passed
        if meta.get('quality', {}).get('qc_status') != 'passed':
            continue
        
        # Extract key metrics (placeholder - customize based on actual analysis)
        summary = {
            'run_id': run_id,
            'subject': meta['subject_id'],
            'condition': meta['condition'],
            'distance_m': meta.get('distance_m', 'NA'),
            'qc_status': meta['quality']['qc_status']
        }
        
        # Add QC results if available
        qc_results = meta.get('quality', {}).get('qc_results', {})
        if 'ppk2' in qc_results and isinstance(qc_results['ppk2'], dict):
            summary['avg_current_mA'] = qc_results['ppk2'].get('avg_current_mA', 'NA')
            summary['avg_power_mW'] = qc_results['ppk2'].get('avg_power_mW', 'NA')
        
        if 'phone' in qc_results and isinstance(qc_results['phone'], dict):
            summary['p95_latency_ms'] = qc_results['phone'].get('p95_interval_ms', 'NA')
            summary['packet_loss_pct'] = qc_results['phone'].get('est_loss_rate_pct', 'NA')
        
        run_summaries.append(summary)

# Create summary dataframes
if run_summaries:
    df_runs = pd.DataFrame(run_summaries)
    df_runs.to_csv("results/summary_by_run.csv", index=False)
    print(f"✓ Generated summary_by_run.csv ({len(df_runs)} runs)")
    
    # Group by condition
    df_conditions = df_runs.groupby('condition').agg({
        'avg_current_mA': ['mean', 'std'],
        'avg_power_mW': ['mean', 'std'],
        'p95_latency_ms': ['mean', 'std'],
        'packet_loss_pct': ['mean', 'std']
    }).round(2)
    
    df_conditions.to_csv("results/summary_by_condition.csv")
    print(f"✓ Generated summary_by_condition.csv ({len(df_conditions)} conditions)")
else:
    print("No valid runs found in catalog")
EOF

echo ""
echo -e "${YELLOW}Step 3: Generating figures...${NC}"

# Generate standard figures
if [ -f "$NOTEBOOK_DIR/generate_figures.ipynb" ]; then
    echo "Running generate_figures.ipynb..."
    jupyter nbconvert --to notebook --execute \
        --ExecutePreprocessor.timeout=600 \
        --output-dir=logs/analysis \
        "$NOTEBOOK_DIR/generate_figures.ipynb"
    echo -e "${GREEN}✓ Figures generated${NC}"
else
    echo -e "${YELLOW}generate_figures.ipynb not found, skipping${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Running statistical tests...${NC}"

# Run statistical analysis
if [ -f "$NOTEBOOK_DIR/statistical_tests.ipynb" ]; then
    echo "Running statistical_tests.ipynb..."
    jupyter nbconvert --to notebook --execute \
        --ExecutePreprocessor.timeout=600 \
        --output-dir=logs/analysis \
        "$NOTEBOOK_DIR/statistical_tests.ipynb"
    echo -e "${GREEN}✓ Statistical tests complete${NC}"
else
    echo -e "${YELLOW}statistical_tests.ipynb not found, skipping${NC}"
fi

echo ""
echo -e "${YELLOW}Step 5: Checking acceptance criteria...${NC}"

# Check if we meet acceptance criteria
python3 << 'EOF'
import pandas as pd
from pathlib import Path

# Load summary by condition
summary_path = Path("results/summary_by_condition.csv")
if not summary_path.exists():
    print("No condition summary available")
else:
    df = pd.read_csv(summary_path, index_col=0)
    
    # Check criteria (placeholder - customize based on actual metrics)
    print("\nAcceptance Criteria Check:")
    print("-" * 40)
    
    # Example checks (update based on actual column names)
    print("[ ] Power reduction ≥ 40%")
    print("[ ] p95 latency ≤ 300ms")
    print("[ ] F1 degradation ≤ 1.5 points")
    print("[ ] Packet loss ≤ 5%")
EOF

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     REGENERATION COMPLETE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

# List generated files
echo ""
echo -e "${GREEN}Generated files:${NC}"
if [ -d "results" ]; then
    echo "Results:"
    ls -lh results/ | tail -n +2
fi

if [ -d "figs" ]; then
    echo ""
    echo "Figures:"
    ls -lh figs/ | tail -n +2
fi

echo ""
echo -e "${GREEN}✅ All analysis artifacts regenerated successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Review results/summary_by_condition.csv"
echo "2. Check figures in figs/"
echo "3. Verify acceptance criteria are met"
echo "4. Create paper-ready figures if needed"