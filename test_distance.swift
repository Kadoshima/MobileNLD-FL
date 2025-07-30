#!/usr/bin/env xcrun swift

import Foundation

// Q15 type definition
typealias Q15 = Int16

// Fixed-point math
struct FixedPointMath {
    static func floatToQ15(_ value: Float) -> Q15 {
        let scaled = value * Float(1 << 15)
        let clamped = max(Float(Int16.min), min(Float(Int16.max), scaled))
        return Q15(clamped)
    }
    
    static func q15ToFloat(_ value: Q15) -> Float {
        return Float(value) / Float(1 << 15)
    }
}

// Simple SIMD8 extensions
extension SIMD8 where Scalar == Int16 {
    var lowHalf: SIMD4<Int16> {
        return SIMD4(self[0], self[1], self[2], self[3])
    }
    
    var highHalf: SIMD4<Int16> {
        return SIMD4(self[4], self[5], self[6], self[7])
    }
}

// Simplified euclideanDistanceSIMD
func euclideanDistanceSIMD(_ a: UnsafePointer<Q15>, _ b: UnsafePointer<Q15>, dimension: Int) -> Float {
    var sum: Int64 = 0
    
    for i in 0..<dimension {
        let diff = Int64(a[i]) - Int64(b[i])
        sum += diff * diff
    }
    
    let q15Scale = Float(1 << 15)
    let scaledSum = Float(sum) / (q15Scale * q15Scale)
    return sqrt(scaledSum)
}

// Test function
func testDistance() {
    print("Testing euclidean distance calculation...")
    
    // Test case 1: Simple 2D
    let dim = 10
    let a = [Q15](repeating: FixedPointMath.floatToQ15(0.5), count: dim)
    let b = [Q15](repeating: FixedPointMath.floatToQ15(-0.5), count: dim)
    
    a.withUnsafeBufferPointer { aPtr in
        b.withUnsafeBufferPointer { bPtr in
            let distance = euclideanDistanceSIMD(aPtr.baseAddress!, bPtr.baseAddress!, dimension: dim)
            
            // Manual calculation
            let diff: Float = 0.5 - (-0.5) // = 1.0
            let expected = sqrtf(Float(dim)) * diff // sqrt(10) * 1.0 = 3.162
            let error = abs(distance - expected) / expected
            
            print("Dimension \(dim):")
            print("  Distance: \(distance)")
            print("  Expected: \(expected)")
            print("  Error: \(error * 100)%")
            print("  Test: \(error < 0.01 ? "PASS" : "FAIL")")
        }
    }
}

testDistance()