//
//  CrossStageCoordinator.swift
//  MobileNLD-FL
//
//  Cross-stage Coordination Mechanism for Comprehensive Dynamic Adjustment System
//  Coordinates scaling decisions across phase space, distance, and index calculations
//

import Foundation
import Accelerate

/// Cross-stage coordinator for multi-stage nonlinear dynamics processing
public class CrossStageCoordinator {
    
    // MARK: - Properties
    
    /// Stage processors
    private let rangeMonitor: DynamicRangeMonitor
    private let scalingEngine: AdaptiveScalingEngine
    
    /// Stage configuration
    private var stageConfig: [ProcessingStage: StageConfiguration] = [:]
    
    /// Coordination state
    private var stageHistory: [StageTransition] = []
    private var globalOptimizationEnabled = true
    
    /// Performance metrics
    private var stageMetrics: [ProcessingStage: StageMetrics] = [:]
    
    // MARK: - Initialization
    
    public init() {
        self.rangeMonitor = DynamicRangeMonitor(windowSize: 256)
        self.scalingEngine = AdaptiveScalingEngine()
        
        // Initialize default stage configurations
        setupDefaultConfigurations()
    }
    
    // MARK: - Public Interface
    
    /// Process signal through coordinated pipeline
    public func processSignal(_ signal: [Q15], through stages: [ProcessingStage]) -> ProcessingResult {
        var currentSignal = signal
        var stageResults: [ProcessingStage: StageResult] = [:]
        var cumulativeScale: Float = 1.0
        
        // Pre-analysis for global optimization
        let globalAnalysis = performGlobalAnalysis(signal, stages: stages)
        
        // Process through each stage with coordination
        for (index, stage) in stages.enumerated() {
            let stageStartTime = CFAbsoluteTimeGetCurrent()
            
            // Get optimal configuration for this stage
            let config = getOptimalConfiguration(
                for: stage,
                previousStage: index > 0 ? stages[index-1] : nil,
                globalAnalysis: globalAnalysis
            )
            
            // Apply stage-specific processing
            let stageResult = processStage(
                signal: currentSignal,
                stage: stage,
                config: config
            )
            
            // Record metrics
            let processingTime = CFAbsoluteTimeGetCurrent() - stageStartTime
            updateMetrics(for: stage, time: processingTime, result: stageResult)
            
            // Store results
            stageResults[stage] = stageResult
            currentSignal = stageResult.output
            cumulativeScale *= stageResult.appliedScale
            
            // Record transition
            recordTransition(from: index > 0 ? stages[index-1] : nil, to: stage, result: stageResult)
        }
        
        return ProcessingResult(
            finalOutput: currentSignal,
            stageResults: stageResults,
            cumulativeScale: cumulativeScale,
            processingChain: stages
        )
    }
    
    /// Optimize configuration for specific nonlinear dynamics algorithm
    public func optimizeForAlgorithm(_ algorithm: NLDAlgorithm) -> AlgorithmOptimization {
        let stages = algorithm.requiredStages
        var optimization = AlgorithmOptimization(algorithm: algorithm)
        
        // Analyze algorithm-specific requirements
        switch algorithm {
        case .lyapunovExponent:
            optimization.recommendedConfig = optimizeForLyapunov()
        case .dfa:
            optimization.recommendedConfig = optimizeForDFA()
        case .correlationDimension:
            optimization.recommendedConfig = optimizeForCorrelationDimension()
        }
        
        // Validate configuration feasibility
        optimization.feasibilityScore = validateConfiguration(optimization.recommendedConfig)
        
        return optimization
    }
    
    /// Get real-time coordination status
    public func getCoordinationStatus() -> CoordinationStatus {
        return CoordinationStatus(
            activeStages: stageConfig.keys.sorted { $0.rawValue < $1.rawValue },
            currentLoad: calculateSystemLoad(),
            scalingHealth: assessScalingHealth(),
            recommendations: generateRecommendations()
        )
    }
    
    // MARK: - Stage Processing
    
