//
//  ComprehensiveNLDTests.swift
//  MobileNLD-FL
//
//  Tests for Comprehensive Dynamic Adjustment System
//

import Foundation

struct ComprehensiveNLDTests {
    
    // MARK: - Test Data Generation
    
    private static func generateTestSignal(length: Int) -> [Q15] {
        // Generate chaotic signal similar to Lorenz system
        var signal: [Q15] = []
        var x: Double = 0.1
        var y: Double = 0.1
        var z: Double = 0.1
        
        let dt = 0.01
        let sigma = 10.0
        let rho = 28.0
        let beta = 8.0 / 3.0
        
        for _ in 0..<length {
            let dx = sigma * (y - x) * dt
            let dy = (x * (rho - z) - y) * dt
            let dz = (x * y - beta * z) * dt
            
            x += dx
            y += dy
            z += dz
            
            // Normalize and convert to Q15
            let normalized = max(-1, min(1, x / 50.0))
            signal.append(Q15(normalized * 32767))
        }
        
        return signal
    }
    
    /// Run all comprehensive tests
    static func runAllTests() -> [TestResult] {
        var results: [TestResult] = []
        
        print("\n🧪 Running Comprehensive Dynamic Adjustment Tests...\n")
        
        // Test 1: Dynamic Range Monitoring
        results.append(testDynamicRangeMonitoring())
        
        // Test 2: Adaptive Scaling
        results.append(testAdaptiveScaling())
        
        // Test 3: Cross-stage Coordination
        results.append(testCrossStageCoordination())
        
        // Test 4: Comprehensive Lyapunov
        results.append(testComprehensiveLyapunov())
        
        // Test 5: Performance vs Original
        results.append(testPerformanceComparison())
        
        // Test 6: 4ms Constraint
        results.append(test4msConstraint())
        
        // Print summary
        printTestSummary(results)
        
        return results
    }
    
    // MARK: - Individual Tests
    
    private static func testDynamicRangeMonitoring() -> TestResult {
        print("📊 Testing Dynamic Range Monitoring...")
        
        let monitor = DynamicRangeMonitor(windowSize: 128)
        
        // Generate test signal with varying amplitude
        var testSignal: [Q15] = []
        for i in 0..<1000 {
            let amplitude = sin(Float(i) * 0.01) * (0.5 + 0.4 * sin(Float(i) * 0.001))
            testSignal.append(FixedPointMath.floatToQ15(amplitude))
        }
        
        // Monitor signal
        var overflowDetected = false
        var underflowDetected = false
        
        for sample in testSignal {
            let status = monitor.monitorSample(sample)
            
            switch status {
            case .overflowRisk:
                overflowDetected = true
            case .underflowRisk:
                underflowDetected = true
            default:
                break
            }
        }
        
        // Get final statistics
        let stats = monitor.getStatistics()
        
        // Test prediction
        let prediction = monitor.predictRisk(horizon: 50)
        
        let passed = stats.peakValue > 0 && stats.variance > 0 && !overflowDetected
        
        print("  Peak value: \(stats.peakValue)")
        print("  Dynamic range: \(stats.dynamicRange)")
        print("  Risk prediction: \(prediction.probability)")
        print("  Result: \(passed ? "✅ PASSED" : "❌ FAILED")\n")
        
        return TestResult(
            testName: "Dynamic Range Monitoring",
            passed: passed,
            result: Float(prediction.probability),
            reference: 0.5,  // Expected threshold
            rmse: Float(prediction.probability),
            executionTime: 0
        )
    }
    
