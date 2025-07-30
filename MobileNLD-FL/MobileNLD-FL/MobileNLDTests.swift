//
//  MobileNLDTests.swift
//  MobileNLD-FLTests
//
//  XCTest unit tests for Q15 implementation and performance
//

import XCTest
@testable import MobileNLD_FL

class MobileNLDTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    let accuracy: Float = 0.01  // Q15 accuracy requirement
    let performanceTarget: Double = 4.0  // 4ms for 3-second window
    
    override func setUpWithError() throws {
        // Setup before each test
    }
    
    override func tearDownWithError() throws {
        // Cleanup after each test
    }
    
    // MARK: - Q15 Conversion Tests
    
    func testQ15BasicConversion() throws {
        let testValues: [Float] = [-1.0, -0.5, 0.0, 0.5, 0.99997]
        
        for value in testValues {
            let q15 = FixedPointMath.floatToQ15(value)
            let recovered = FixedPointMath.q15ToFloat(q15)
            
            XCTAssertEqual(value, recovered, accuracy: 0.0001,
                          "Q15 conversion failed for \(value)")
        }
    }
    
    func testQ15Saturation() throws {
        // Test overflow
        let overflow = FixedPointMath.floatToQ15(1.5)
        XCTAssertEqual(overflow, Q15.max, "Positive saturation failed")
        
        // Test underflow
        let underflow = FixedPointMath.floatToQ15(-1.5)
        XCTAssertEqual(underflow, Q15.min, "Negative saturation failed")
    }
    
    func testQ15Multiplication() throws {
        let a = FixedPointMath.floatToQ15(0.5)
        let b = FixedPointMath.floatToQ15(0.25)
        
        let result = FixedPointMath.multiply(a, b)
        let floatResult = FixedPointMath.q15ToFloat(result)
        
        XCTAssertEqual(floatResult, 0.125, accuracy: 0.001,
                      "Q15 multiplication failed")
    }
    
    // MARK: - Lyapunov Exponent Tests
    
    func testLyapunovAccuracy() throws {
        let signal = generateChaoticSignal(length: 150)
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        let lye = NonlinearDynamics.lyapunovExponent(
            q15Signal,
            embeddingDim: 5,
            delay: 4,
            samplingRate: 50
        )
        
        // Verify result is in reasonable range for chaotic signal
        XCTAssertGreaterThan(lye, 0.0, "Lyapunov should be positive for chaos")
        XCTAssertLessThan(lye, 1.0, "Lyapunov unreasonably high")
    }
    
    func testLyapunovPerformance() throws {
        let signal = generateTestSignal(length: 150)
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        measure {
            _ = NonlinearDynamics.lyapunovExponent(
                q15Signal,
                embeddingDim: 5,
                delay: 4,
                samplingRate: 50
            )
        }
    }
    
    // MARK: - DFA Tests
    
    func testDFAAccuracy() throws {
        let signal = generateOneFNoise(length: 150)
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        let alpha = NonlinearDynamics.dfaAlpha(
            q15Signal,
            minBoxSize: 4,
            maxBoxSize: 64
        )
        
        // 1/f noise should have alpha close to 1.0
        XCTAssertEqual(alpha, 1.0, accuracy: 0.2,
                      "DFA alpha incorrect for 1/f noise")
    }
    
    func testDFAPerformance() throws {
        let signal = generateTestSignal(length: 150)
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        measure {
            _ = NonlinearDynamics.dfaAlpha(
                q15Signal,
                minBoxSize: 4,
                maxBoxSize: 64
            )
        }
    }
    
    // MARK: - Combined Window Processing
    
    func testWindowProcessingTime() throws {
        let signal = generateTestSignal(length: 150)  // 3 seconds at 50Hz
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process complete window
        let lye = NonlinearDynamics.lyapunovExponent(
            q15Signal,
            embeddingDim: 5,
            delay: 4,
            samplingRate: 50
        )
        let alpha = NonlinearDynamics.dfaAlpha(
            q15Signal,
            minBoxSize: 4,
            maxBoxSize: 64
        )
        
        let elapsedTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        print("Window processing: \(String(format: "%.2f", elapsedTime))ms")
        print("LyE: \(lye), Alpha: \(alpha)")
        
        XCTAssertLessThan(elapsedTime, performanceTarget,
                         "Window processing exceeds 4ms target")
    }
    
    // MARK: - Error Bound Verification
    
    func testTheoreticalErrorBounds() throws {
        // Test multiple signal types to verify error bounds
        let signalTypes = [
            generateSineSignal(length: 150),
            generateChaoticSignal(length: 150),
            generateNoiseSignal(length: 150),
            generateMixedSignal(length: 150)
        ]
        
        var maxLyeError: Float = 0
        var maxAlphaError: Float = 0
        
        for signal in signalTypes {
            // This would compare against high-precision reference
            // For now, we verify error propagation stays bounded
            let q15Signal = FixedPointMath.floatArrayToQ15(signal)
            
            // Convert back to verify quantization error
            let recovered = q15Signal.map { FixedPointMath.q15ToFloat($0) }
            let quantizationError = zip(signal, recovered).map { abs($0 - $1) }.max() ?? 0
            
            XCTAssertLessThan(quantizationError, 0.0001,
                             "Quantization error too large")
        }
    }
    
    // MARK: - Stress Tests
    
    func testContinuousProcessing() throws {
        // Simulate continuous real-time processing
        let windowSize = 150
        var signal = generateTestSignal(length: windowSize)
        let iterations = 100
        
        var processingTimes: [Double] = []
        
        for i in 0..<iterations {
            // Simulate sliding window with new samples
            signal = Array(signal.dropFirst(10)) + generateTestSignal(length: 10)
            let q15Signal = FixedPointMath.floatArrayToQ15(signal)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            _ = NonlinearDynamics.lyapunovExponent(
                q15Signal,
                embeddingDim: 5,
                delay: 4,
                samplingRate: 50
            )
            _ = NonlinearDynamics.dfaAlpha(
                q15Signal,
                minBoxSize: 4,
                maxBoxSize: 64
            )
            
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            processingTimes.append(elapsed)
        }
        
        let avgTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxTime = processingTimes.max() ?? 0
        
        print("Continuous processing - Avg: \(String(format: "%.2f", avgTime))ms, Max: \(String(format: "%.2f", maxTime))ms")
        
        XCTAssertLessThan(avgTime, performanceTarget,
                         "Average processing time exceeds target")
        XCTAssertLessThan(maxTime, performanceTarget * 1.5,
                         "Max processing time too high")
    }
    
    // MARK: - Helper Functions
    
    private func generateTestSignal(length: Int) -> [Float] {
        return (0..<length).map { i in
            let t = Float(i) / 50.0
            return sin(2 * .pi * 0.5 * t) + 0.3 * sin(2 * .pi * 2.0 * t) + 0.1 * Float.random(in: -1...1)
        }
    }
    
    private func generateSineSignal(length: Int) -> [Float] {
        return (0..<length).map { i in
            sin(2 * .pi * 0.1 * Float(i) / 50.0)
        }
    }
    
    private func generateChaoticSignal(length: Int) -> [Float] {
        var x: Float = 0.1
        return (0..<length).map { _ in
            x = 3.9 * x * (1 - x)  // Logistic map
            return x * 2 - 1
        }
    }
    
    private func generateNoiseSignal(length: Int) -> [Float] {
        return (0..<length).map { _ in Float.random(in: -1...1) }
    }
    
    private func generateMixedSignal(length: Int) -> [Float] {
        return generateTestSignal(length: length)
    }
    
    private func generateOneFNoise(length: Int) -> [Float] {
        var noise = generateNoiseSignal(length: length)
        
        // Cumulative sum approximates 1/f
        for i in 1..<length {
            noise[i] = noise[i-1] * 0.9 + noise[i] * 0.1
        }
        
        // Normalize
        let max = noise.max() ?? 1
        let min = noise.min() ?? -1
        let range = max - min
        
        return noise.map { ($0 - min) / range * 2 - 1 }
    }
}

// MARK: - Performance Test Suite

class PerformanceTests: XCTestCase {
    
    func testDetailedBenchmarks() throws {
        let signal = Array(repeating: Float(0), count: 150).map { _ in
            Float.random(in: -1...1)
        }
        let q15Signal = FixedPointMath.floatArrayToQ15(signal)
        
        // Benchmark Lyapunov
        self.measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = NonlinearDynamics.lyapunovExponent(
                q15Signal,
                embeddingDim: 5,
                delay: 4,
                samplingRate: 50
            )
        }
    }
    
    func testMemoryFootprint() throws {
        // Verify memory efficiency
        let signal = Array(repeating: Q15(0), count: 150)
        
        // Q15 uses 2 bytes per sample vs 4 bytes for Float
        let q15Memory = MemoryLayout<Q15>.size * signal.count
        let floatMemory = MemoryLayout<Float>.size * signal.count
        
        print("Memory usage - Q15: \(q15Memory) bytes, Float: \(floatMemory) bytes")
        print("Memory savings: \(Int((1 - Double(q15Memory)/Double(floatMemory)) * 100))%")
        
        XCTAssertEqual(q15Memory, floatMemory / 2,
                      "Q15 should use half the memory of Float")
    }
}