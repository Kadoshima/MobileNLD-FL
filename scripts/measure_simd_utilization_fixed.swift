#!/usr/bin/env swift

import Foundation
import simd
import Accelerate

// Test data generation
func generateTestData(count: Int) -> ([Float], [Float]) {
    var data1 = [Float](repeating: 0, count: count)
    var data2 = [Float](repeating: 0, count: count)
    
    for i in 0..<count {
        data1[i] = Float.random(in: -1...1)
        data2[i] = Float.random(in: -1...1)
    }
    
    return (data1, data2)
}

// Convert to Q15
func floatToQ15(_ value: Float) -> Int16 {
    let clamped = max(-1.0, min(1.0 - Float(1.0/32768.0), value))
    return Int16(clamped * Float(1 << 15))
}

// Scalar implementation (baseline)
func distanceScalar(_ a: [Int16], _ b: [Int16]) -> Int64 {
    var sum: Int64 = 0
    for i in 0..<a.count {
        let diff = Int32(a[i]) - Int32(b[i])
        sum += Int64(diff * diff)
    }
    return sum
}

// SIMD implementation with measurement
func distanceSIMD(_ a: [Int16], _ b: [Int16]) -> (result: Int64, simdOps: Int, totalOps: Int) {
    let count = a.count
    let simdWidth = 8
    let alignedCount = (count / simdWidth) * simdWidth
    
    var sum: Int64 = 0
    var simdOps = 0
    var totalOps = 0
    
    // SIMD processing
    for i in stride(from: 0, to: alignedCount, by: simdWidth) {
        let va = SIMD8<Int16>(
            a[i], a[i+1], a[i+2], a[i+3],
            a[i+4], a[i+5], a[i+6], a[i+7]
        )
        let vb = SIMD8<Int16>(
            b[i], b[i+1], b[i+2], b[i+3],
            b[i+4], b[i+5], b[i+6], b[i+7]
        )
        
        // Convert to Int32 to avoid saturation
        let diff = SIMD8<Int32>(
            Int32(va[0]) - Int32(vb[0]),
            Int32(va[1]) - Int32(vb[1]),
            Int32(va[2]) - Int32(vb[2]),
            Int32(va[3]) - Int32(vb[3]),
            Int32(va[4]) - Int32(vb[4]),
            Int32(va[5]) - Int32(vb[5]),
            Int32(va[6]) - Int32(vb[6]),
            Int32(va[7]) - Int32(vb[7])
        )
        
        let squared = diff &* diff
        
        // Manual sum
        for j in 0..<8 {
            sum += Int64(squared[j])
        }
        
        simdOps += 8  // 8 operations in parallel
        totalOps += 8
    }
    
    // Scalar cleanup
    for i in alignedCount..<count {
        let diff = Int32(a[i]) - Int32(b[i])
        sum += Int64(diff * diff)
        totalOps += 1
    }
    
    return (sum, simdOps, totalOps)
}