    private func processStage(signal: [Q15], stage: ProcessingStage, config: StageConfiguration) -> StageResult {
        // Monitor input signal
        let rangeStatus = rangeMonitor.monitorBatch(signal)
        
        // Apply scaling based on configuration
        let (scaledSignal, scaleInfo) = scalingEngine.scaleSignal(signal, stage: stage.rawValue)
        
        // Stage-specific processing
        let processedSignal: [Q15]
        
        switch stage {
        case .phaseSpaceReconstruction:
            processedSignal = processPhaseSpace(scaledSignal, config: config)
        case .distanceCalculation:
            processedSignal = processDistanceCalc(scaledSignal, config: config)
        case .indexCalculation:
            processedSignal = processIndexCalc(scaledSignal, config: config)
        case .aggregation:
            processedSignal = processAggregation(scaledSignal, config: config)
        }
        
        // Reverse scaling if needed
        let finalSignal = config.preserveScale ? processedSignal : scalingEngine.reverseScale(processedSignal, scaleInfo: scaleInfo)
        
        return StageResult(
            output: finalSignal,
            appliedScale: scaleInfo.scaleFactor,
            rangeUtilization: calculateRangeUtilization(processedSignal),
            qualityMetric: assessQuality(processedSignal, original: signal)
        )
    }
    
    // MARK: - Stage-Specific Processing
    
    private func processPhaseSpace(_ signal: [Q15], config: StageConfiguration) -> [Q15] {
        // Placeholder for actual phase space reconstruction
        // In real implementation, this would reshape the signal
        return signal
    }
    
    private func processDistanceCalc(_ signal: [Q15], config: StageConfiguration) -> [Q15] {
        // Placeholder for distance calculations
        // Would typically compute pairwise distances
        return signal
    }
    
    private func processIndexCalc(_ signal: [Q15], config: StageConfiguration) -> [Q15] {
        // Placeholder for index calculations (Lyapunov, etc.)
        return signal
    }
    
    private func processAggregation(_ signal: [Q15], config: StageConfiguration) -> [Q15] {
        // Placeholder for final aggregation
        return signal
    }
    
    // MARK: - Optimization Methods
    
    private func performGlobalAnalysis(_ signal: [Q15], stages: [ProcessingStage]) -> GlobalAnalysis {
        // Analyze signal characteristics
        let stats = rangeMonitor.getStatistics()
        
        // Predict processing requirements
        let predictedLoads = stages.map { stage in
            predictProcessingLoad(for: stage, signalSize: signal.count)
        }
        
        // Identify bottlenecks
        let bottleneckIndex = predictedLoads.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        
        return GlobalAnalysis(
            signalCharacteristics: stats,
            predictedLoads: predictedLoads,
            bottleneckStage: stages[safe: bottleneckIndex],
            recommendedStrategy: determineStrategy(stats: stats, stages: stages)
        )
    }
    
    private func getOptimalConfiguration(
        for stage: ProcessingStage,
        previousStage: ProcessingStage?,
        globalAnalysis: GlobalAnalysis
    ) -> StageConfiguration {
        
        var config = stageConfig[stage] ?? StageConfiguration()
        
        // Adjust based on previous stage output
        if let previous = previousStage,
           let prevMetrics = stageMetrics[previous] {
            config.inputScaleHint = prevMetrics.outputScale
        }
        
        // Apply global optimization insights
        if stage == globalAnalysis.bottleneckStage {
            config.aggressiveOptimization = true
            config.qualityTarget = 0.8  // Reduce quality target for bottleneck
        }
        
        // Stage-specific adjustments
        switch stage {
        case .phaseSpaceReconstruction:
            config.scalingStrategy = .conservative  // Preserve signal structure
        case .distanceCalculation:
            config.scalingStrategy = .aggressive    // Prevent overflow in squares
        case .indexCalculation:
            config.scalingStrategy = .adaptive      // Balance precision and range
        case .aggregation:
            config.scalingStrategy = .minimal       // Final stage needs less scaling
        }
        
        return config
    }
    
    private func optimizeForLyapunov() -> [ProcessingStage: StageConfiguration] {
        var configs: [ProcessingStage: StageConfiguration] = [:]
        
        // Phase space: Conservative to preserve trajectory
        configs[.phaseSpaceReconstruction] = StageConfiguration(
            scalingStrategy: .conservative,
            qualityTarget: 0.95,
            preserveScale: false
        )
        
        // Distance: Aggressive to handle squared differences
        configs[.distanceCalculation] = StageConfiguration(
            scalingStrategy: .aggressive,
            qualityTarget: 0.9,
            maxScale: 0.5  // Prevent overflow
        )
        
        // Index calculation: High precision needed
        configs[.indexCalculation] = StageConfiguration(
            scalingStrategy: .adaptive,
            qualityTarget: 0.98,
            errorTolerance: 1e-6
        )
        
        return configs
    }
    
