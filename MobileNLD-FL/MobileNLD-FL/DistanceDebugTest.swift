//
//  DistanceDebugTest.swift
//  MobileNLD-FL
//
//  Debug test to identify distance calculation issue
//

import Foundation

struct DistanceDebugTest {
    
    static func runDebugTest() {
        print("=== Distance Calculation Debug Test ===\n")
        
        // Test 1: Simple case with known values
        print("Test 1: Simple 2D case")
        let a2d: [Q15] = [FixedPointMath.floatToQ15(0.5), FixedPointMath.floatToQ15(0.5)]
        let b2d: [Q15] = [FixedPointMath.floatToQ15(-0.5), FixedPointMath.floatToQ15(-0.5)]
        
        a2d.withUnsafeBufferPointer { aPtr in
            b2d.withUnsafeBufferPointer { bPtr in
                let distance = SIMDOptimizations.euclideanDistanceSIMD(
                    aPtr.baseAddress!,
                    bPtr.baseAddress!,
                    dimension: 2
                )
                
                // Manual calculation
                let diff = 0.5 - (-0.5) // = 1.0
                let expected = Float(sqrt(2.0 * Double(diff) * Double(diff))) // = sqrt(2)
                
                print("  Result: \(distance)")
                print("  Expected: \(expected)")
                print("  Match: \(abs(distance - expected) < 0.001)\n")
            }
        }
        
        // Test 2: Check Q15 conversion
        print("Test 2: Q15 conversion check")
        let testFloat: Float = 0.5
        let q15Val = FixedPointMath.floatToQ15(testFloat)
        let backToFloat = FixedPointMath.q15ToFloat(q15Val)
        print("  Original: \(testFloat)")
        print("  Q15: \(q15Val)")
        print("  Back to float: \(backToFloat)")
        print("  Q15 max: \(Q15.max) = \(FixedPointMath.q15ToFloat(Q15.max))")
        print("  Q15 min: \(Q15.min) = \(FixedPointMath.q15ToFloat(Q15.min))\n")
        
        // Test 3: Manual distance calculation
        print("Test 3: Manual calculation for dim=10")
        let dim = 10
        let aVal: Q15 = FixedPointMath.floatToQ15(0.5)
        let bVal: Q15 = FixedPointMath.floatToQ15(-0.5)
        
        // Manual sum calculation
        var manualSum: Int64 = 0
        for _ in 0..<dim {
            let diff = Int64(aVal) - Int64(bVal)
            manualSum += diff * diff
        }
        
        print("  a value (Q15): \(aVal)")
        print("  b value (Q15): \(bVal)")
        print("  diff (Q15): \(Int64(aVal) - Int64(bVal))")
        print("  diff^2: \((Int64(aVal) - Int64(bVal)) * (Int64(aVal) - Int64(bVal)))")
        print("  sum (10 dims): \(manualSum)")
        
        let q15Scale = Float(1 << 15)
        let scaledSum = Float(manualSum) / (q15Scale * q15Scale)
        let manualDistance = sqrt(scaledSum)
        
        print("  q15Scale: \(q15Scale)")
        print("  scaledSum: \(scaledSum)")
        print("  Manual distance: \(manualDistance)")
        print("  Expected: \(sqrt(10.0))\n")
        
        // Test 4: Test actual function with dim=10
        print("Test 4: Actual function test (dim=10)")
        let a10d = [Q15](repeating: FixedPointMath.floatToQ15(0.5), count: dim)
        let b10d = [Q15](repeating: FixedPointMath.floatToQ15(-0.5), count: dim)
        
        a10d.withUnsafeBufferPointer { aPtr in
            b10d.withUnsafeBufferPointer { bPtr in
                let distance = SIMDOptimizations.euclideanDistanceSIMD(
                    aPtr.baseAddress!,
                    bPtr.baseAddress!,
                    dimension: dim
                )
                
                print("  Function result: \(distance)")
                print("  Expected: \(sqrt(10.0))")
                print("  Error: \(abs(distance - sqrt(10.0)) / sqrt(10.0) * 100)%\n")
            }
        }
        
        print("=== End Debug Test ===")
    }
}