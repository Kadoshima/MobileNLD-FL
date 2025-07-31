//
//  NonlinearDynamicsAdaptiveOnly.swift
//  MobileNLD-FL
//
//  動的調整のみ実装版（SIMD最適化なし）
//  実験計画 5.4 SIMD Optimization Effect Evaluation用
//

import Foundation

struct NonlinearDynamicsAdaptiveOnly {
    
    // Adaptive scaling engine instance
    private static let scalingEngine = AdaptiveScalingEngine()
    
    // MARK: - Lyapunov Exponent (Adaptive Only - No SIMD)
    
    /// Calculate Lyapunov exponent using adaptive scaling without SIMD optimization
    static func lyapunovExponentAdaptive(_ timeSeries: [Q15], 
                                        embeddingDim: Int = 5, 
                                        delay: Int = 4, 
                                        samplingRate: Int = 50) -> Float {
        
        guard timeSeries.count >= embeddingDim * delay + 100 else {
            return 0.0 // Insufficient data
        }
        
        // Apply adaptive scaling to input
        let (scaledTimeSeries, scaleInfo) = scalingEngine.scaleSignal(timeSeries, stage: "lyapunov_input")
        
        // Phase space reconstruction with scaled data
        let embeddings = phaseSpaceReconstructionAdaptive(scaledTimeSeries, 
                                                         dimension: embeddingDim, 
                                                         delay: delay)
        
        guard embeddings.count > 10 else { return 0.0 }
        
        // Find nearest neighbors and calculate divergence
        var divergences: [Float] = []
        let maxSteps = min(50, scaledTimeSeries.count / 10)
        
        for i in 0..<embeddings.count - maxSteps {
            if let nearestIndex = findNearestNeighborAdaptive(embeddings, targetIndex: i, minSeparation: 10) {
                
                // Track divergence evolution
                var logDivergences: [Float] = []
                
                for step in 1...maxSteps {
                    let currentIndex = i + step
                    let neighborIndex = nearestIndex + step
                    
                    guard currentIndex < embeddings.count && neighborIndex < embeddings.count else { break }
                    
                    // Calculate distance with scalar operations
                    let distance = euclideanDistanceAdaptive(embeddings[currentIndex], embeddings[neighborIndex])
                    
                    if distance > 0 {
                        // Adjust distance based on scaling factor before log
                        let adjustedDistance = distance * scaleInfo.scaleFactor
                        logDivergences.append(log(adjustedDistance))
                    }
                }
                
                if logDivergences.count >= 10 {
                    divergences.append(contentsOf: logDivergences)
                }
            }
        }
        
        guard !divergences.isEmpty else { return 0.0 }
        
        // Linear regression to find slope
        let timeStep = 1.0 / Float(samplingRate)
        let lyapunovExponent = calculateSlopeAdaptive(divergences, timeStep: timeStep)
        
        return lyapunovExponent
    }
    
    // MARK: - Phase Space Reconstruction (Adaptive)
    
    private static func phaseSpaceReconstructionAdaptive(_ timeSeries: [Q15], 
                                                       dimension: Int, 
                                                       delay: Int) -> [[Q15]] {
        let numPoints = timeSeries.count - (dimension - 1) * delay
        guard numPoints > 0 else { return [] }
        
        var embeddings: [[Q15]] = []
        embeddings.reserveCapacity(numPoints)
        
        // Apply stage-specific scaling for phase space
        let scalingStrategy = scalingEngine.getScalingStrategy(for: ["phase_space"])
        
        for i in 0..<numPoints {
            var embedding: [Q15] = []
            embedding.reserveCapacity(dimension)
            
            // Collect embedding vector
            for j in 0..<dimension {
                let index = i + j * delay
                embedding.append(timeSeries[index])
            }
            
            // Apply adaptive scaling to embedding if recommended
            if let phaseSpaceScale = scalingStrategy.stageScales["phase_space"], phaseSpaceScale != 1.0 {
                let (scaledEmbedding, _) = scalingEngine.scaleSignal(embedding, stage: "phase_space_\(i)")
                embeddings.append(scaledEmbedding)
            } else {
                embeddings.append(embedding)
            }
        }
        
        return embeddings
    }
    
