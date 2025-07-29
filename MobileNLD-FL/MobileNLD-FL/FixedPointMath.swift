//
//  FixedPointMath.swift
//  MobileNLD-FL
//
//  Fixed-point arithmetic implementation for real-time nonlinear dynamics
//  Q15 format: 1 sign bit + 15 fractional bits, range [-1, 1)
//

import Foundation
import Accelerate

typealias Q15 = Int16

struct FixedPointMath {
    
    // MARK: - Constants
    static let Q15_SCALE: Int32 = 32768 // 2^15
    static let Q15_MAX: Q15 = 32767     // 0.999969482421875
    static let Q15_MIN: Q15 = -32768    // -1.0
    
    // MARK: - Conversion Functions
    
    /// Convert Float to Q15 fixed-point
    static func floatToQ15(_ value: Float) -> Q15 {
        let scaled = value * Float(Q15_SCALE)
        return Q15(max(Float(Q15_MIN), min(Float(Q15_MAX), scaled)))
    }
    
    /// Convert Q15 fixed-point to Float
    static func q15ToFloat(_ value: Q15) -> Float {
        return Float(value) / Float(Q15_SCALE)
    }
    
    /// Convert Float array to Q15 array
    static func floatArrayToQ15(_ values: [Float]) -> [Q15] {
        return values.map { floatToQ15($0) }
    }
    
    /// Convert Q15 array to Float array
    static func q15ArrayToFloat(_ values: [Q15]) -> [Float] {
        return values.map { q15ToFloat($0) }
    }
    
    // MARK: - Basic Arithmetic Operations
    
    /// Q15 multiplication with proper scaling
    static func multiply(_ a: Q15, _ b: Q15) -> Q15 {
        let product = Int32(a) * Int32(b)
        return Q15(product >> 15)
    }
    
    /// Q15 division with proper scaling
    static func divide(_ a: Q15, _ b: Q15) -> Q15 {
        guard b != 0 else { return Q15_MAX }
        let dividend = Int32(a) << 15
        return Q15(dividend / Int32(b))
    }
    
    /// Q15 addition with saturation
    static func add(_ a: Q15, _ b: Q15) -> Q15 {
        let sum = Int32(a) + Int32(b)
        return Q15(max(Int32(Q15_MIN), min(Int32(Q15_MAX), sum)))
    }
    
    /// Q15 subtraction with saturation
    static func subtract(_ a: Q15, _ b: Q15) -> Q15 {
        let diff = Int32(a) - Int32(b)
        return Q15(max(Int32(Q15_MIN), min(Int32(Q15_MAX), diff)))
    }
    
    // MARK: - Advanced Mathematical Functions
    
    /// Natural logarithm using lookup table for Q15
    /// Input range: (0, 1], Output: Q15 representation of ln(x)
    static func ln(_ x: Q15) -> Q15 {
        guard x > 0 else { return Q15_MIN } // ln(0) = -∞
        
        // Use lookup table for better performance
        // This is a simplified implementation - in practice would use larger LUT
        let floatVal = q15ToFloat(x)
        let lnResult = log(floatVal)
        return floatToQ15(lnResult)
    }
    
    /// Square root using Newton-Raphson method for Q15
    static func sqrt(_ x: Q15) -> Q15 {
        guard x >= 0 else { return 0 }
        guard x > 0 else { return 0 }
        
        // Newton-Raphson: x_{n+1} = (x_n + a/x_n) / 2
        var estimate: Q15 = x >> 1 // Initial guess
        
        for _ in 0..<8 { // 8 iterations should be sufficient for Q15 precision
            let quotient = divide(x, estimate)
            estimate = Q15((Int32(estimate) + Int32(quotient)) >> 1)
        }
        
        return estimate
    }
    
    /// Absolute value
    static func abs(_ x: Q15) -> Q15 {
        return x >= 0 ? x : Q15(-Int32(x))
    }
    
    // MARK: - Vector Operations using Accelerate
    
    /// Compute mean of Q15 array
    static func mean(_ values: [Q15]) -> Q15 {
        guard !values.isEmpty else { return 0 }
        
        let sum = values.reduce(Int32(0)) { Int32($0) + Int32($1) }
        return Q15(sum / Int32(values.count))
    }
    
    /// Compute variance of Q15 array
    static func variance(_ values: [Q15]) -> Q15 {
        guard values.count > 1 else { return 0 }
        
        let meanVal = mean(values)
        let sumSquaredDiff = values.reduce(Int32(0)) { acc, val in
            let diff = subtract(val, meanVal)
            return acc + Int32(multiply(diff, diff))
        }
        
        return Q15(sumSquaredDiff / Int32(values.count - 1))
    }
    
    /// Compute standard deviation of Q15 array
    static func standardDeviation(_ values: [Q15]) -> Q15 {
        return sqrt(variance(values))
    }
}

// MARK: - Q15 Extensions for convenience

extension Q15 {
    var toFloat: Float {
        return FixedPointMath.q15ToFloat(self)
    }
    
    static func from(_ float: Float) -> Q15 {
        return FixedPointMath.floatToQ15(float)
    }
}