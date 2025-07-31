//
//  DynamicRangeMonitor.swift
//  MobileNLD-FL
//
//  Dynamic Range Monitoring Module for Comprehensive Dynamic Adjustment System
//  Monitors signal statistics in real-time and predicts overflow/underflow risks
//

import Foundation
import Accelerate

/// Dynamic range monitoring for Q15 fixed-point arithmetic
public class DynamicRangeMonitor {
    
    // MARK: - Properties
    
    /// Sliding window for online statistics
    private var slidingWindow: [Q15]
    private let windowSize: Int
    
    /// Statistics cache
    private var cachedMean: Float = 0.0
    private var cachedVariance: Float = 0.0
    private var cachedPeakValue: Float = 0.0
    
    /// Risk thresholds
    private let overflowThreshold: Float = 0.9  // 90% of Q15 range
    private let underflowThreshold: Float = 0.1 // 10% of Q15 range
    
    /// Monitoring state
    private(set) var isMonitoring = false
    private var updateCounter = 0
    private let updateInterval = 16  // Update every 16 samples for efficiency
    
    // MARK: - Initialization
    
    public init(windowSize: Int = 128) {
        self.windowSize = windowSize
        self.slidingWindow = [Q15](repeating: 0, count: windowSize)
    }
    
    // MARK: - Public Interface
    
    /// Monitor a new sample and update statistics
    @inline(__always)
    public func monitorSample(_ sample: Q15) -> RangeStatus {
        // Shift window and add new sample
        slidingWindow.removeFirst()
        slidingWindow.append(sample)
        
        updateCounter += 1
        
        // Update statistics at intervals for efficiency
        if updateCounter >= updateInterval {
            updateStatistics()
            updateCounter = 0
        }
        
        // Quick check for immediate overflow risk
        let normalizedSample = abs(Float(sample)) / Float(FixedPointMath.Q15_SCALE)
        if normalizedSample > overflowThreshold {
            return .overflowRisk(scale: normalizedSample)
        }
        
        return evaluateRangeStatus()
    }
    
    /// Monitor a batch of samples
    public func monitorBatch(_ samples: [Q15]) -> RangeStatus {
        // Use vDSP for efficient batch processing
        samples.withUnsafeBufferPointer { samplesPtr in
            var maxValue: Float = 0
            var minValue: Float = 0
            
            // Convert to float for statistics
            var floatSamples = [Float](repeating: 0, count: samples.count)
            vDSP_vflt16(samplesPtr.baseAddress!, 1, &floatSamples, 1, vDSP_Length(samples.count))
            
            // Scale to normalized range
            var scale = 1.0 / Float(FixedPointMath.Q15_SCALE)
            vDSP_vsmul(floatSamples, 1, &scale, &floatSamples, 1, vDSP_Length(samples.count))
            
            // Find max and min
            vDSP_maxv(floatSamples, 1, &maxValue, vDSP_Length(samples.count))
            vDSP_minv(floatSamples, 1, &minValue, vDSP_Length(samples.count))
            
            // Update cached peak
            cachedPeakValue = max(abs(maxValue), abs(minValue))
            
            // Update sliding window with latest samples
            let startIndex = max(0, samples.count - windowSize)
            if startIndex < samples.count {
                slidingWindow = Array(samples[startIndex...])
            }
        }
        
        updateStatistics()
        return evaluateRangeStatus()
    }
    
    /// Get current signal statistics
    public func getStatistics() -> SignalStatistics {
        return SignalStatistics(
            mean: cachedMean,
            variance: cachedVariance,
            peakValue: cachedPeakValue,
            dynamicRange: calculateDynamicRange()
        )
    }
    
    /// Predict risk for upcoming samples based on trend
    public func predictRisk(horizon: Int = 10) -> RiskPrediction {
        // Simple linear extrapolation of peak values
        let recentPeaks = extractRecentPeaks()
        guard recentPeaks.count >= 2 else {
            return RiskPrediction(probability: 0.0, timeToRisk: Int.max)
        }
        
        // Calculate trend
        let trend = (recentPeaks.last! - recentPeaks.first!) / Float(recentPeaks.count - 1)
        let predictedPeak = cachedPeakValue + trend * Float(horizon)
        
        // Calculate risk probability
        let riskProbability = min(1.0, max(0.0, (predictedPeak - overflowThreshold) / (1.0 - overflowThreshold)))
        let timeToRisk = riskProbability > 0.5 ? Int((overflowThreshold - cachedPeakValue) / trend) : Int.max
        
        return RiskPrediction(probability: riskProbability, timeToRisk: max(0, timeToRisk))
    }
    