    private func optimizeForDFA() -> [ProcessingStage: StageConfiguration] {
        var configs: [ProcessingStage: StageConfiguration] = [:]
        
        // DFA needs different optimization
        configs[.phaseSpaceReconstruction] = StageConfiguration(
            scalingStrategy: .adaptive,
            qualityTarget: 0.9
        )
        
        configs[.aggregation] = StageConfiguration(
            scalingStrategy: .minimal,
            qualityTarget: 0.95,
            preserveScale: true  // Keep scale for detrending
        )
        
        return configs
    }
    
    private func optimizeForCorrelationDimension() -> [ProcessingStage: StageConfiguration] {
        // Similar pattern with different parameters
        return optimizeForLyapunov()  // Simplified for now
    }
    
    // MARK: - Metrics and Monitoring
    
    private func updateMetrics(for stage: ProcessingStage, time: Double, result: StageResult) {
        var metrics = stageMetrics[stage] ?? StageMetrics()
        
        metrics.processingTime = time
        metrics.outputScale = result.appliedScale
        metrics.rangeUtilization = result.rangeUtilization
        metrics.qualityScore = result.qualityMetric
        
        stageMetrics[stage] = metrics
    }
    
    private func recordTransition(from: ProcessingStage?, to: ProcessingStage, result: StageResult) {
        let transition = StageTransition(
            fromStage: from,
            toStage: to,
            timestamp: Date(),
            scaleChange: result.appliedScale,
            qualityImpact: result.qualityMetric
        )
        
        stageHistory.append(transition)
        
        // Keep history bounded
        if stageHistory.count > 1000 {
            stageHistory.removeFirst()
        }
    }
    
    private func calculateRangeUtilization(_ signal: [Q15]) -> Float {
        guard !signal.isEmpty else { return 0 }
        
        var maxVal: Q15 = 0
        signal.withUnsafeBufferPointer { ptr in
            vDSP_maxmgvi(ptr.baseAddress!, 1, &maxVal, nil, vDSP_Length(signal.count))
        }
        
        return Float(maxVal) / Float(FixedPointMath.Q15_MAX)
    }
    
    private func assessQuality(_ processed: [Q15], original: [Q15]) -> Float {
        // Simple SNR-based quality metric
        guard processed.count == original.count else { return 0 }
        
        var mse: Float = 0
        processed.withUnsafeBufferPointer { procPtr in
            original.withUnsafeBufferPointer { origPtr in
                var diff = [Float](repeating: 0, count: processed.count)
                var procFloat = [Float](repeating: 0, count: processed.count)
                var origFloat = [Float](repeating: 0, count: original.count)
                
                // Convert to float
                vDSP_vflt16(procPtr.baseAddress!, 1, &procFloat, 1, vDSP_Length(processed.count))
                vDSP_vflt16(origPtr.baseAddress!, 1, &origFloat, 1, vDSP_Length(original.count))
                
                // Calculate difference
                vDSP_vsub(origFloat, 1, procFloat, 1, &diff, 1, vDSP_Length(processed.count))
                
                // Calculate MSE
                vDSP_measqv(diff, 1, &mse, vDSP_Length(diff.count))
            }
        }
        
        // Convert MSE to quality score (0-1)
        return max(0, 1 - sqrt(mse) / Float(FixedPointMath.Q15_SCALE))
    }
    
    // MARK: - Helper Methods
    
    private func setupDefaultConfigurations() {
        stageConfig[.phaseSpaceReconstruction] = StageConfiguration(
            scalingStrategy: .adaptive,
            qualityTarget: 0.95
        )
        
        stageConfig[.distanceCalculation] = StageConfiguration(
            scalingStrategy: .aggressive,
            qualityTarget: 0.9
        )
        
        stageConfig[.indexCalculation] = StageConfiguration(
            scalingStrategy: .conservative,
            qualityTarget: 0.98
        )
        
        stageConfig[.aggregation] = StageConfiguration(
            scalingStrategy: .minimal,
            qualityTarget: 0.95
        )
    }
    
    private func predictProcessingLoad(for stage: ProcessingStage, signalSize: Int) -> Float {
        // Simple heuristic based on stage complexity
        let baseLoad: Float
        
        switch stage {
        case .phaseSpaceReconstruction:
            baseLoad = 1.0
        case .distanceCalculation:
            baseLoad = Float(signalSize) / 100  // O(n²) complexity
        case .indexCalculation:
            baseLoad = 2.0
        case .aggregation:
            baseLoad = 0.5
        }
        
        return baseLoad * Float(signalSize) / 1000
    }
    