    // MARK: - Nearest Neighbor Search (Adaptive)
    
    private static func findNearestNeighborAdaptive(_ embeddings: [[Q15]], 
                                                   targetIndex: Int, 
                                                   minSeparation: Int) -> Int? {
        guard !embeddings.isEmpty else { return nil }
        
        var minDistance: Float = Float.greatestFiniteMagnitude
        var nearestIndex: Int? = nil
        
        // Apply distance-specific scaling
        let (scaledTarget, targetScaleInfo) = scalingEngine.scaleSignal(embeddings[targetIndex], stage: "distance_target")
        
        // Scalar search with adaptive scaling
        for i in 0..<embeddings.count {
            // Skip temporal neighbors
            if abs(i - targetIndex) < minSeparation { continue }
            
            // Scale comparison point
            let (scaledPoint, _) = scalingEngine.scaleSignal(embeddings[i], stage: "distance_compare_\(i)")
            
            // Calculate distance with scalar operations
            let distance = euclideanDistanceAdaptive(scaledTarget, scaledPoint)
            
            if distance < minDistance {
                minDistance = distance
                nearestIndex = i
            }
        }
        
        return nearestIndex
    }
    
    // MARK: - Distance Calculation (Adaptive)
    
    private static func euclideanDistanceAdaptive(_ a: [Q15], _ b: [Q15]) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        var sum: Int64 = 0
        
        // Pure scalar calculation
        for i in 0..<a.count {
            let diff = Int64(a[i]) - Int64(b[i])
            sum += diff * diff
        }
        