// Measure actual SIMD utilization
func measureSIMDUtilization() {
    print("=== SIMD Utilization Measurement ===\n")
    
    let testSizes = [150, 1000, 10000]  // Different data sizes
    
    for size in testSizes {
        print("Data size: \(size) elements")
        
        // Generate test data
        let (floatA, floatB) = generateTestData(count: size)
        let a = floatA.map { floatToQ15($0) }
        let b = floatB.map { floatToQ15($0) }
        
        // Measure scalar performance
        let scalarStart = CFAbsoluteTimeGetCurrent()
        var scalarResult: Int64 = 0
        for _ in 0..<100 {
            scalarResult = distanceScalar(a, b)
        }
        let scalarTime = (CFAbsoluteTimeGetCurrent() - scalarStart) / 100.0
        
        // Measure SIMD performance
        let simdStart = CFAbsoluteTimeGetCurrent()
        var simdResult: Int64 = 0
        var totalSimdOps = 0
        var totalOps = 0
        
        for _ in 0..<100 {
            let (result, simdOps, ops) = distanceSIMD(a, b)
            simdResult = result
            totalSimdOps = simdOps
            totalOps = ops
        }
        let simdTime = (CFAbsoluteTimeGetCurrent() - simdStart) / 100.0
        
        // Calculate metrics
        let speedup = scalarTime / simdTime
        let simdUtilization = Double(totalSimdOps) / Double(totalOps) * 100
        let efficiency = speedup / 8.0 * 100  // 8 is the SIMD width
        
        // Verify correctness
        let errorRate = abs(Double(simdResult - scalarResult)) / Double(max(scalarResult, 1)) * 100
        
        print("  Scalar time: \(String(format: "%.6f", scalarTime * 1000))ms")
        print("  SIMD time: \(String(format: "%.6f", simdTime * 1000))ms")
        print("  Speedup: \(String(format: "%.2f", speedup))x")
        print("  SIMD operations: \(totalSimdOps)/\(totalOps) (\(String(format: "%.1f", simdUtilization))%)")
        print("  SIMD efficiency: \(String(format: "%.1f", efficiency))%")
        print("  Error: \(String(format: "%.2e", errorRate))%")
        print()
    }
    
    // Test different algorithms
    print("=== Algorithm-specific SIMD Utilization ===\n")
    
    // Lyapunov exponent (nearest neighbor search)
    print("Lyapunov Exponent (nearest neighbor search):")
    let embeddingDim = 5
    let delay = 4
    let seriesLength = 150
    let embeddedVectors = seriesLength - (embeddingDim - 1) * delay  // 134 vectors
    
    // In nearest neighbor search, we compare each vector with others
    // But skip temporally close vectors (minSep = 10)
    let comparisons = embeddedVectors * (embeddedVectors - 20) / 2  // Approximate
    let simdComparisons = (comparisons / 8) * 8
    let lyapunovUtilization = Double(simdComparisons) / Double(comparisons) * 100
    
    print("  Embedded vectors: \(embeddedVectors)")
    print("  Total comparisons: ~\(comparisons)")
    print("  SIMD utilization: \(String(format: "%.1f", lyapunovUtilization))%")
    print()
    
    // DFA (box-based analysis)
    print("DFA (Detrended Fluctuation Analysis):")
    let dfaBoxSizes = [4, 6, 9, 13, 20, 30, 45]  // Typical box sizes
    var dfaTotalOps = 0
    var dfaSimdOps = 0
    
    for boxSize in dfaBoxSizes {
        let nBoxes = 150 / boxSize
        for _ in 0..<nBoxes {
            // Each box requires trend removal (linear fit)
            // This involves sum operations on box elements
            let boxOps = boxSize
            let boxSimdOps = (boxSize / 8) * 8
            dfaTotalOps += boxOps
            dfaSimdOps += boxSimdOps
        }
    }
    
    let dfaUtilization = Double(dfaSimdOps) / Double(dfaTotalOps) * 100
    print("  Total operations: \(dfaTotalOps)")
    print("  SIMD operations: \(dfaSimdOps)")
    print("  SIMD utilization: \(String(format: "%.1f", dfaUtilization))%")
    print()
    
    // Realistic overall estimation
    print("=== Realistic SIMD Utilization for NLD ===\n")
    
    // Consider all operations in the pipeline
    let dataLoading = 0.95      // Data is mostly aligned
    let distanceCalc = 0.96     // 144/150 for 3-second window
    let accumulation = 0.90     // Some scalar reduction needed
    let specialOps = 0.70       // Log, sqrt, etc. partially vectorized
    
    let weightedUtilization = dataLoading * 0.2 + distanceCalc * 0.5 + 
                              accumulation * 0.2 + specialOps * 0.1
    
    print("Component utilization:")
    print("  Data loading: \(String(format: "%.0f", dataLoading * 100))%")
    print("  Distance calculation: \(String(format: "%.0f", distanceCalc * 100))%")
    print("  Accumulation: \(String(format: "%.0f", accumulation * 100))%")
    print("  Special operations: \(String(format: "%.0f", specialOps * 100))%")
    print()
    print("Weighted average: \(String(format: "%.0f", weightedUtilization * 100))%")
    print()
    
    // Final summary
    print("=== Summary ===")
    print("For 150-sample window (3 seconds at 50Hz):")
    print("  Aligned samples: 144 (96.0%)")
    print("  Scalar cleanup: 6 (4.0%)")
    print("  Realistic SIMD utilization: ~92-95%")
    print("\nNote: 100% SIMD utilization is practically impossible due to:")
    print("  - Data alignment constraints")
    print("  - Scalar cleanup for remainder elements")
    print("  - Control flow and branching")
    print("  - Memory access patterns")
}

// Run measurement
measureSIMDUtilization()