    private func determineStrategy(stats: SignalStatistics, stages: [ProcessingStage]) -> ScalingStrategy {
        if stats.dynamicRange > 100 {
            return ScalingStrategy(
                stageScales: Dictionary(uniqueKeysWithValues: stages.map { ($0.rawValue, 0.1) }),
                cumulativeScale: 0.01,
                warnings: ["High dynamic range detected"]
            )
        }
        
        return scalingEngine.getScalingStrategy(for: stages.map { $0.rawValue })
    }
    
    private func calculateSystemLoad() -> Float {
        let loads = stageMetrics.values.map { $0.processingTime }
        return Float(loads.reduce(0, +))
    }
    
    private func assessScalingHealth() -> ScalingHealth {
        let scales = stageMetrics.values.map { $0.outputScale }
        let cumulative = scales.reduce(1.0, *)
        
        if cumulative < 0.001 || cumulative > 1000 {
            return .poor
        } else if cumulative < 0.01 || cumulative > 100 {
            return .fair
        } else {
            return .good
        }
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Check for extreme scaling
        for (stage, metrics) in stageMetrics {
            if metrics.outputScale < 0.1 {
                recommendations.append("Consider reducing input range for \(stage.rawValue)")
            }
            if metrics.rangeUtilization < 0.3 {
                recommendations.append("Low range utilization in \(stage.rawValue)")
            }
        }
        
        return recommendations
    }
    
    private func validateConfiguration(_ configs: [ProcessingStage: StageConfiguration]) -> Float {
        // Simple validation based on cumulative scaling
        let scales = configs.values.compactMap { config -> Float? in
            switch config.scalingStrategy {
            case .aggressive: return 0.5
            case .conservative: return 0.9
            case .adaptive: return 0.7
            case .minimal: return 1.0
            }
        }
        
        let cumulative = scales.reduce(1.0, *)
        
        if cumulative > 0.01 && cumulative < 100 {
            return 1.0  // Perfect feasibility
        } else {
            return max(0, 1.0 - abs(log10(cumulative)) / 4)
        }
    }
}

// MARK: - Supporting Types

public enum ProcessingStage: String, CaseIterable {
    case phaseSpaceReconstruction = "phase_space"
    case distanceCalculation = "distance"
    case indexCalculation = "index"
    case aggregation = "aggregation"
}

public struct StageConfiguration {
    var scalingStrategy: ScalingStrategy = .adaptive
    var qualityTarget: Float = 0.95
    var maxScale: Float = 10.0
    var minScale: Float = 0.1
    var preserveScale: Bool = false
    var aggressiveOptimization: Bool = false
    var inputScaleHint: Float = 1.0
    var errorTolerance: Float = 1e-5
    
    enum ScalingStrategy {
        case aggressive
        case conservative
        case adaptive
        case minimal
    }
}

public struct StageResult {
    let output: [Q15]
    let appliedScale: Float
    let rangeUtilization: Float
    let qualityMetric: Float
}

public struct ProcessingResult {
    let finalOutput: [Q15]
    let stageResults: [ProcessingStage: StageResult]
    let cumulativeScale: Float
    let processingChain: [ProcessingStage]
}

private struct StageMetrics {
    var processingTime: Double = 0
    var outputScale: Float = 1.0
    var rangeUtilization: Float = 0
    var qualityScore: Float = 0
}

private struct StageTransition {
    let fromStage: ProcessingStage?
    let toStage: ProcessingStage
    let timestamp: Date
    let scaleChange: Float
    let qualityImpact: Float
}

private struct GlobalAnalysis {
    let signalCharacteristics: SignalStatistics
    let predictedLoads: [Float]
    let bottleneckStage: ProcessingStage?
    let recommendedStrategy: ScalingStrategy
}

public struct CoordinationStatus {
    let activeStages: [ProcessingStage]
    let currentLoad: Float
    let scalingHealth: ScalingHealth
    let recommendations: [String]
}

public enum ScalingHealth {
    case good
    case fair
    case poor
}

public enum NLDAlgorithm {
    case lyapunovExponent
    case dfa
    case correlationDimension
    
    var requiredStages: [ProcessingStage] {
        switch self {
        case .lyapunovExponent:
            return [.phaseSpaceReconstruction, .distanceCalculation, .indexCalculation]
        case .dfa:
            return [.phaseSpaceReconstruction, .aggregation]
        case .correlationDimension:
            return [.phaseSpaceReconstruction, .distanceCalculation, .aggregation]
        }
    }
}

public struct AlgorithmOptimization {
    let algorithm: NLDAlgorithm
    var recommendedConfig: [ProcessingStage: StageConfiguration] = [:]
    var feasibilityScore: Float = 0
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}