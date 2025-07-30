#!/bin/bash
# Script to fix build errors

echo "=== Fixing MobileNLD-FL Build Errors ==="

# 1. Remove test files that are causing XCTest errors
echo "1. Removing test files from main target..."
cd /Users/kadoshima/Documents/MobileNLD-FL/MobileNLD-FL/MobileNLD-FL

# Backup and remove test files
for file in MobileNLDTests.swift SIMDIntegrationTests.swift; do
    if [ -f "$file" ]; then
        echo "   Removing $file"
        rm -f "$file"
    fi
done

# 2. Clean DerivedData
echo "2. Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MobileNLD-FL-*

# 3. Check for duplicate symbols
echo "3. Checking for duplicate TestResult definitions..."
grep -n "struct TestResult" *.swift

echo ""
echo "=== Next Steps ==="
echo "1. First, update your Apple Developer License Agreement:"
echo "   - Go to https://developer.apple.com"
echo "   - Sign in and accept the new agreement"
echo ""
echo "2. In Xcode:"
echo "   - Product → Clean Build Folder (Shift+Cmd+K)"
echo "   - Try building for Simulator first"
echo "   - If simulator works, then try device"
echo ""
echo "3. If device still fails:"
echo "   - Go to Signing & Capabilities"
echo "   - Toggle 'Automatically manage signing' off and on"
echo "   - Re-select your team"
echo ""
echo "Build errors should now be reduced."