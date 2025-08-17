# Project Structure

## Root Directory: MobileNLD-FL/

### Core Directories

#### M5Stack/ - Firmware for edge devices
- `sensor_node/` - M5Stack_1: IMU data collection and BLE transmission
- `light_inference/` - M5Stack_2: 2-class lightweight classifier
- `detailed_inference/` - M5Stack_3: 8-class detailed classifier

#### iOS/ - iPhone application
- `EdgeHAR/` - Swift coordinator app (currently empty, to be implemented)

#### scripts/ - Python utilities
- `download_uci_har.py` - Downloads and prepares UCI HAR dataset
- `train_2class_model.py` - Trains binary classifier (Active/Idle)
- `train_8class_model.py` - Trains 8-class activity classifier
- Additional analysis and evaluation scripts to be added

#### models/ - Trained ML models
- Stores `.tflite` files for deployment
- `.h5` Keras models
- `.h` C header files for M5Stack
- Normalization parameters

#### data/ - Datasets
- `uci_har/` - UCI Human Activity Recognition dataset
- `custom/` - Custom collected data (future)

#### results/ - Experiment outputs
- `power_logs/` - Power consumption measurements
- `accuracy_results/` - Model evaluation results
- `figures/` - Graphs and visualizations for paper

#### docs/ - Documentation
- `研究概要_EdgeHAR.md` - Research overview (Japanese)
- `実装計画_1ヶ月スプリント.md` - Implementation plan
- `実験進捗トラッカー.md` - Experiment tracker
- `archive_NLD-FL/` - Archived previous research

### Key Files
- `README.md` - Project overview and setup instructions
- `CLAUDE.md` - AI assistant guidance (checked into repo)
- `.gitignore` - Git ignore patterns
- `requirements.txt` - Python dependencies (to be created)

### Hidden Directories
- `.serena/` - Serena MCP server files
- `.claude/` - Claude configuration

## File Naming Conventions
- Python scripts: `snake_case.py`
- Arduino sketches: `snake_case.ino`
- Documentation: Japanese or English with underscores
- Models: `{n}class_model.{ext}`