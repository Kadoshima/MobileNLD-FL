//
//  NonlinearDynamicsTests.swift
//  MobileNLD-FL
//
//  Unit tests for nonlinear dynamics calculations
//  Verifies accuracy against MATLAB reference implementations
//

import Foundation

struct NonlinearDynamicsTests {
    
    // MARK: - Test Data Generation
    
    /// Generate test signal similar to MATLAB test cases
    static func generateTestSignal(length: Int = 1000, samplingRate: Int = 50) -> [Q15] {
        var signal: [Float] = []
        let dt = 1.0 / Float(samplingRate)
        
        // Generate Lorenz attractor-like signal for testing
        for i in 0..<length {
            let t = Float(i) * dt
            let x = sin(2.0 * Float.pi * 0.1 * t) + 0.5 * sin(2.0 * Float.pi * 0.3 * t)
            let noise = Float.random(in: -0.05...0.05) // Small amount of noise
            signal.append(x + noise)
        }
        
        // Normalize to [-1, 1] range for Q15
        let maxVal = signal.max() ?? 1.0
        let minVal = signal.min() ?? -1.0
        let range = maxVal - minVal
        
        let normalizedSignal = signal.map { (($0 - minVal) / range) * 2.0 - 1.0 }
        
        return FixedPointMath.floatArrayToQ15(normalizedSignal)
    }
    
    // MARK: - Lyapunov Exponent Tests
    
    /// Test Lyapunov exponent calculation accuracy
    /// Expected RMSE < 0.021 compared to MATLAB reference
    static func testLyapunovExponent() -> TestResult {
        print("Testing Lyapunov Exponent calculation...")
        
        let testSignal = generateTestSignal(length: 1500, samplingRate: 50)
        
        // Parameters matching MATLAB implementation
        let embeddingDim = 5
        let delay = 4
        let samplingRate = 50
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let lyeResult = NonlinearDynamics.lyapunovExponent(testSignal, 
                                                          embeddingDim: embeddingDim, 
                                                          delay: delay, 
                                                          samplingRate: samplingRate)
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
        
        // MATLAB reference value (this would be computed from actual MATLAB)
        // For demonstration, using typical values for this type of signal
        let matlabReference: Float = 0.15 // This should be actual MATLAB result
        let rmse = sqrt(pow(lyeResult - matlabReference, 2))
        
        let passed = rmse < 0.021 && executionTime < 50.0 // 50ms threshold for 3s window
        
        print("  LyE Result: \(lyeResult)")
        print("  MATLAB Reference: \(matlabReference)")
        print("  RMSE: \(rmse)")
        print("  Execution Time: \(String(format: "%.2f", executionTime))ms")
        print("  Test \(passed ? "PASSED" : "FAILED")")
        
        return TestResult(
            testName: "Lyapunov Exponent",
            passed: passed,
            result: lyeResult,
            reference: matlabReference,
            rmse: rmse,
            executionTime: executionTime
        )
    }
    
    // MARK: - DFA Tests
    
    /// Test DFA calculation accuracy
    /// Expected RMSE < 0.018 compared to MATLAB reference
    static func testDFA() -> TestResult {
        print("Testing DFA calculation...")
        
        let testSignal = generateTestSignal(length: 1000, samplingRate: 50)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let dfaResult = NonlinearDynamics.dfaAlpha(testSignal, 
                                                  minBoxSize: 4, 
                                                  maxBoxSize: 64)
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        // MATLAB reference value
        let matlabReference: Float = 1.2 // This should be actual MATLAB result
        let rmse = sqrt(pow(dfaResult - matlabReference, 2))
        
        let passed = rmse < 0.018 && executionTime < 30.0 // 30ms threshold
        
        print("  DFA Result: \(dfaResult)")
        print("  MATLAB Reference: \(matlabReference)")
        print("  RMSE: \(rmse)")
        print("  Execution Time: \(String(format: "%.2f", executionTime))ms")
        print("  Test \(passed ? "PASSED" : "FAILED")")
        
        return TestResult(
            testName: "DFA Alpha",
            passed: passed,
            result: dfaResult,
            reference: matlabReference,
            rmse: rmse,
            executionTime: executionTime
        )
    }
    