    private static func testAdaptiveScaling() -> TestResult {
        print("🔧 Testing Adaptive Scaling Engine...")
        
        let engine = AdaptiveScalingEngine()
        
        // Test signal with overflow risk
        let riskySignal = (0..<100).map { _ in
            FixedPointMath.floatToQ15(Float.random(in: 0.8...0.95))
        }
        
        // Apply scaling
        let (scaled, scaleInfo) = engine.scaleSignal(riskySignal, stage: "test")
        
        // Verify scaling reduced risk
        let maxScaled = scaled.map { abs($0) }.max() ?? 0
        let scaledRatio = Float(maxScaled) / Float(FixedPointMath.Q15_MAX)
        
        // Reverse scaling
        let reversed = engine.reverseScale(scaled, scaleInfo: scaleInfo)
        
        // Calculate error
        var error: Float = 0
        for i in 0..<riskySignal.count {
            let diff = Float(riskySignal[i] - reversed[i]) / Float(FixedPointMath.Q15_SCALE)
            error += diff * diff
        }
        let rmse = sqrt(error / Float(riskySignal.count))
        
        let passed = scaledRatio < 0.8 && rmse < 0.01
        
        print("  Applied scale: \(scaleInfo.scaleFactor)")
        print("  Scaled max ratio: \(scaledRatio)")
        print("  Reverse RMSE: \(rmse)")
        print("  Result: \(passed ? "✅ PASSED" : "❌ FAILED")\n")
        
        return TestResult(
            testName: "Adaptive Scaling",
            passed: passed,
            result: scaledRatio,
            reference: 0.5,
            rmse: rmse,
            executionTime: 0
        )
    }
    
    private static func testCrossStageCoordination() -> TestResult {
        print("🔗 Testing Cross-stage Coordination...")
        
        let coordinator = CrossStageCoordinator()
        
        // Generate test signal
        let testSignal = generateTestSignal(length: 500)
        
        // Define processing stages
        let stages: [ProcessingStage] = [
            .phaseSpaceReconstruction,
            .distanceCalculation,
            .indexCalculation
        ]
        
        // Process through pipeline
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = coordinator.processSignal(testSignal, through: stages)
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Check coordination effectiveness
        let cumulativeScale = result.cumulativeScale
        let stageQualities = result.stageResults.values.map { $0.qualityMetric }
        let averageQuality = stageQualities.reduce(0, +) / Float(stageQualities.count)
        
        let passed = cumulativeScale > 0.01 && cumulativeScale < 100 && averageQuality > 0.8
        
        print("  Cumulative scale: \(cumulativeScale)")
        print("  Average quality: \(averageQuality)")
        print("  Processing time: \(String(format: "%.2f", processingTime))ms")
        print("  Result: \(passed ? "✅ PASSED" : "❌ FAILED")\n")
        
        return TestResult(
            testName: "Cross-stage Coordination",
            passed: passed,
            result: averageQuality,
            reference: 0.8,
            rmse: 1.0 - averageQuality,
            executionTime: processingTime
        )
    }
    
    private static func testComprehensiveLyapunov() -> TestResult {
        print("📈 Testing Comprehensive Lyapunov Calculation...")
        
        let comprehensiveNLD = ComprehensiveNonlinearDynamics()
        
        // Generate Lorenz attractor
        let lorenzSignal = generateTestSignal(length: 1000)
        
        // Calculate with comprehensive system
        let startTime = CFAbsoluteTimeGetCurrent()
        let (lyapunov, metrics) = comprehensiveNLD.lyapunovExponent(lorenzSignal)
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Expected Lyapunov for Lorenz is around 0.9
        let expectedLyapunov: Float = 0.9
        let error = abs(lyapunov - expectedLyapunov)
        
        let passed = error < 0.3 && metrics.qualityScore > 0.7 && processingTime < 100
        
        print("  Calculated Lyapunov: \(lyapunov)")
        print("  Expected: ~\(expectedLyapunov)")
        print("  Error: \(error)")
        print("  Quality score: \(metrics.qualityScore)")
        print("  Processing time: \(String(format: "%.2f", processingTime))ms")
        print("  Cumulative scale: \(metrics.cumulativeScale)")
        print("  Result: \(passed ? "✅ PASSED" : "❌ FAILED")\n")
        
        return TestResult(
            testName: "Comprehensive Lyapunov",
            passed: passed,
            result: lyapunov,
            reference: expectedLyapunov,
            rmse: error,
            executionTime: processingTime
        )
    }
    
