//
//  AdaptiveScalingEngine.swift
//  MobileNLD-FL
//
//  Adaptive Scaling Engine for Comprehensive Dynamic Adjustment System
//  Implements multi-stage scaling with precision compensation
//

import Foundation
import Accelerate

/// Adaptive scaling engine for Q15 dynamic adjustment
public class AdaptiveScalingEngine {
    
    // MARK: - Properties
    
    /// Scaling history for reverse compensation
    private var scalingHistory: [ScalingRecord] = []
    private let historySize = 100
    
    /// Multi-stage scaling factors
    private var globalScale: Float = 1.0
    private var stageScales: [String: Float] = [:]
    
    /// Precision compensation parameters
    private var errorAccumulator: Float = 0.0
    private let errorThreshold: Float = 1e-6
    
    /// Adaptive parameters
    private var adaptationRate: Float = 0.1
    private let minScale: Float = 0.01
    private let maxScale: Float = 100.0
    
    // MARK: - Public Interface
    
    /// Apply adaptive scaling to signal
    public func scaleSignal(_ signal: [Q15], stage: String = "default") -> (scaled: [Q15], scaleInfo: ScalingInfo) {
        // Get range status from monitor (assuming it's passed in or accessible)
        let rangeStatus = analyzeSignalRange(signal)
        
        // Determine optimal scale factor
        let optimalScale = calculateOptimalScale(rangeStatus, stage: stage)
        
        // Apply multi-stage scaling
        let scaledSignal = applyScaling(signal, scale: optimalScale)
        
        // Record scaling for reverse operation
        let record = ScalingRecord(
            timestamp: Date(),
            stage: stage,
            scaleFactor: optimalScale,
            inputRange: rangeStatus,
            errorEstimate: estimateScalingError(optimalScale)
        )
        recordScaling(record)
        
        // Update stage-specific scale
        stageScales[stage] = optimalScale
        
        return (scaledSignal, ScalingInfo(scaleFactor: optimalScale, stage: stage))
    }
    
    /// Reverse scaling with precision compensation
    public func reverseScale(_ signal: [Q15], scaleInfo: ScalingInfo) -> [Q15] {
        guard let record = findScalingRecord(for: scaleInfo) else {
            // Fallback to simple reverse scaling
            return simpleReverseScale(signal, scale: scaleInfo.scaleFactor)
        }
        
        // Apply reverse scaling with error compensation
        return reverseScaleWithCompensation(signal, record: record)
    }
    
    /// Batch scaling with SIMD optimization
    public func scaleBatch(_ batch: [[Q15]], stage: String = "default") -> [(scaled: [Q15], scaleInfo: ScalingInfo)] {
        // Analyze entire batch for global scaling decision
        let batchRange = analyzeBatchRange(batch)
        let globalOptimalScale = calculateOptimalScale(batchRange, stage: stage)
        
        // Apply consistent scaling across batch
        return batch.map { signal in
            let scaled = applyScaling(signal, scale: globalOptimalScale)
            let info = ScalingInfo(scaleFactor: globalOptimalScale, stage: stage)
            return (scaled, info)
        }
    }
    
    /// Get scaling recommendations for multi-stage processing
    public func getScalingStrategy(for stages: [String]) -> ScalingStrategy {
        var strategy = ScalingStrategy()
        
        // Analyze inter-stage dependencies
        for (i, stage) in stages.enumerated() {
            let previousScale = i > 0 ? stageScales[stages[i-1]] ?? 1.0 : 1.0
            let recommendedScale = recommendScaleForStage(stage, previousScale: previousScale)
            strategy.stageScales[stage] = recommendedScale
        }
        
        // Calculate cumulative scaling effect
        strategy.cumulativeScale = strategy.stageScales.values.reduce(1.0, *)
        
        // Warn if cumulative scaling is extreme
        if strategy.cumulativeScale < 0.001 || strategy.cumulativeScale > 1000 {
            strategy.warnings.append("Extreme cumulative scaling: \(strategy.cumulativeScale)")
        }
        
        return strategy
    }
    
    // MARK: - Private Methods
    
    private func analyzeSignalRange(_ signal: [Q15]) -> RangeStatus {
        guard !signal.isEmpty else { return .optimal(currentRange: 0) }
        
        // Find min/max manually for Q15 data
        var maxVal: Q15 = signal.first ?? 0
        var minVal: Q15 = signal.first ?? 0
        
        for value in signal {
            if value > maxVal {
                maxVal = value
            }
            if value < minVal {
                minVal = value
            }
        }
        
        let peakValue = Float(max(abs(maxVal), abs(minVal))) / Float(FixedPointMath.Q15_SCALE)
        
        if peakValue > 0.9 {
            return .overflowRisk(scale: peakValue)
        } else if peakValue < 0.1 {
            return .underflowRisk(scale: peakValue)
        } else if peakValue > 0.7 {
            return .nearLimit(currentRange: peakValue)
        } else {
            return .optimal(currentRange: peakValue)
        }
    }
    
    private func calculateOptimalScale(_ rangeStatus: RangeStatus, stage: String) -> Float {
        // Base scale from range status
        var scale = rangeStatus.recommendedScale
        
        // Apply stage-specific adjustments
        switch stage {
        case "phase_space":
            // Phase space reconstruction needs headroom for embedding
            scale *= 0.8
        case "distance":
            // Distance calculations can amplify values
            scale *= 0.7
        case "lyapunov":
            // Lyapunov needs precision for small differences
            scale = max(scale, 0.5)  // Don't over-compress
        default:
            break
        }
        
        // Apply adaptive learning
        if let previousScale = stageScales[stage] {
            // Smooth adaptation to avoid oscillations
            scale = previousScale * (1 - adaptationRate) + scale * adaptationRate
        }
        
        // Clamp to safe range
        return max(minScale, min(maxScale, scale))
    }
    
