# Task Completion Checklist

## When Completing a Task

### For Python Development
1. **Code Quality**
   - Ensure PEP 8 compliance (no linting tools currently configured)
   - Add appropriate docstrings
   - Use type hints where beneficial
   - Handle exceptions properly

2. **Testing**
   - Run the script to verify it works
   - Test with sample data if applicable
   - Check output formats match expectations

3. **Documentation**
   - Update relevant documentation if needed
   - Add inline comments for complex logic

### For M5Stack Development
1. **Compilation**
   - Verify code compiles without errors
   - Check memory usage fits within constraints
   - Ensure all libraries are properly included

2. **Hardware Testing**
   - Test BLE communication
   - Verify sensor data collection
   - Check power consumption if relevant

### For iOS Development
1. **Build & Test**
   - Ensure Xcode project builds successfully
   - Test on simulator and/or device
   - Verify BLE connectivity with M5Stack devices

### For ML Model Training
1. **Validation**
   - Check model accuracy meets targets
   - Verify model size (<50KB for TFLite)
   - Test quantized model performance
   - Save all artifacts (models, parameters, logs)

2. **Export**
   - Generate TFLite model
   - Create C header file for M5Stack
   - Document model specifications

### General Checklist
- [ ] Code runs without errors
- [ ] Functionality meets requirements
- [ ] Files saved in correct locations
- [ ] Git changes ready for commit
- [ ] Documentation updated if needed
- [ ] Results logged appropriately

## Important Notes
- Currently no automated testing framework
- No configured linting/formatting tools
- Manual verification required for most tasks
- Focus on functionality over extensive testing infrastructure

## Future Improvements
- Setup pytest for Python testing
- Configure pylint or black for code formatting
- Add Arduino unit tests
- Implement CI/CD pipeline