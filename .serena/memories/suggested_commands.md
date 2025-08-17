# Suggested Commands for EdgeHAR Development

## System Commands (Darwin/macOS)
- `ls -la` - List files with details
- `cd` - Change directory
- `pwd` - Print working directory
- `find . -name "*.py"` - Find files by pattern
- `grep -r "pattern" .` - Search in files
- `open .` - Open folder in Finder

## Git Commands
- `git status` - Check repository status
- `git add .` - Stage all changes
- `git commit -m "message"` - Commit changes
- `git push` - Push to remote
- `git log --oneline` - View commit history

## Python Development
```bash
# Setup environment
pip install tensorflow scikit-learn pandas numpy matplotlib

# Data preparation
cd scripts
python download_uci_har.py       # Download UCI HAR dataset
python generate_test_data.py     # Generate synthetic data

# Model training
python train_2class_model.py     # Train lightweight model
python train_8class_model.py     # Train detailed model
python quantize_models.py        # Quantize for TFLite Micro

# Analysis
python analyze_power.py          # Analyze power logs
python evaluate_models.py        # Generate accuracy reports
python generate_figures.py       # Create paper figures
```

## M5Stack Development
```bash
# Arduino CLI (if installed)
arduino-cli compile --fqbn esp32:esp32:m5stack-core2
arduino-cli upload --port /dev/cu.usbserial-*

# PlatformIO (alternative)
pio run -t upload
pio device monitor
```

## iOS Development
```bash
# Xcode command line
xcodebuild -scheme EdgeHAR build
xcodebuild test

# SwiftLint (if installed)
swiftlint
```

## Testing & Validation
```bash
# Python tests (when implemented)
python -m pytest tests/
python -m unittest discover

# Code quality (if tools installed)
pylint scripts/*.py
black scripts/*.py --check
```

## Project Management
```bash
# Check project structure
tree -I '__pycache__|*.pyc|venv'

# Monitor file sizes
du -sh models/*.tflite

# View logs
tail -f results/power_logs/*.log
```

## Note
Not all commands may have associated tools installed. The project currently focuses on implementation rather than extensive testing/linting infrastructure.