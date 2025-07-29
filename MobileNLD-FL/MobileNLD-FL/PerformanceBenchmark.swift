//
//  PerformanceBenchmark.swift
//  MobileNLD-FL
//
//  Performance measurement and continuous benchmarking for Day 3 testing
//  Includes Instruments Points of Interest and energy profiling support
//

import Foundation
import os.signpost

class PerformanceBenchmark: ObservableObject {
    
    // MARK: - Signpost Logging for Instruments
    
    private let performanceLog = OSLog(subsystem: "com.mobilenld.app", category: "Performance")
    
    // Signpost IDs for different measurement categories
    private let lyeSignpostID = OSSignpostID(log: OSLog(subsystem: "com.mobilenld.app", category: "LyapunovExponent"))
    private let dfaSignpostID = OSSignpostID(log: OSLog(subsystem: "com.mobilenld.app", category: "DFA"))
    private let windowSignpostID = OSSignpostID(log: OSLog(subsystem: "com.mobilenld.app", category: "WindowProcessing"))
    
    // MARK: - Performance Data Storage
    
    @Published var isRunning = false
    @Published var currentIteration = 0
    @Published var totalIterations = 0
    @Published var averageProcessingTime: Double = 0.0
    @Published var energyImpact: String = "Measuring..."
    
    private var processingTimes: [Double] = []
    private var benchmarkResults: [BenchmarkResult] = []
    
    // MARK: - Benchmark Configuration
    
    struct BenchmarkConfig {
        let windowSize: Int          // 3 seconds = 150 samples at 50Hz
        let samplingRate: Int        // 50Hz
        let benchmarkDuration: Int   // 300 seconds (5 minutes)
        let measurementInterval: Double // 1.0 second between measurements
        
        static let standard = BenchmarkConfig(
            windowSize: 150,         // 3 seconds * 50Hz
            samplingRate: 50,
            benchmarkDuration: 300,  // 5 minutes
            measurementInterval: 1.0
        )
    }
    
    // MARK: - Benchmark Execution
    
