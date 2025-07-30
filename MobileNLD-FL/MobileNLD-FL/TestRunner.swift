//
//  TestRunner.swift
//  MobileNLD-FL
//
//  Test runner for benchmarking without Xcode
//  Can be run from command line or integrated into ContentView
//

import Foundation

class TestRunner {
    
    // MARK: - Properties
    
    private var results: [TestResult] = []
    private let outputPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // MARK: - Run All Tests
    
    func runAllTests(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var output = "=== MobileNLD-FL Test Results ===\n"
            output += "Date: \(Date())\n"
            output += "Device: \(self.getDeviceInfo())\n\n"
            
            // Q15 Tests
            output += self.runQ15Tests()
            
            // Lyapunov Tests
            output += self.runLyapunovTests()
            
            // DFA Tests
            output += self.runDFATests()
            
            // Performance Tests
            output += self.runPerformanceTests()
            
            // SIMD Utilization Tests
            output += self.runSIMDTests()
            
            // Summary
            output += self.generateSummary()
            
            // Save results
            self.saveResults(output)
            
            DispatchQueue.main.async {
                completion(output)
            }
        }
    }
    
    // MARK: - Individual Test Suites
    
    private func runQ15Tests() -> String {
        var output = "=== Q15 Arithmetic Tests ===\n"
        
        // Test conversion accuracy
        let testValues: [Float] = [-1.0, -0.5, 0.0, 0.5, 0.99997]
        var maxError: Float = 0
        
        for value in testValues {
            let q15 = FixedPointMath.floatToQ15(value)
            let recovered = FixedPointMath.q15ToFloat(q15)
            let error = abs(value - recovered)
            maxError = max(maxError, error)
            
            output += String(format: "Value: %.5f -> Q15: %d -> Recovered: %.5f (Error: %.6f)\n",
                           value, q15, recovered, error)
        }
        
        let passed = maxError < 0.0001
        output += "Max Error: \(maxError) - \(passed ? "PASS" : "FAIL")\n\n"
        
        results.append(TestResult(
            testName: "Q15 Conversion",
            passed: passed,
            result: maxError,
            reference: 0.0001,
            rmse: maxError,
            executionTime: 0
        ))
        
        return output
    }
    
    private func runLyapunovTests() -> String {
        var output = "=== Lyapunov Exponent Tests ===\n"
        
        let signal = generateChaoticSignal(length: 150)
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        var times: [Double] = []
        var results: [Float] = []
        
        // Run multiple iterations for statistics
        for i in 0..<10 {
            let start = CFAbsoluteTimeGetCurrent()
            let lye = NonlinearDynamics.lyapunovExponent(
                q15Signal,
                embeddingDim: 5,
                delay: 4,
                samplingRate: 50
            )
            let time = (CFAbsoluteTimeGetCurrent() - start) * 1000
            
            times.append(time)
            results.append(lye)
            
            if i == 0 {
                output += String(format: "First result: %.4f (%.2f ms)\n", lye, time)
            }
        }
        
        let avgTime = times.reduce(0, +) / Double(times.count)
        let avgResult = results.reduce(0, +) / Float(results.count)
        
        output += String(format: "Average: %.4f (%.2f ms)\n", avgResult, avgTime)
        output += String(format: "Performance: %.1fx speedup vs baseline\n", 50.0 / avgTime)
        
        let passed = avgTime < 2.0  // Half of 4ms budget
        output += "Status: \(passed ? "PASS" : "FAIL")\n\n"
        
        self.results.append(TestResult(
            testName: "Lyapunov Performance",
            passed: passed,
            result: Float(avgTime),
            reference: 2.0,
            rmse: 0,
            executionTime: avgTime
        ))
        
        return output
    }
    
    private func runDFATests() -> String {
        var output = "=== DFA Tests ===\n"
        
        let signal = generateOneFNoise(length: 150)
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        var times: [Double] = []
        var alphas: [Float] = []
        
        for i in 0..<10 {
            let start = CFAbsoluteTimeGetCurrent()
            let alpha = NonlinearDynamics.dfaAlpha(
                q15Signal,
                minBoxSize: 4,
                maxBoxSize: 64
            )
            let time = (CFAbsoluteTimeGetCurrent() - start) * 1000
            
            times.append(time)
            alphas.append(alpha)
            
            if i == 0 {
                output += String(format: "First result: α=%.4f (%.2f ms)\n", alpha, time)
            }
        }
        
        let avgTime = times.reduce(0, +) / Double(times.count)
        let avgAlpha = alphas.reduce(0, +) / Float(alphas.count)
        
        output += String(format: "Average: α=%.4f (%.2f ms)\n", avgAlpha, avgTime)
        output += "Expected α ≈ 1.0 for 1/f noise\n"
        
        let passed = avgTime < 2.0 && abs(avgAlpha - 1.0) < 0.2
        output += "Status: \(passed ? "PASS" : "FAIL")\n\n"
        
        self.results.append(TestResult(
            testName: "DFA Performance",
            passed: passed,
            result: Float(avgTime),
            reference: 2.0,
            rmse: abs(avgAlpha - 1.0),
            executionTime: avgTime
        ))
        
        return output
    }
    
    private func runPerformanceTests() -> String {
        var output = "=== Combined Window Performance ===\n"
        
        let signal = generateMixedSignal(length: 150)
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        var windowTimes: [Double] = []
        
        // Warm up
        for _ in 0..<5 {
            _ = processWindow(q15Signal)
        }
        
        // Measure
        for _ in 0..<100 {
            let start = CFAbsoluteTimeGetCurrent()
            _ = processWindow(q15Signal)
            let time = (CFAbsoluteTimeGetCurrent() - start) * 1000
            windowTimes.append(time)
        }
        
        let avgTime = windowTimes.reduce(0, +) / Double(windowTimes.count)
        let minTime = windowTimes.min() ?? 0
        let maxTime = windowTimes.max() ?? 0
        
        output += String(format: "Average: %.2f ms\n", avgTime)
        output += String(format: "Min: %.2f ms, Max: %.2f ms\n", minTime, maxTime)
        output += String(format: "Target: < 4.0 ms\n")
        
        let passed = avgTime < 4.0
        output += "Status: \(passed ? "PASS" : "FAIL")\n\n"
        
        self.results.append(TestResult(
            testName: "Window Processing",
            passed: passed,
            result: Float(avgTime),
            reference: 4.0,
            rmse: 0,
            executionTime: avgTime
        ))
        
        return output
    }
    
    private func runSIMDTests() -> String {
        var output = "=== SIMD Utilization Tests ===\n"
        
        // Test distance calculation
        let a = [Q15](repeating: 100, count: 16)
        let b = [Q15](repeating: 200, count: 16)
        
        let utilization = SIMDOptimizations.measureSIMDUtilization(
            operationName: "Distance Calculation",
            iterations: 10000
        ) {
            a.withUnsafeBufferPointer { aPtr in
                b.withUnsafeBufferPointer { bPtr in
                    _ = SIMDOptimizations.euclideanDistanceSIMD(
                        aPtr.baseAddress!,
                        bPtr.baseAddress!,
                        dimension: 16
                    )
                }
            }
        }
        
        output += String(format: "Distance Calculation: %.1f%% SIMD utilization\n", utilization)
        
        // Test cumulative sum
        let signal = [Q15](repeating: 100, count: 150)
        let cumulativeUtilization = SIMDOptimizations.measureSIMDUtilization(
            operationName: "Cumulative Sum",
            iterations: 1000
        ) {
            _ = SIMDOptimizations.cumulativeSumSIMD(signal, mean: 0)
        }
        
        output += String(format: "Cumulative Sum: %.1f%% SIMD utilization\n", cumulativeUtilization)
        
        let avgUtilization = (utilization + cumulativeUtilization) / 2
        output += String(format: "Average SIMD Utilization: %.1f%%\n", avgUtilization)
        
        let passed = avgUtilization > 90.0  // Target 95%
        output += "Target: > 90% - \(passed ? "PASS" : "FAIL")\n\n"
        
        self.results.append(TestResult(
            testName: "SIMD Utilization",
            passed: passed,
            result: Float(avgUtilization),
            reference: 90.0,
            rmse: 0,
            executionTime: 0
        ))
        
        return output
    }
    
    // MARK: - Helper Functions
    
    private func processWindow(_ signal: [Q15]) -> (lye: Float, alpha: Float) {
        let lye = NonlinearDynamics.lyapunovExponent(
            signal,
            embeddingDim: 5,
            delay: 4,
            samplingRate: 50
        )
        let alpha = NonlinearDynamics.dfaAlpha(
            signal,
            minBoxSize: 4,
            maxBoxSize: 64
        )
        return (lye, alpha)
    }
    
    private func generateSummary() -> String {
        var output = "=== Test Summary ===\n"
        
        let passed = results.filter { $0.passed }.count
        let total = results.count
        
        output += "Passed: \(passed)/\(total)\n"
        
        for result in results {
            let status = result.passed ? "✓" : "✗"
            output += String(format: "%@ %@: %.2f ms\n",
                           status, result.testName, result.executionTime)
        }
        
        if passed == total {
            output += "\n🎉 All tests PASSED! Ready for IEICE submission.\n"
        } else {
            output += "\n⚠️  Some tests failed. Optimization needed.\n"
        }
        
        return output
    }
    
    private func saveResults(_ output: String) {
        let fileName = "test_results_\(Date().timeIntervalSince1970).txt"
        let fileURL = outputPath.appendingPathComponent(fileName)
        
        do {
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Results saved to: \(fileURL.path)")
        } catch {
            print("Failed to save results: \(error)")
        }
    }
    
    private func getDeviceInfo() -> String {
        #if targetEnvironment(simulator)
        return "iOS Simulator"
        #else
        return UIDevice.current.model + " (" + UIDevice.current.systemVersion + ")"
        #endif
    }
    
    // MARK: - Signal Generation
    
    private func generateChaoticSignal(length: Int) -> [Float] {
        var x: Float = 0.1
        return (0..<length).map { _ in
            x = 3.9 * x * (1 - x)  // Logistic map
            return x * 2 - 1
        }
    }
    
    private func generateOneFNoise(length: Int) -> [Float] {
        var noise = (0..<length).map { _ in Float.random(in: -1...1) }
        for i in 1..<length {
            noise[i] = noise[i-1] * 0.9 + noise[i] * 0.1
        }
        return normalizeSignal(noise)
    }
    
    private func generateMixedSignal(length: Int) -> [Float] {
        return (0..<length).map { i in
            let t = Float(i) / 50.0
            return sin(2 * .pi * 0.5 * t) + 0.3 * sin(2 * .pi * 2.0 * t) + 0.1 * Float.random(in: -1...1)
        }
    }
    
    private func normalizeSignal(_ signal: [Float]) -> [Float] {
        let max = signal.max() ?? 1
        let min = signal.min() ?? -1
        let range = max - min
        return signal.map { ($0 - min) / range * 2 - 1 }
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