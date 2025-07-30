#!/bin/bash
# Build and test script for MobileNLD-FL iOS implementation
# Targets iPhone 13 (iOS 17+) for IEICE paper experiments

set -e

echo "=== MobileNLD-FL iOS Build & Test Script ==="
echo "Date: $(date)"
echo "Target: iPhone 13, iOS 17+"
echo ""

# Navigate to project directory
cd ../MobileNLD-FL/MobileNLD-FL

# Build for testing
echo "Building for testing..."
xcodebuild test \
  -project MobileNLD-FL.xcodeproj \
  -scheme MobileNLD-FL \
  -destination 'platform=iOS,name=iPhone 13' \
  -configuration Release \
  -quiet | grep -E '(Test Suite|passed|failed|executed)'

# Build for device deployment
echo ""
echo "Building for device deployment..."
xcodebuild build \
  -project MobileNLD-FL.xcodeproj \
  -scheme MobileNLD-FL \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -derivedDataPath build

echo ""
echo "Build complete. App bundle location:"
echo "build/Build/Products/Release-iphoneos/MobileNLD-FL.app"

# Instructions for running on device
echo ""
echo "=== Device Testing Instructions ==="
echo "1. Connect iPhone 13 via USB"
echo "2. Open Xcode and run on device, or use:"
echo "   xcrun devicectl device install app --device [device-id] build/Build/Products/Release-iphoneos/MobileNLD-FL.app"
echo "3. Launch app and tap 'Run Tests' button"
echo "4. Results saved to device Documents folder"
echo ""
echo "=== Performance Measurement ==="
echo "1. Open Instruments (Xcode > Open Developer Tool > Instruments)"
echo "2. Choose 'Time Profiler' template"
echo "3. Select your iPhone 13 and MobileNLD-FL app"
echo "4. Record while running tests"
echo "5. Check CPU usage and SIMD instruction counts"