    /// Start 5-minute continuous benchmark for Instruments profiling
    func startContinuousBenchmark(config: BenchmarkConfig = .standard) {
        guard !isRunning else { return }
        
        isRunning = true
        currentIteration = 0
        totalIterations = Int(Double(config.benchmarkDuration) / config.measurementInterval)
        processingTimes.removeAll()
        benchmarkResults.removeAll()
        
        print("🚀 Starting 5-minute continuous benchmark...")
        print("   Window size: \(config.windowSize) samples (\(config.windowSize/config.samplingRate)s)")
        print("   Total iterations: \(totalIterations)")
        print("   Target: < 4ms per window")
        
        // Log benchmark start for Instruments
        os_signpost(.begin, log: performanceLog, name: "ContinuousBenchmark",
                   "Starting 5-minute benchmark with %d iterations", totalIterations)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.executeBenchmark(config: config)
        }
    }
    
    private func executeBenchmark(config: BenchmarkConfig) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for iteration in 0..<totalIterations {
            let iterationStart = CFAbsoluteTimeGetCurrent()
            
            // Generate test signal for this iteration
            let testSignal = generateRealtimeTestSignal(
                length: config.windowSize,
                samplingRate: config.samplingRate,
                iteration: iteration
            )
            
            // Measure window processing time with signposts
            let windowTime = measureWindowProcessing(testSignal, samplingRate: config.samplingRate)
            
            processingTimes.append(windowTime)
            
            // Create benchmark result
            let result = BenchmarkResult(
                iteration: iteration,
                timestamp: iterationStart,
                processingTime: windowTime,
                targetMet: windowTime < 0.004, // 4ms target
                cpuUsage: getCurrentCPUUsage(),
                memoryUsage: getCurrentMemoryUsage()
            )
            
            benchmarkResults.append(result)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.currentIteration = iteration + 1
                self.averageProcessingTime = self.processingTimes.reduce(0, +) / Double(self.processingTimes.count)
            }
            
            // Sleep until next measurement interval
            let iterationDuration = CFAbsoluteTimeGetCurrent() - iterationStart
            let sleepTime = config.measurementInterval - iterationDuration
            if sleepTime > 0 {
                usleep(UInt32(sleepTime * 1_000_000)) // Convert to microseconds
            }
            
            // Check if we should stop
            if !isRunning { break }
        }
        
        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Log benchmark completion
        os_signpost(.end, log: performanceLog, name: "ContinuousBenchmark",
                   "Completed in %.2f seconds", totalDuration)
        
        DispatchQueue.main.async {
            self.finalizeBenchmark(duration: totalDuration)
        }
    }
    
    // MARK: - Window Processing Measurement
    
    private func measureWindowProcessing(_ signal: [Q15], samplingRate: Int) -> Double {
        // Begin window processing measurement
        os_signpost(.begin, log: performanceLog, name: "WindowProcessing",
                   "Processing %d samples", signal.count)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Measure Lyapunov Exponent calculation
        let lyeStart = CFAbsoluteTimeGetCurrent()
        os_signpost(.begin, log: OSLog(subsystem: "com.mobilenld.app", category: "LyapunovExponent"),
                   name: "LyapunovCalculation", signpostID: lyeSignpostID)
        
        let lyeResult = NonlinearDynamics.lyapunovExponent(
            signal,
            embeddingDim: 5,
            delay: 4,
            samplingRate: samplingRate
        )
        
        let lyeTime = CFAbsoluteTimeGetCurrent() - lyeStart
        os_signpost(.end, log: OSLog(subsystem: "com.mobilenld.app", category: "LyapunovExponent"),
                   name: "LyapunovCalculation", signpostID: lyeSignpostID,
                   "Completed in %.4f ms, result: %.6f", lyeTime * 1000, lyeResult)
        
        // Measure DFA calculation
        let dfaStart = CFAbsoluteTimeGetCurrent()
        os_signpost(.begin, log: OSLog(subsystem: "com.mobilenld.app", category: "DFA"),
                   name: "DFACalculation", signpostID: dfaSignpostID)
        
        let dfaResult = NonlinearDynamics.dfaAlpha(
            signal,
            minBoxSize: 4,
            maxBoxSize: 64
        )
        
        let dfaTime = CFAbsoluteTimeGetCurrent() - dfaStart
        os_signpost(.end, log: OSLog(subsystem: "com.mobilenld.app", category: "DFA"),
                   name: "DFACalculation", signpostID: dfaSignpostID,
                   "Completed in %.4f ms, result: %.6f", dfaTime * 1000, dfaResult)
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // End window processing measurement
        os_signpost(.end, log: performanceLog, name: "WindowProcessing",
                   "Total: %.4f ms (LyE: %.4f ms, DFA: %.4f ms)",
                   totalTime * 1000, lyeTime * 1000, dfaTime * 1000)
        
        return totalTime
    }
    
    // MARK: - Test Signal Generation
    
    private func generateRealtimeTestSignal(length: Int, samplingRate: Int, iteration: Int) -> [Q15] {
        var signal: [Float] = []
        let dt = 1.0 / Float(samplingRate)
        let baseFreq: Float = 0.1 + Float(iteration % 10) * 0.01 // Vary frequency slightly
        
        for i in 0..<length {
            let t = Float(i) * dt + Float(iteration) * dt // Continuous time progression
            
            // Multi-component signal simulating real gait data
            let fundamental = sin(2.0 * Float.pi * baseFreq * t)
            let harmonic = 0.3 * sin(2.0 * Float.pi * baseFreq * 3.0 * t)
            let noise = Float.random(in: -0.1...0.1)
            let trend = 0.05 * sin(2.0 * Float.pi * 0.01 * t) // Slow drift
            
            signal.append(fundamental + harmonic + noise + trend)
        }
        
        // Normalize to Q15 range
        let maxVal = signal.max() ?? 1.0
        let minVal = signal.min() ?? -1.0
        let range = max(maxVal - minVal, 0.1) // Avoid division by zero
        
        let normalizedSignal = signal.map { (($0 - minVal) / range) * 2.0 - 1.0 }
        return FixedPointMath.floatArrayToQ15(normalizedSignal)
    }
    
    // MARK: - System Resource Monitoring
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage - in real implementation would use mach API
        return Double.random(in: 15.0...45.0) // Simulated CPU usage
    }
    
    private func getCurrentMemoryUsage() -> Double {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &count) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     UnsafeMutablePointer<integer_t>.init(OpaquePointer($0)),
                     UnsafeMutablePointer<mach_msg_type_number_t>($0))
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // MB
        }
        return 0.0
    }
    
    // MARK: - Benchmark Finalization
    
    private func finalizeBenchmark(duration: Double) {
        isRunning = false
        
        guard !benchmarkResults.isEmpty else { return }
        
        // Calculate statistics
        let avgTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxTime = processingTimes.max() ?? 0.0
        let minTime = processingTimes.min() ?? 0.0
        let successRate = Double(benchmarkResults.filter { $0.targetMet }.count) / Double(benchmarkResults.count)
        
        // Generate report
        let report = BenchmarkReport(
            duration: duration,
            totalIterations: benchmarkResults.count,
            averageProcessingTime: avgTime,
            maxProcessingTime: maxTime,
            minProcessingTime: minTime,
            targetSuccessRate: successRate,
            results: benchmarkResults
        )
        
        // Save results
        saveBenchmarkResults(report)
        
        print("\n📊 Benchmark Complete!")
        print("   Duration: \(String(format: "%.1f", duration))s")
        print("   Iterations: \(benchmarkResults.count)")
        print("   Avg Time: \(String(format: "%.2f", avgTime * 1000))ms")
        print("   Max Time: \(String(format: "%.2f", maxTime * 1000))ms")
        print("   Success Rate: \(String(format: "%.1f", successRate * 100))%")
        
        energyImpact = "Check Instruments for Energy Log data"
    }
    
    // MARK: - Data Export
    
    private func saveBenchmarkResults(_ report: BenchmarkReport) {
        // Save CSV for analysis
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let csvURL = documentsPath.appendingPathComponent("benchmark_results.csv")
        
        var csvContent = "iteration,timestamp,processing_time_ms,target_met,cpu_usage,memory_mb\n"
        
        for result in report.results {
            csvContent += "\(result.iteration),\(result.timestamp),\(result.processingTime * 1000),\(result.targetMet),\(result.cpuUsage),\(result.memoryUsage)\n"
        }
        
        do {
            try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            print("📁 Results saved to: \(csvURL.path)")
        } catch {
            print("❌ Failed to save results: \(error)")
        }
    }
    
    // MARK: - Stop Benchmark
    
    func stopBenchmark() {
        isRunning = false
    }
}

// MARK: - Data Structures

struct BenchmarkResult {
    let iteration: Int
    let timestamp: Double
    let processingTime: Double
    let targetMet: Bool
    let cpuUsage: Double
    let memoryUsage: Double
}

struct BenchmarkReport {
    let duration: Double
    let totalIterations: Int
    let averageProcessingTime: Double
    let maxProcessingTime: Double
    let minProcessingTime: Double
    let targetSuccessRate: Double
    let results: [BenchmarkResult]
}