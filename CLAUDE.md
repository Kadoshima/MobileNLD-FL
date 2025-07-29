# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MobileNLD-FL is a research project for **mobile nonlinear dynamics analysis with federated learning** for fatigue anomaly detection. The project implements real-time computation of nonlinear dynamics indicators (Lyapunov exponent, DFA) and heart rate variability on smartphones, combined with personalized federated autoencoders for privacy-preserving anomaly detection.

## Key Components

### 1. Data Processing Pipeline
- **Raw data**: MHEALTH dataset (10 subjects, 23 sensor channels, 50Hz sampling)
- **Preprocessing**: `scripts/01_preprocess.py` extracts features from 3-second windows
- **Feature types**: Statistical features, nonlinear dynamics (LyE, DFA), HRV (RMSSD, LF/HF ratio)

### 2. iOS Implementation
- **Location**: `MobileNLD-FL/MobileNLD-FL/` (Swift project, iOS 17+, iPhone 13 target)
- **Status**: Xcode project created - ready for core implementation
- **Next phase**: Fixed-point arithmetic (Q15) implementation for real-time computation
- **Performance target**: 3-second windows processed in 4ms
- **Build**: Open Xcode project in the nested MobileNLD-FL directory

### 3. Machine Learning
- **Framework**: Flower (federated learning) with TensorFlow
- **Architecture**: Personalized federated autoencoders (PFL-AE)
- **Status**: Implementation pending - referenced in planning documents
- **Key insight**: Shared encoder + local decoder for non-IID data handling

## Common Commands

### Environment Setup
```bash
pip install -r requirements.txt
```

### Data Preparation
```bash
# Download MHEALTH dataset
bash scripts/00_download.sh

# Preprocess data into features and RR intervals
python scripts/01_preprocess.py
```

### Federated Learning Training
```bash
# Note: ML implementation is planned but not yet implemented
# Planned commands based on project documentation:
# python ml/train_federated.py --algo fedavg
# python ml/train_federated.py --algo pflae
```

### iOS Development
- Navigate to `MobileNLD-FL/MobileNLD-FL/` directory and open the Xcode project
- Current status: Xcode project setup complete (Swift 5.0, iOS 17+ deployment target)
- Next: Implement fixed-point arithmetic (Q15) and NLD algorithms
- Ensure physical iPhone 13 is connected for performance testing
- Use Instruments "Energy Log" for power consumption measurement

## Architecture Notes

### Fixed-Point Implementation
- Uses Q15 format (Int16) for all computations
- Lookup tables replace expensive operations like logarithms
- Target: 22x speedup over Python floating-point

### Federated Learning Structure
- **Input dimensions**: 10 features (NLD:2 + HRV:2 + statistical:6)
- **Network**: Encoder [32,16], Decoder [16,32]
- **Training**: 20 rounds, 1 epoch per round, lr=1e-3
- **Evaluation**: Session-based split simulates non-IID federated scenarios

### Research Contributions
1. **N1**: Real-time LyE/DFA computation on smartphones (4ms for 3s windows)
2. **N2**: Combined NLD+HRV features improve fatigue detection (AUC +0.09)
3. **N3**: Personalized federated autoencoders for gait analysis
4. **N4**: Single-subject federated evaluation via session splitting

## File Organization

```
MobileNLD-FL/
├── data/
│   ├── raw/MHEALTHDATASET/     # Original sensor logs
│   └── processed/              # Feature CSVs and RR intervals
├── ios/MobileNLD/              # Swift implementation
├── ml/                         # Federated learning code
├── scripts/                    # Data pipeline utilities
├── docs/                       # Japanese documentation and plans
├── figs/                       # Generated plots for papers
└── paper/                      # LaTeX manuscript
```

## Development Status & Notes

- **Current status**: Research planning phase with data preprocessing complete
- **Primary language**: Python for ML, Swift for iOS implementation
- **Active components**: Data preprocessing scripts functional
- **In development**: iOS implementation (basic template exists), ML federated learning code
- **Performance testing**: Use iPhone 13 with Instruments for accurate measurements
- **Data privacy**: All processing designed for edge deployment
- **Paper target**: IEICE Transactions on Information and Systems
- **Evaluation dataset**: MHEALTH (UCI Repository) - publicly available

## Implementation Timeline

Based on the project planning documents (`docs/実装TODO.md`):
1. **Day 1-3**: Data pipeline and iOS core implementation
2. **Day 4**: Flower federated learning implementation  
3. **Day 5-7**: Evaluation, figures, and paper writing