#!/usr/bin/env swift

import Foundation

// Q15 fixed-point type definition
typealias Q15 = Int16

// Simple timer for performance measurement
func measureTime(block: () -> Void) -> Double {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    return (CFAbsoluteTimeGetCurrent() - start) * 1000 // Convert to milliseconds
}

// Load test data from CSV
func loadTestData() -> [Q15]? {
    let path = "/Users/kadoshima/Documents/MobileNLD-FL/実験/raw_data/rossler_data/rossler_q15.csv"
    
    guard let csvData = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("Error: Could not load test data from \(path)")
        return nil
    }
    
    let lines = csvData.components(separatedBy: .newlines)
    guard lines.count > 1 else { return nil }
    
    var q15Data: [Q15] = []
    
    // Skip header and read x_q15 column
    for i in 1..<lines.count {
        let values = lines[i].components(separatedBy: ",")
        if values.count > 1, let xQ15 = Int16(values[1]) {
            q15Data.append(xQ15)
        }
    }
    
    return q15Data
}

// Simplified Lyapunov exponent calculation for baseline testing
func lyapunovExponentBaseline(_ data: [Q15]) -> Float {
    guard data.count > 50 else { return 0.0 }
    
    let embeddingDim = 5
    let delay = 4
    let numPoints = min(100, data.count - (embeddingDim - 1) * delay)
    
    var sum: Float = 0
    var count = 0
    
    // Simple phase space reconstruction and nearest neighbor calculation
    for i in 0..<numPoints-1 {
        // Find nearest neighbor (simplified)
        var minDist: Float = Float.greatestFiniteMagnitude
        
        for j in 0..<numPoints {
            if abs(i - j) < 10 { continue } // Theiler window
            
            var dist: Float = 0
            for k in 0..<embeddingDim {
                let diff = Float(data[i + k * delay] - data[j + k * delay]) / 32768.0
                dist += diff * diff
            }
            
            if dist > 0 && dist < minDist {
                minDist = dist
            }
        }
        
        if minDist < Float.greatestFiniteMagnitude {
            sum += log(sqrt(minDist))
            count += 1
        }
    }
    
    return count > 0 ? sum / Float(count) : 0.0
}

// Run basic performance experiment
func runBasicPerformanceExperiment(testData: [Q15]) {
    print("=== Basic Performance Measurement ===")
    print("Comparing simplified baseline implementation")
    print()
    
    let dataSizes = [50, 100, 200, 500, 1000]
    let iterations = 10
    
    var results: [[String: Any]] = []
    
    for size in dataSizes {
        guard size <= testData.count else { continue }
        let data = Array(testData.prefix(size))
        
        print("Data size: \(size) samples")
        
        var times: [Double] = []
        
        // Warmup
        for _ in 0..<3 {
            _ = lyapunovExponentBaseline(data)
        }
        
        // Measure
        for _ in 0..<iterations {
            let time = measureTime {
                _ = lyapunovExponentBaseline(data)
            }
            times.append(time)
        }
        
        let avgTime = times.reduce(0, +) / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        
        print("  Average: \(String(format: "%.2f", avgTime))ms")
        print("  Min: \(String(format: "%.2f", minTime))ms, Max: \(String(format: "%.2f", maxTime))ms")
        print()
        
        results.append([
            "data_size": size,
            "avg_time_ms": avgTime,
            "min_time_ms": minTime,
            "max_time_ms": maxTime,
            "iterations": iterations
        ])
    }
    
    // Save results
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
        .replacingOccurrences(of: " ", with: "_")
    
    let resultsPath = "/Users/kadoshima/Documents/MobileNLD-FL/実験/results/\(timestamp)_basic_performance.json"
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: ["measurements": results], options: .prettyPrinted)
        try jsonData.write(to: URL(fileURLWithPath: resultsPath))
        print("Results saved to: \(resultsPath)")
    } catch {
        print("Error saving results: \(error)")
    }
}

// Main execution
print("MobileNLD-FL Performance Experiment")
print("===================================")
print()

// Load test data
guard let testData = loadTestData() else {
    print("Failed to load test data")
    exit(1)
}

print("Loaded \(testData.count) samples from Rössler system")
print()

// Run experiments
runBasicPerformanceExperiment(testData: testData)

print("\nExperiment completed!")
print("Note: This is a simplified baseline measurement.")
print("For full implementation comparison, please run within Xcode project.")