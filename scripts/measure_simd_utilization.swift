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
        sum += Int64(squared.wrappedSum())
        
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
        let errorRate = abs(Double(simdResult - scalarResult)) / Double(scalarResult) * 100
        
        print("  Scalar time: \(String(format: "%.6f", scalarTime * 1000))ms")
        print("  SIMD time: \(String(format: "%.6f", simdTime * 1000))ms")
        print("  Speedup: \(String(format: "%.2f", speedup))x")
        print("  SIMD operations: \(totalSimdOps)/\(totalOps) (\(String(format: "%.1f", simdUtilization))%)")
        print("  SIMD efficiency: \(String(format: "%.1f", efficiency))%")
        print("  Error: \(String(format: "%.2e", errorRate))%")
        print()
    }
    
    // Test with 4-way unrolling
    print("=== 4-way Unrolling Performance ===")
    
    let size = 1000
    let (floatA, floatB) = generateTestData(count: size)
    let a = floatA.map { floatToQ15($0) }
    let b = floatB.map { floatToQ15($0) }
    
    // 4-way unrolled SIMD
    func distance4WayUnrolled(_ a: [Int16], _ b: [Int16]) -> Int64 {
        let count = a.count
        let simdWidth = 32  // 4 x 8
        let alignedCount = (count / simdWidth) * simdWidth
        
        var sum0: Int64 = 0
        var sum1: Int64 = 0
        var sum2: Int64 = 0
        var sum3: Int64 = 0
        
        for i in stride(from: 0, to: alignedCount, by: simdWidth) {
            // Process 4 SIMD8 vectors in parallel
            let va0 = SIMD8<Int16>(a[i..<i+8])
            let vb0 = SIMD8<Int16>(b[i..<i+8])
            let diff0 = SIMD8<Int32>(va0.map { Int32($0) }) &- SIMD8<Int32>(vb0.map { Int32($0) })
            sum0 += Int64((diff0 &* diff0).wrappedSum())
            
            let va1 = SIMD8<Int16>(a[i+8..<i+16])
            let vb1 = SIMD8<Int16>(b[i+8..<i+16])
            let diff1 = SIMD8<Int32>(va1.map { Int32($0) }) &- SIMD8<Int32>(vb1.map { Int32($0) })
            sum1 += Int64((diff1 &* diff1).wrappedSum())
            
            let va2 = SIMD8<Int16>(a[i+16..<i+24])
            let vb2 = SIMD8<Int16>(b[i+16..<i+24])
            let diff2 = SIMD8<Int32>(va2.map { Int32($0) }) &- SIMD8<Int32>(vb2.map { Int32($0) })
            sum2 += Int64((diff2 &* diff2).wrappedSum())
            
            let va3 = SIMD8<Int16>(a[i+24..<i+32])
            let vb3 = SIMD8<Int16>(b[i+24..<i+32])
            let diff3 = SIMD8<Int32>(va3.map { Int32($0) }) &- SIMD8<Int32>(vb3.map { Int32($0) })
            sum3 += Int64((diff3 &* diff3).wrappedSum())
        }
        
        var totalSum = sum0 + sum1 + sum2 + sum3
        
        // Cleanup
        for i in alignedCount..<count {
            let diff = Int32(a[i]) - Int32(b[i])
            totalSum += Int64(diff * diff)
        }
        
        return totalSum
    }
    
    let unrolledStart = CFAbsoluteTimeGetCurrent()
    var unrolledResult: Int64 = 0
    for _ in 0..<100 {
        unrolledResult = distance4WayUnrolled(a, b)
    }
    let unrolledTime = (CFAbsoluteTimeGetCurrent() - unrolledStart) / 100.0
    
    let unrolledSpeedup = scalarTime / unrolledTime
    print("  4-way unrolled time: \(String(format: "%.6f", unrolledTime * 1000))ms")
    print("  Speedup vs scalar: \(String(format: "%.2f", unrolledSpeedup))x")
    print("  Speedup vs basic SIMD: \(String(format: "%.2f", simdTime / unrolledTime))x")
    
    // Final summary
    print("\n=== Summary ===")
    print("SIMD utilization for 150-sample window: \(String(format: "%.1f", Double(144) / Double(150) * 100))%")
    print("SIMD utilization for 1000-sample window: \(String(format: "%.1f", Double(1000 - 1000 % 8) / Double(1000) * 100))%")
    print("Theoretical maximum speedup: 8x")
    print("Achieved speedup: ~\(String(format: "%.1f", speedup))x")
    print("Efficiency: ~\(String(format: "%.1f", efficiency))%")
}

// Convenience extension
extension SIMD8 where Scalar == Int16 {
    init<C>(_ data: C) where C: Collection, C.Element == Int16 {
        let array = Array(data)
        self.init(array[0], array[1], array[2], array[3], 
                  array[4], array[5], array[6], array[7])
    }
}

extension SIMD8 where Scalar == Int32 {
    init<C>(_ data: C) where C: Collection, C.Element == Int32 {
        let array = Array(data)
        self.init(array[0], array[1], array[2], array[3], 
                  array[4], array[5], array[6], array[7])
    }
}

// Run measurement
measureSIMDUtilization()