    private func applyScaling(_ signal: [Q15], scale: Float) -> [Q15] {
        guard scale != 1.0 else { return signal }
        
        var scaledSignal = [Q15](repeating: 0, count: signal.count)
        
        signal.withUnsafeBufferPointer { inputPtr in
            scaledSignal.withUnsafeMutableBufferPointer { outputPtr in
                // Convert to float for scaling
                var floatSignal = [Float](repeating: 0, count: signal.count)
                vDSP_vflt16(inputPtr.baseAddress!, 1, &floatSignal, 1, vDSP_Length(signal.count))
                
                // Apply scale
                var scaleCopy = scale
                vDSP_vsmul(floatSignal, 1, &scaleCopy, &floatSignal, 1, vDSP_Length(signal.count))
                
                // Convert back with saturation
                for i in 0..<signal.count {
                    let scaled = floatSignal[i]
                    if scaled > Float(Int16.max) {
                        outputPtr[i] = Int16.max
                    } else if scaled < Float(Int16.min) {
                        outputPtr[i] = Int16.min
                    } else {
                        outputPtr[i] = Int16(scaled)
                    }
                }
            }
        }
        
        return scaledSignal
    }
    
    private func reverseScaleWithCompensation(_ signal: [Q15], record: ScalingRecord) -> [Q15] {
        let inverseScale = 1.0 / record.scaleFactor
        var reversed = applyScaling(signal, scale: inverseScale)
        
        // Apply error compensation
        if record.errorEstimate > errorThreshold {
            reversed = applyErrorCompensation(reversed, error: record.errorEstimate)
        }
        
        return reversed
    }
    
    private func applyErrorCompensation(_ signal: [Q15], error: Float) -> [Q15] {
        // Simple additive compensation
        let compensation = Q15(error * Float(FixedPointMath.Q15_SCALE))
        return signal.map { sample in
            let compensated = Int32(sample) + Int32(compensation)
            return Q15(max(Int32(Q15.min), min(Int32(Q15.max), compensated)))
        }
    }
    
    private func estimateScalingError(_ scale: Float) -> Float {
        // Error increases with extreme scaling
        if scale < 0.1 || scale > 10.0 {
            return abs(1.0 - scale) * 0.001
        }
        return 0.0
    }
    
    private func recordScaling(_ record: ScalingRecord) {
        scalingHistory.append(record)
        if scalingHistory.count > historySize {
            scalingHistory.removeFirst()
        }
        
        // Update error accumulator
        errorAccumulator += record.errorEstimate
    }
    
    private func findScalingRecord(for info: ScalingInfo) -> ScalingRecord? {
        return scalingHistory.last { $0.stage == info.stage }
    }
    
    private func simpleReverseScale(_ signal: [Q15], scale: Float) -> [Q15] {
        return applyScaling(signal, scale: 1.0 / scale)
    }
    
    private func analyzeBatchRange(_ batch: [[Q15]]) -> RangeStatus {
        var globalMax: Float = 0
        
        for signal in batch {
            let status = analyzeSignalRange(signal)
            switch status {
            case .overflowRisk(let scale):
                globalMax = max(globalMax, scale)
            case .nearLimit(let range):
                globalMax = max(globalMax, range)
            case .underflowRisk(let scale):
                globalMax = max(globalMax, scale)
            case .optimal(let range):
                globalMax = max(globalMax, range)
            }
        }
        
        if globalMax > 0.9 {
            return .overflowRisk(scale: globalMax)
        } else if globalMax > 0.7 {
            return .nearLimit(currentRange: globalMax)
        } else {
            return .optimal(currentRange: globalMax)
        }
    }
    
    private func recommendScaleForStage(_ stage: String, previousScale: Float) -> Float {
        // Stage-specific heuristics
        let baseRecommendation: Float
        
        switch stage {
        case "phase_space":
            baseRecommendation = 0.8
        case "distance":
            baseRecommendation = 0.6
        case "lyapunov":
            baseRecommendation = 0.9
        case "dfa":
            baseRecommendation = 0.7
        default:
            baseRecommendation = 1.0
        }
        
        // Consider cumulative effect
        let cumulative = previousScale * baseRecommendation
        
        // Prevent extreme cumulative scaling
        if cumulative < 0.1 {
            return baseRecommendation / previousScale * 0.1
        } else if cumulative > 10.0 {
            return baseRecommendation / previousScale * 10.0
        }
        
        return baseRecommendation
    }
}

// MARK: - Supporting Types

/// Scaling information for reverse operations
public struct ScalingInfo {
    public let scaleFactor: Float
    public let stage: String
}

/// Scaling record for history tracking
private struct ScalingRecord {
    let timestamp: Date
    let stage: String
    let scaleFactor: Float
    let inputRange: RangeStatus
    let errorEstimate: Float
}

/// Multi-stage scaling strategy
public struct ScalingStrategy {
    public var stageScales: [String: Float] = [:]
    public var cumulativeScale: Float = 1.0
    public var warnings: [String] = []
}

// MARK: - Integration Extensions

extension AdaptiveScalingEngine {
    
    /// Create engine optimized for specific nonlinear dynamics calculation
    public static func engineForNLD(type: NLDType) -> AdaptiveScalingEngine {
        let engine = AdaptiveScalingEngine()
        
        switch type {
        case .lyapunovExponent:
            engine.adaptationRate = 0.05  // Slower adaptation for stability
        case .dfa:
            engine.adaptationRate = 0.15  // Faster adaptation for varying scales
        case .correlationDimension:
            engine.adaptationRate = 0.1
        }
        
        return engine
    }
}

public enum NLDType {
    case lyapunovExponent
    case dfa
    case correlationDimension
}