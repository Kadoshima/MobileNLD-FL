#!/bin/bash
# Script to run performance tests on connected iPhone

echo "=== MobileNLD-FL Device Testing ==="
echo "Date: $(date)"
echo ""

# Check connected devices
echo "Checking connected devices..."
xcrun devicectl list devices | grep -E "(iPhone|iPad).*connected"

echo ""
echo "=== Instructions for Device Testing ==="
echo ""
echo "Since automatic provisioning is not set up, please follow these steps:"
echo ""
echo "1. Open Xcode (already opened)"
echo "2. Select your iPhone from the device menu (top toolbar)"
echo "3. If prompted, select your development team:"
echo "   - Click on the project name in navigator"
echo "   - Select 'Signing & Capabilities' tab"
echo "   - Choose your Apple ID team"
echo ""
echo "4. Click the Run button (▶) or press Cmd+R"
echo ""
echo "5. Once the app launches on your iPhone:"
echo "   a. Tap 'Run Tests' button"
echo "   b. Wait for completion (should take ~5 seconds)"
echo "   c. View results on screen"
echo ""
echo "6. For detailed performance profiling:"
echo "   a. In Xcode: Product → Profile (Cmd+I)"
echo "   b. Choose 'Time Profiler'"
echo "   c. Run the 5-minute benchmark"
echo "   d. Analyze CPU usage and SIMD instructions"
echo ""
echo "Expected Results:"
echo "- Processing time: < 4ms for 3-second window"
echo "- SIMD utilization: ~95%"
echo "- All tests passed: 12/12"
echo ""

# Alternative: Try to build and install via command line
echo "Attempting command-line build..."
echo "If this fails, please use Xcode as instructed above."
echo ""

cd /Users/kadoshima/Documents/MobileNLD-FL/MobileNLD-FL

# Try to build with automatic signing
xcodebuild -project MobileNLD-FL.xcodeproj \
  -scheme MobileNLD-FL \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  CODE_SIGN_IDENTITY="Apple Development" \
  DEVELOPMENT_TEAM="" \
  build

if [ $? -eq 0 ]; then
    echo "Build successful! Now install on device using Xcode."
else
    echo "Command-line build failed. Please use Xcode to run on device."
fi