    private static func testPerformanceComparison() -> TestResult {
        print("⚡ Testing Performance vs Original Implementation...")
        
        let testSignal = generateTestSignal(length: 150)
        
        // Original implementation
        let originalStartTime = CFAbsoluteTimeGetCurrent()
        let originalLyapunov = NonlinearDynamics.lyapunovExponent(testSignal)
        let originalTime = (CFAbsoluteTimeGetCurrent() - originalStartTime) * 1000
        
        // Comprehensive implementation
        let comprehensiveNLD = ComprehensiveNonlinearDynamics()
        comprehensiveNLD.setQualityMode(.highSpeed)
        
        let comprehensiveStartTime = CFAbsoluteTimeGetCurrent()
        let (comprehensiveLyapunov, _) = comprehensiveNLD.lyapunovExponent(testSignal)
        let comprehensiveTime = (CFAbsoluteTimeGetCurrent() - comprehensiveStartTime) * 1000
        
        // Compare results
        let resultDifference = abs(originalLyapunov - comprehensiveLyapunov)
        let speedup = originalTime / comprehensiveTime
        
        let passed = resultDifference < 0.1 && comprehensiveTime < originalTime * 1.5
        
        print("  Original time: \(String(format: "%.2f", originalTime))ms")
        print("  Comprehensive time: \(String(format: "%.2f", comprehensiveTime))ms")
        print("  Speedup: \(String(format: "%.2fx", speedup))")
        print("  Result difference: \(resultDifference)")
        print("  Result: \(passed ? "✅ PASSED" : "❌ FAILED")\n")
        
        return TestResult(
            testName: "Performance Comparison",
            passed: passed,
            result: comprehensiveLyapunov,
            reference: originalLyapunov,
            rmse: resultDifference,
            executionTime: comprehensiveTime
        )
    }
    
    private static func test4msConstraint() -> TestResult {
        print("⏱️ Testing 4ms Real-time Constraint...")
        
        let comprehensiveNLD = ComprehensiveNonlinearDynamics()
        comprehensiveNLD.setQualityMode(.highSpeed)
        
        // Test with 3-second window at 50Hz (150 samples)
        let windowSize = 150
        var successCount = 0
        let iterations = 10
        var totalTime: Double = 0
        
        for _ in 0..<iterations {
            let testSignal = (0..<windowSize).map { _ in
                FixedPointMath.floatToQ15(Float.random(in: -0.8...0.8))
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = comprehensiveNLD.lyapunovExponent(testSignal)
            let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            
            totalTime += processingTime
            if processingTime <= 4.0 {
                successCount += 1
            }
        }
        
        let averageTime = totalTime / Double(iterations)
        let successRate = Float(successCount) / Float(iterations)
        
        let passed = successRate >= 0.8  // 80% success rate
        
        print("  Average time: \(String(format: "%.2f", averageTime))ms")
        print("  Success rate: \(String(format: "%.0f%%", successRate * 100))")
        print("  Result: \(passed ? "✅ PASSED" : "❌ FAILED")\n")
        
        return TestResult(
            testName: "4ms Constraint",
            passed: passed,
            result: Float(averageTime),
            reference: 4.0,
            rmse: Float(abs(averageTime - 4.0)) / 4.0,
            executionTime: averageTime
        )
    }
    
    // MARK: - Helper Methods
    
    private static func printTestSummary(_ results: [TestResult]) {
        print(String(repeating: "=", count: 50))
        print("📊 Comprehensive Test Summary")
        print(String(repeating: "=", count: 50))
        
        let passed = results.filter { $0.passed }.count
        let total = results.count
        
        for result in results {
            let status = result.passed ? "✅" : "❌"
            print("\(status) \(result.testName)")
        }
        
        print("\nTotal: \(passed)/\(total) tests passed")
        
        if passed == total {
            print("🎉 All comprehensive tests passed!")
        } else {
            print("⚠️ Some tests failed. Review implementation.")
        }
    }
}

// MARK: - String Extension

private extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}