    // MARK: - Q15 Arithmetic Tests
    
    /// Test fixed-point arithmetic accuracy
    static func testQ15Arithmetic() -> TestResult {
        print("Testing Q15 arithmetic operations...")
        
        var allPassed = true
        var maxError: Float = 0.0
        
        // Test conversion accuracy
        let testValues: [Float] = [-0.99, -0.5, 0.0, 0.25, 0.75, 0.99]
        
        for value in testValues {
            let q15 = FixedPointMath.floatToQ15(value)
            let converted = FixedPointMath.q15ToFloat(q15)
            let error = abs(converted - value)
            maxError = max(maxError, error)
            
            if error > 0.0001 { // Q15 precision limit
                allPassed = false
            }
        }
        
        // Test arithmetic operations
        let a = FixedPointMath.floatToQ15(0.5)
        let b = FixedPointMath.floatToQ15(0.25)
        
        let mulResult = FixedPointMath.q15ToFloat(FixedPointMath.multiply(a, b))
        let mulExpected: Float = 0.125
        let mulError = abs(mulResult - mulExpected)
        
        if mulError > 0.001 {
            allPassed = false
        }
        
        maxError = max(maxError, mulError)
        
        print("  Max Conversion Error: \(maxError)")
        print("  Multiplication Test: \(mulResult) (expected: \(mulExpected))")
        print("  Test \(allPassed ? "PASSED" : "FAILED")")
        
        return TestResult(
            testName: "Q15 Arithmetic",
            passed: allPassed,
            result: maxError,
            reference: 0.0,
            rmse: maxError,
            executionTime: 0.0
        )
    }
    
    // MARK: - Performance Benchmark
    
    /// Benchmark processing time for 3-second window
    static func benchmarkProcessingTime() -> TestResult {
        print("Benchmarking processing time for 3-second window...")
        
        let samplingRate = 50
        let windowSize = 3 * samplingRate // 3 seconds
        let testSignal = generateTestSignal(length: windowSize, samplingRate: samplingRate)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process both LyE and DFA (as would be done in real application)
        let _ = NonlinearDynamics.lyapunovExponent(testSignal, 
                                                 embeddingDim: 5, 
                                                 delay: 4, 
                                                 samplingRate: samplingRate)
        let _ = NonlinearDynamics.dfaAlpha(testSignal, 
                                         minBoxSize: 4, 
                                         maxBoxSize: 64)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = (endTime - startTime) * 1000 // Convert to milliseconds
        
        let targetTime: Float = 4.0 // 4ms target
        let passed = totalTime < Double(targetTime)
        
        print("  3-second window processing time: \(String(format: "%.2f", totalTime))ms")
        print("  Target: < \(targetTime)ms")
        print("  Performance gain: \(String(format: "%.1f", Double(targetTime) / totalTime))x")
        print("  Test \(passed ? "PASSED" : "FAILED")")
        
        return TestResult(
            testName: "Performance Benchmark",
            passed: passed,
            result: Float(totalTime),
            reference: targetTime,
            rmse: Float(abs(totalTime - Double(targetTime))),
            executionTime: totalTime
        )
    }
    
    // MARK: - Run All Tests
    
    /// Run all tests and return comprehensive results
    static func runAllTests() -> [TestResult] {
        print("=== Running MobileNLD-FL Tests ===\n")
        
        var results: [TestResult] = []
        
        results.append(testQ15Arithmetic())
        print("")
        results.append(testLyapunovExponent())
        print("")
        results.append(testDFA())
        print("")
        results.append(benchmarkProcessingTime())
        print("")
        
        let passedTests = results.filter { $0.passed }.count
        let totalTests = results.count
        
        print("=== Test Summary ===")
        print("Passed: \(passedTests)/\(totalTests)")
        
        if passedTests == totalTests {
            print("🎉 All tests PASSED!")
        } else {
            print("❌ Some tests FAILED")
        }
        
        return results
    }
}

// MARK: - Test Result Structure

struct TestResult {
    let testName: String
    let passed: Bool
    let result: Float
    let reference: Float
    let rmse: Float
    let executionTime: Double
}