//
//  ComprehensiveNonlinearDynamics.swift
//  MobileNLD-FL
//
//  Nonlinear Dynamics with Comprehensive Dynamic Adjustment System
//  Integrates dynamic monitoring, adaptive scaling, and cross-stage coordination
//

import Foundation
import Accelerate

/// Enhanced nonlinear dynamics with comprehensive dynamic adjustment
public class ComprehensiveNonlinearDynamics {
    
    // MARK: - Properties
    
    /// Dynamic adjustment components
    private let rangeMonitor: DynamicRangeMonitor
    private let scalingEngine: AdaptiveScalingEngine
    private let coordinator: CrossStageCoordinator
    
    /// Performance constraints
    private let targetProcessingTime: Double = 0.004  // 4ms target
    private var qualityMode: QualityMode = .balanced
    
    /// Metrics tracking
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Initialization
    
    public init(signalType: SignalType = .general) {
        self.rangeMonitor = DynamicRangeMonitor.optimalMonitor(for: signalType)
        self.scalingEngine = AdaptiveScalingEngine.engineForNLD(type: .lyapunovExponent)
        self.coordinator = CrossStageCoordinator()
    }
    
    // MARK: - Public Interface
    
    /// Calculate Lyapunov exponent with comprehensive dynamic adjustment
    public func lyapunovExponent(
        _ timeSeries: [Q15],
        embeddingDim: Int = 5,
        delay: Int = 4,
        samplingRate: Int = 50
    ) -> (value: Float, metrics: CalculationMetrics) {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Define processing stages for Lyapunov
        let stages: [ProcessingStage] = [
            .phaseSpaceReconstruction,
            .distanceCalculation,
            .indexCalculation
        ]
        
        // Process through coordinated pipeline
        let result = coordinator.processSignal(timeSeries, through: stages)
        
        // Extract and compute Lyapunov exponent
        let lyapunovValue = computeLyapunovFromPipeline(
            result,
            embeddingDim: embeddingDim,
            delay: delay,
            samplingRate: samplingRate
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Create metrics
        let metrics = CalculationMetrics(
            processingTime: processingTime,
            cumulativeScale: result.cumulativeScale,
            qualityScore: assessQuality(result),
            stageBreakdown: result.stageResults.mapValues { $0.qualityMetric }
        )
        
        // Update performance tracking
        updatePerformanceMetrics(processingTime: processingTime, quality: metrics.qualityScore)
        
        return (lyapunovValue, metrics)
    }
    
    /// Calculate DFA alpha with comprehensive dynamic adjustment
    public func dfaAlpha(
        _ timeSeries: [Q15],
        minBoxSize: Int = 4,
        maxBoxSize: Int = 64
    ) -> (value: Float, metrics: CalculationMetrics) {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // DFA uses different stages
        let stages: [ProcessingStage] = [
            .phaseSpaceReconstruction,  // For cumulative sum
            .aggregation                 // For fluctuation analysis
        ]
        
        // Optimize for DFA
        _ = coordinator.optimizeForAlgorithm(.dfa)
        
        // Process through pipeline
        let result = coordinator.processSignal(timeSeries, through: stages)
        
        // Compute DFA
        let dfaValue = computeDFAFromPipeline(
            result,
            minBoxSize: minBoxSize,
            maxBoxSize: maxBoxSize
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        let metrics = CalculationMetrics(
            processingTime: processingTime,
            cumulativeScale: result.cumulativeScale,
            qualityScore: assessQuality(result),
            stageBreakdown: result.stageResults.mapValues { $0.qualityMetric }
        )
        
        return (dfaValue, metrics)
    }
    
    /// Set quality mode for time/accuracy tradeoff
    public func setQualityMode(_ mode: QualityMode) {
        self.qualityMode = mode
        
        // Adjust coordinator settings based on mode
        switch mode {
        case .highSpeed:
            // Prioritize speed over accuracy
            coordinator.globalOptimizationEnabled = false
        case .balanced:
            // Default balanced approach
            coordinator.globalOptimizationEnabled = true
        case .highAccuracy:
            // Maximum accuracy, may exceed 4ms
            coordinator.globalOptimizationEnabled = true
        }
    }
    
    /// Get current system status
    public func getSystemStatus() -> SystemStatus {
        let coordinationStatus = coordinator.getCoordinationStatus()
        
        return SystemStatus(
            performanceMetrics: performanceMetrics,
            coordinationStatus: coordinationStatus,
            currentQualityMode: qualityMode,
            averageProcessingTime: performanceMetrics.averageTime,
            successRate: performanceMetrics.successRate
        )
    }
    
    // MARK: - Private Implementation
    
    private func computeLyapunovFromPipeline(
        _ result: ProcessingResult,
        embeddingDim: Int,
        delay: Int,
        samplingRate: Int
    ) -> Float {
        
        // Get the processed signal
        let processedSignal = result.finalOutput
        
        // Phase space reconstruction with dynamic adjustment
        guard let phaseSpaceResult = result.stageResults[.phaseSpaceReconstruction] else {
            return 0.0
        }
        
        let embeddings = reconstructPhaseSpace(
            phaseSpaceResult.output,
            dimension: embeddingDim,
            delay: delay
        )
        
        guard embeddings.count > 10 else { return 0.0 }
        
        // Distance calculations with scaling
        guard let distanceResult = result.stageResults[.distanceCalculation] else {
            return 0.0
        }
        
        // Find nearest neighbors and track divergence
        var divergences: [Float] = []
        let maxSteps = min(50, processedSignal.count / 10)
        
        for i in 0..<min(embeddings.count - maxSteps, 100) {  // Limit iterations for speed
            if let nearestIndex = findNearestNeighborAdaptive(
                embeddings,
                targetIndex: i,
                minSeparation: 10,
                scale: distanceResult.appliedScale
            ) {
                // Track divergence evolution
                var logDivergences: [Float] = []
                
                for step in 1...maxSteps {
                    let currentIndex = i + step
                    let neighborIndex = nearestIndex + step
                    
                    guard currentIndex < embeddings.count && neighborIndex < embeddings.count else { break }
                    
                    let distance = computeScaledDistance(
                        embeddings[currentIndex],
                        embeddings[neighborIndex],
                        scale: distanceResult.appliedScale
                    )
                    
                    if distance > 0 {
                        logDivergences.append(log(distance))
                    }
                }
                
                if logDivergences.count >= 10 {
                    divergences.append(contentsOf: logDivergences)
                }
            }
        }
        
        guard !divergences.isEmpty else { return 0.0 }
        
        // Linear regression for Lyapunov exponent
        let timeStep = 1.0 / Float(samplingRate)
        return calculateSlope(divergences, timeStep: timeStep)
    }
    
    private func computeDFAFromPipeline(
        _ result: ProcessingResult,
        minBoxSize: Int,
        maxBoxSize: Int
    ) -> Float {
        
        guard let phaseSpaceResult = result.stageResults[.phaseSpaceReconstruction] else {
            return 0.0
        }
        
        // Convert to cumulative sum with scaling awareness
        let scaledSignal = phaseSpaceResult.output
        let cumulativeSum = computeAdaptiveCumulativeSum(scaledSignal, scale: phaseSpaceResult.appliedScale)
        
        var boxSizes: [Int] = []
        var fluctuations: [Float] = []
        
        // Logarithmically spaced box sizes
        var boxSize = minBoxSize
        while boxSize <= maxBoxSize && boxSize < cumulativeSum.count / 4 {
            boxSizes.append(boxSize)
            
            let fluctuation = calculateAdaptiveFluctuation(
                cumulativeSum,
                boxSize: boxSize,
                scale: result.cumulativeScale
            )
            fluctuations.append(fluctuation)
            
            boxSize = Int(Float(boxSize) * 1.2)
        }
        
        guard boxSizes.count >= 3 else { return 0.0 }
        
        // Linear regression in log-log space
        let logBoxSizes = boxSizes.map { log(Float($0)) }
        let logFluctuations = fluctuations.map { log(max($0, 1e-10)) }
        
        return calculateSlope(logFluctuations, logBoxSizes)
    }
    
    // MARK: - Adaptive Helper Methods
    
    private func reconstructPhaseSpace(
        _ timeSeries: [Q15],
        dimension: Int,
        delay: Int
    ) -> [[Q15]] {
        let numPoints = timeSeries.count - (dimension - 1) * delay
        guard numPoints > 0 else { return [] }
        
        var embeddings: [[Q15]] = []
        embeddings.reserveCapacity(numPoints)
        
        for i in 0..<numPoints {
            var embedding: [Q15] = []
            embedding.reserveCapacity(dimension)
            
            for j in 0..<dimension {
                let index = i + j * delay
                embedding.append(timeSeries[index])
            }
            embeddings.append(embedding)
        }
        
        return embeddings
    }
    
    private func findNearestNeighborAdaptive(
        _ embeddings: [[Q15]],
        targetIndex: Int,
        minSeparation: Int,
        scale: Float
    ) -> Int? {
        
        guard targetIndex < embeddings.count else { return nil }
        
        let target = embeddings[targetIndex]
        var minDistance = Float.infinity
        var nearestIndex: Int?
        
        // Adaptive search range based on quality mode
        let searchRange: Int
        switch qualityMode {
        case .highSpeed:
            searchRange = min(embeddings.count, 200)
        case .balanced:
            searchRange = min(embeddings.count, 500)
        case .highAccuracy:
            searchRange = embeddings.count
        }
        
        let step = max(1, embeddings.count / searchRange)
        
        for i in stride(from: 0, to: embeddings.count, by: step) {
            guard abs(i - targetIndex) >= minSeparation else { continue }
            
            let distance = computeScaledDistance(target, embeddings[i], scale: scale)
            
            if distance < minDistance {
                minDistance = distance
                nearestIndex = i
            }
        }
        
        return nearestIndex
    }
    
    private func computeScaledDistance(_ a: [Q15], _ b: [Q15], scale: Float) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        // Use SIMD-optimized distance with scale awareness
        return a.withUnsafeBufferPointer { aPtr in
            b.withUnsafeBufferPointer { bPtr in
                let rawDistance = SIMDOptimizations.euclideanDistanceSIMD(
                    aPtr.baseAddress!,
                    bPtr.baseAddress!,
                    dimension: a.count
                )
                // Adjust for scaling
                return rawDistance / scale
            }
        }
    }
    
    private func computeAdaptiveCumulativeSum(_ signal: [Q15], scale: Float) -> [Float] {
        var cumSum = [Float](repeating: 0, count: signal.count)
        
        signal.withUnsafeBufferPointer { signalPtr in
            cumSum.withUnsafeMutableBufferPointer { cumSumPtr in
                // Convert to float with scale adjustment
                var floatSignal = [Float](repeating: 0, count: signal.count)
                vDSP_vflt16(signalPtr.baseAddress!, 1, &floatSignal, 1, vDSP_Length(signal.count))
                
                // Apply inverse scaling for accurate cumulative sum
                var invScale = 1.0 / (Float(FixedPointMath.Q15_SCALE) * scale)
                vDSP_vsmul(floatSignal, 1, &invScale, &floatSignal, 1, vDSP_Length(signal.count))
                
                // Compute mean
                var mean: Float = 0
                vDSP_meanv(floatSignal, 1, &mean, vDSP_Length(signal.count))
                
                // Subtract mean
                var negMean = -mean
                vDSP_vsadd(floatSignal, 1, &negMean, &floatSignal, 1, vDSP_Length(signal.count))
                
                // Cumulative sum
                var one: Float = 1.0
                vDSP_vrsum(floatSignal, 1, &one, cumSumPtr.baseAddress!, 1, vDSP_Length(signal.count))
            }
        }
        
        return cumSum
    }
    
    private func calculateAdaptiveFluctuation(_ cumulativeSum: [Float], boxSize: Int, scale: Float) -> Float {
        let numBoxes = cumulativeSum.count / boxSize
        guard numBoxes > 0 else { return 0 }
        
        var totalFluctuation: Float = 0
        
        for i in 0..<numBoxes {
            let startIndex = i * boxSize
            let endIndex = min(startIndex + boxSize, cumulativeSum.count)
            
            let boxData = Array(cumulativeSum[startIndex..<endIndex])
            
            // Use SIMD-optimized linear regression
            let x = Array(0..<boxData.count).map { Float($0) }
            let (slope, intercept) = SIMDOptimizations.linearRegressionSIMD(x: x, y: boxData)
            
            // Calculate RMS of residuals
            var rms: Float = 0
            for j in 0..<boxData.count {
                let fitted = slope * Float(j) + intercept
                let residual = boxData[j] - fitted
                rms += residual * residual
            }
            rms = sqrt(rms / Float(boxData.count))
            
            totalFluctuation += rms * rms * Float(boxSize)
        }
        
        // Adjust for cumulative scaling
        return sqrt(totalFluctuation / Float(numBoxes * boxSize)) * scale
    }
    
    private func calculateSlope(_ yValues: [Float], _ xValues: [Float]) -> Float {
        guard yValues.count == xValues.count && yValues.count > 1 else { return 0.0 }
        
        let (slope, _) = SIMDOptimizations.linearRegressionSIMD(x: xValues, y: yValues)
        return slope
    }
    
    private func calculateSlope(_ values: [Float], timeStep: Float) -> Float {
        guard values.count > 1 else { return 0.0 }
        
        let xValues = (0..<values.count).map { Float($0) * timeStep }
        return calculateSlope(values, xValues)
    }
    
    private func assessQuality(_ result: ProcessingResult) -> Float {
        // Average quality across all stages
        let qualities = result.stageResults.values.map { $0.qualityMetric }
        guard !qualities.isEmpty else { return 0 }
        
        return qualities.reduce(0, +) / Float(qualities.count)
    }
    
    private func updatePerformanceMetrics(processingTime: Double, quality: Float) {
        performanceMetrics.totalProcessingTime += processingTime
        performanceMetrics.processedSamples += 1
        
        if processingTime <= targetProcessingTime {
            performanceMetrics.successfulProcessing += 1
        }
        
        performanceMetrics.averageQuality = 
            (performanceMetrics.averageQuality * Float(performanceMetrics.processedSamples - 1) + quality) / 
            Float(performanceMetrics.processedSamples)
    }
}

// MARK: - Supporting Types

public enum QualityMode {
    case highSpeed      // Prioritize speed, may sacrifice accuracy
    case balanced       // Balance speed and accuracy
    case highAccuracy   // Maximum accuracy, may exceed 4ms
}

public struct CalculationMetrics {
    public let processingTime: Double
    public let cumulativeScale: Float
    public let qualityScore: Float
    public let stageBreakdown: [ProcessingStage: Float]
}

public struct SystemStatus {
    public let performanceMetrics: PerformanceMetrics
    public let coordinationStatus: CoordinationStatus
    public let currentQualityMode: QualityMode
    public let averageProcessingTime: Double
    public let successRate: Float
}

public struct PerformanceMetrics {
    var totalProcessingTime: Double = 0
    var processedSamples: Int = 0
    var successfulProcessing: Int = 0
    var averageQuality: Float = 0
    
    var averageTime: Double {
        guard processedSamples > 0 else { return 0 }
        return totalProcessingTime / Double(processedSamples)
    }
    
    var successRate: Float {
        guard processedSamples > 0 else { return 0 }
        return Float(successfulProcessing) / Float(processedSamples)
    }
}

// MARK: - Factory Methods

extension ComprehensiveNonlinearDynamics {
    
    /// Create instance optimized for ECG analysis
    public static func forECG() -> ComprehensiveNonlinearDynamics {
        let nld = ComprehensiveNonlinearDynamics(signalType: .ecg)
        nld.setQualityMode(.balanced)
        return nld
    }
    
    /// Create instance optimized for EEG analysis
    public static func forEEG() -> ComprehensiveNonlinearDynamics {
        let nld = ComprehensiveNonlinearDynamics(signalType: .eeg)
        nld.setQualityMode(.highAccuracy)
        return nld
    }
    
    /// Create instance optimized for real-time processing
    public static func forRealtime() -> ComprehensiveNonlinearDynamics {
        let nld = ComprehensiveNonlinearDynamics(signalType: .general)
        nld.setQualityMode(.highSpeed)
        return nld
    }
}