    // MARK: - Private Methods
    
    private func updateStatistics() {
        slidingWindow.withUnsafeBufferPointer { windowPtr in
            // Convert to float for accurate statistics
            var floatWindow = [Float](repeating: 0, count: windowSize)
            vDSP_vflt16(windowPtr.baseAddress!, 1, &floatWindow, 1, vDSP_Length(windowSize))
            
            // Normalize
            var scale = 1.0 / Float(FixedPointMath.Q15_SCALE)
            vDSP_vsmul(floatWindow, 1, &scale, &floatWindow, 1, vDSP_Length(windowSize))
            
            // Calculate mean
            vDSP_meanv(floatWindow, 1, &cachedMean, vDSP_Length(windowSize))
            
            // Calculate variance
            var meanSquared: Float = 0
            vDSP_measqv(floatWindow, 1, &meanSquared, vDSP_Length(windowSize))
            cachedVariance = meanSquared - cachedMean * cachedMean
            
            // Update peak
            var maxVal: Float = 0
            var minVal: Float = 0
            vDSP_maxv(floatWindow, 1, &maxVal, vDSP_Length(windowSize))
            vDSP_minv(floatWindow, 1, &minVal, vDSP_Length(windowSize))
            cachedPeakValue = max(abs(maxVal), abs(minVal))
        }
    }
    
    private func evaluateRangeStatus() -> RangeStatus {
        let dynamicRange = calculateDynamicRange()
        
        // Check overflow risk
        if cachedPeakValue > overflowThreshold {
            return .overflowRisk(scale: cachedPeakValue)
        }
        
        // Check underflow risk
        if dynamicRange < underflowThreshold && cachedPeakValue < underflowThreshold {
            return .underflowRisk(scale: cachedPeakValue)
        }
        
        // Check if near limits
        if cachedPeakValue > 0.7 {
            return .nearLimit(currentRange: dynamicRange)
        }
        
        return .optimal(currentRange: dynamicRange)
    }
    
    private func calculateDynamicRange() -> Float {
        // Dynamic range as ratio of peak to noise floor
        let noiseFloor = sqrt(cachedVariance)
        guard noiseFloor > 0 else { return 0 }
        return cachedPeakValue / noiseFloor
    }
    
    private func extractRecentPeaks() -> [Float] {
        // Extract local peaks from recent samples
        var peaks: [Float] = []
        let stride = windowSize / 8
        
        for i in stride(from: 0, to: windowSize - stride, by: stride) {
            let segment = Array(slidingWindow[i..<(i + stride)])
            if let maxSample = segment.max() {
                peaks.append(Float(abs(maxSample)) / Float(FixedPointMath.Q15_SCALE))
            }
        }
        
        return peaks
    }
}

// MARK: - Supporting Types

/// Range monitoring status
public enum RangeStatus: Equatable {
    case optimal(currentRange: Float)
    case nearLimit(currentRange: Float)
    case overflowRisk(scale: Float)
    case underflowRisk(scale: Float)
    
    /// Recommended scale factor for adjustment
    public var recommendedScale: Float {
        switch self {
        case .optimal:
            return 1.0
        case .nearLimit(let range):
            return 0.8 / range  // Scale down by 20%
        case .overflowRisk(let scale):
            return 0.7 / scale  // Aggressive scaling
        case .underflowRisk(let scale):
            return min(10.0, 0.5 / scale)  // Scale up, but limit amplification
        }
    }
}

/// Signal statistics
public struct SignalStatistics {
    public let mean: Float
    public let variance: Float
    public let peakValue: Float
    public let dynamicRange: Float
}

/// Risk prediction
public struct RiskPrediction {
    public let probability: Float  // 0.0 to 1.0
    public let timeToRisk: Int     // Samples until risk threshold
}

// MARK: - Extensions for Integration

extension DynamicRangeMonitor {
    
    /// Create optimal monitor for specific signal type
    public static func optimalMonitor(for signalType: SignalType) -> DynamicRangeMonitor {
        switch signalType {
        case .ecg:
            return DynamicRangeMonitor(windowSize: 256)  // ~1 second at 256Hz
        case .eeg:
            return DynamicRangeMonitor(windowSize: 512)  // Longer window for slower dynamics
        case .accelerometer:
            return DynamicRangeMonitor(windowSize: 128)  // Fast response
        case .general:
            return DynamicRangeMonitor(windowSize: 256)
        }
    }
}

public enum SignalType {
    case ecg
    case eeg
    case accelerometer
    case general
}