        // Convert back to Float and normalize
        let q15Scale = Float(1 << 15)
        let scaledSum = Float(sum) / (q15Scale * q15Scale)
        return sqrt(scaledSum)
    }
    
    // MARK: - Linear Regression (Adaptive)
    
    private static func calculateSlopeAdaptive(_ values: [Float], timeStep: Float) -> Float {
        guard values.count > 1 else { return 0.0 }
        
        let n = Float(values.count)
        var sumX: Float = 0.0
        var sumY: Float = 0.0
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        
        // Scalar accumulation
        for (i, y) in values.enumerated() {
            let x = Float(i) * timeStep
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return 0.0 }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        return slope
    }
    
    // MARK: - Detrended Fluctuation Analysis (Adaptive)
    
    static func dfaAlphaAdaptive(_ timeSeries: [Q15], 
                                 minBoxSize: Int = 4, 
                                 maxBoxSize: Int = 64) -> Float {
        
        guard timeSeries.count >= maxBoxSize * 2 else { return 0.0 }
        
        // Apply adaptive scaling to input
        let (scaledTimeSeries, scaleInfo) = scalingEngine.scaleSignal(timeSeries, stage: "dfa_input")
        
        // Calculate mean with scalar operations
        var sum: Int64 = 0
        for value in scaledTimeSeries {
            sum += Int64(value)
        }
        let mean = Q15(sum / Int64(scaledTimeSeries.count))
        
        // Cumulative sum with adaptive scaling
        var cumulativeSum: [Int32] = []
        cumulativeSum.reserveCapacity(scaledTimeSeries.count)
        
        var runningSum: Int64 = 0
        for (i, value) in scaledTimeSeries.enumerated() {
            runningSum += Int64(value) - Int64(mean)
            
            // Apply stage-specific scaling for cumulative sum
            if i % 100 == 0 { // Check periodically
                let tempSum = [Int32(runningSum)]
                let (scaledSum, _) = scalingEngine.scaleSignal(
                    tempSum.map { Q15($0 / 256) }, 
                    stage: "dfa_cumsum"
                )
                runningSum = Int64(scaledSum[0]) * 256
            }
            
            // Scale to prevent overflow
            cumulativeSum.append(Int32(runningSum / 256))
        }
        
        var boxSizes: [Int] = []
        var fluctuations: [Float] = []
        
        // Logarithmically spaced box sizes
        var boxSize = minBoxSize
        while boxSize <= maxBoxSize && boxSize < cumulativeSum.count / 4 {
            boxSizes.append(boxSize)
            
            let fluctuation = calculateFluctuationAdaptive(cumulativeSum, boxSize: boxSize)
            fluctuations.append(fluctuation)
            
            boxSize = Int(Float(boxSize) * 1.2)
        }
        
        guard boxSizes.count >= 3 else { return 0.0 }
        
        // Linear regression in log-log space
        let logBoxSizes = boxSizes.map { log(Float($0)) }
        let logFluctuations = fluctuations.map { log(max($0, 1e-10)) }
        
        let alpha = calculateSlopeAdaptive(logFluctuations, logBoxSizes)
        
        // Adjust alpha based on initial scaling
        return alpha * scaleInfo.scaleFactor
    }
    
    private static func calculateFluctuationAdaptive(_ cumulativeSum: [Int32], boxSize: Int) -> Float {
        let numBoxes = cumulativeSum.count / boxSize
        var totalFluctuation: Float = 0.0
        
        for i in 0..<numBoxes {
            let startIndex = i * boxSize
            let endIndex = min(startIndex + boxSize, cumulativeSum.count)
            
            let boxData = Array(cumulativeSum[startIndex..<endIndex])
            
            guard boxData.count > 1 else { continue }
            
            // Apply adaptive scaling to box data
            let q15BoxData = boxData.map { Q15($0 / 256) } // Convert back to Q15 range
            let (scaledBoxData, boxScaleInfo) = scalingEngine.scaleSignal(q15BoxData, stage: "dfa_box_\(i)")
            
            // Linear trend removal with scalar operations
            let (slope, intercept) = linearTrendAdaptive(scaledBoxData)
            
            // Calculate RMS of residuals
            var sumSquaredResiduals: Float = 0.0
            for j in 0..<scaledBoxData.count {
                let x = Float(j)
                let y = FixedPointMath.q15ToFloat(scaledBoxData[j])
                let fitted = slope * x + intercept
                let residual = y - fitted
                sumSquaredResiduals += residual * residual
            }
            
            let rms = sqrt(sumSquaredResiduals / Float(scaledBoxData.count))
            
            // Adjust RMS based on box scaling
            let adjustedRMS = rms * boxScaleInfo.scaleFactor
            totalFluctuation += adjustedRMS * adjustedRMS * Float(boxSize)
        }
        
        guard numBoxes > 0 else { return 0.0 }
        return sqrt(totalFluctuation / Float(numBoxes * boxSize))
    }
    
    private static func linearTrendAdaptive(_ data: [Q15]) -> (slope: Float, intercept: Float) {
        guard !data.isEmpty else { return (0.0, 0.0) }
        
        let n = Float(data.count)
        var sumX: Float = 0.0
        var sumY: Float = 0.0
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        
        // Scalar calculation
        for i in 0..<data.count {
            let x = Float(i)
            let y = FixedPointMath.q15ToFloat(data[i])
            
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return (0, sumY / n) }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        
        return (slope, intercept)
    }
    
    private static func calculateSlopeAdaptive(_ yValues: [Float], _ xValues: [Float]) -> Float {
        guard yValues.count == xValues.count && yValues.count > 1 else { return 0.0 }
        
        let n = Float(yValues.count)
        var sumX: Float = 0.0
        var sumY: Float = 0.0
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        
        // Scalar regression
        for i in 0..<yValues.count {
            let x = xValues[i]
            let y = yValues[i]
            
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return 0.0 }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        return slope
    }
}