//
//  NonlinearDynamicsScalar.swift
//  MobileNLD-FL
//
//  スカラー実装版（vDSP/SIMD未使用）- 実験のベースライン
//  実験計画 5.4 SIMD Optimization Effect Evaluation用
//

import Foundation

struct NonlinearDynamicsScalar {
    
    // MARK: - Lyapunov Exponent (Scalar Implementation)
    
    /// Calculate Lyapunov exponent using pure scalar operations (no SIMD/vDSP)
    static func lyapunovExponentScalar(_ timeSeries: [Q15], 
                                     embeddingDim: Int = 5, 
                                     delay: Int = 4, 
                                     samplingRate: Int = 50) -> Float {
        
        guard timeSeries.count >= embeddingDim * delay + 100 else {
            return 0.0 // Insufficient data
        }
        
        // Phase space reconstruction - scalar implementation
        let embeddings = phaseSpaceReconstructionScalar(timeSeries, 
                                                       dimension: embeddingDim, 
                                                       delay: delay)
        
        guard embeddings.count > 10 else { return 0.0 }
        
        // Find nearest neighbors and calculate divergence
        var divergences: [Float] = []
        let maxSteps = min(50, timeSeries.count / 10)
        
        for i in 0..<embeddings.count - maxSteps {
            if let nearestIndex = findNearestNeighborScalar(embeddings, targetIndex: i, minSeparation: 10) {
                
                // Track divergence evolution
                var logDivergences: [Float] = []
                
                for step in 1...maxSteps {
                    let currentIndex = i + step
                    let neighborIndex = nearestIndex + step
                    
                    guard currentIndex < embeddings.count && neighborIndex < embeddings.count else { break }
                    
                    let distance = euclideanDistanceScalar(embeddings[currentIndex], embeddings[neighborIndex])
                    
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
        
        // Linear regression to find slope (Lyapunov exponent)
        let timeStep = 1.0 / Float(samplingRate)
        let lyapunovExponent = calculateSlopeScalar(divergences, timeStep: timeStep)
        
        return lyapunovExponent
    }
    
    // MARK: - Phase Space Reconstruction (Scalar)
    
    private static func phaseSpaceReconstructionScalar(_ timeSeries: [Q15], 
                                                     dimension: Int, 
                                                     delay: Int) -> [[Q15]] {
        let numPoints = timeSeries.count - (dimension - 1) * delay
        guard numPoints > 0 else { return [] }
        
        var embeddings: [[Q15]] = []
        embeddings.reserveCapacity(numPoints)
        
        // Pure scalar loops - no optimization
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
    
    // MARK: - Nearest Neighbor Search (Scalar)
    
    private static func findNearestNeighborScalar(_ embeddings: [[Q15]], 
                                                targetIndex: Int, 
                                                minSeparation: Int) -> Int? {
        guard !embeddings.isEmpty else { return nil }
        
        var minDistance: Float = Float.greatestFiniteMagnitude
        var nearestIndex: Int? = nil
        
        // Scalar search - no parallel processing
        for i in 0..<embeddings.count {
            // Skip temporal neighbors
            if abs(i - targetIndex) < minSeparation { continue }
            
            let distance = euclideanDistanceScalar(embeddings[targetIndex], embeddings[i])
            
            if distance < minDistance {
                minDistance = distance
                nearestIndex = i
            }
        }
        
        return nearestIndex
    }
    
    // MARK: - Distance Calculation (Scalar)
    
    private static func euclideanDistanceScalar(_ a: [Q15], _ b: [Q15]) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        var sum: Int64 = 0 // Use Int64 to prevent overflow
        
        // Pure scalar calculation - no SIMD
        for i in 0..<a.count {
            let diff = Int64(a[i]) - Int64(b[i])
            sum += diff * diff
        }
        
        // Convert back to Float and normalize
        let q15Scale = Float(1 << 15)
        let scaledSum = Float(sum) / (q15Scale * q15Scale)
        return sqrt(scaledSum)
    }
    
    // MARK: - Linear Regression (Scalar)
    
    private static func calculateSlopeScalar(_ values: [Float], timeStep: Float) -> Float {
        guard values.count > 1 else { return 0.0 }
        
        let n = Float(values.count)
        var sumX: Float = 0.0
        var sumY: Float = 0.0
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        
        // Scalar accumulation - no vectorization
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
    
    // MARK: - Detrended Fluctuation Analysis (Scalar)
    
    static func dfaAlphaScalar(_ timeSeries: [Q15], 
                              minBoxSize: Int = 4, 
                              maxBoxSize: Int = 64) -> Float {
        
        guard timeSeries.count >= maxBoxSize * 2 else { return 0.0 }
        
        // Calculate mean - scalar operation
        var sum: Int64 = 0
        for value in timeSeries {
            sum += Int64(value)
        }
        let mean = Q15(sum / Int64(timeSeries.count))
        
        // Cumulative sum - scalar implementation
        var cumulativeSum: [Int32] = []
        cumulativeSum.reserveCapacity(timeSeries.count)
        
        var runningSum: Int64 = 0
        for value in timeSeries {
            runningSum += Int64(value) - Int64(mean)
            // Scale to prevent overflow
            cumulativeSum.append(Int32(runningSum / 256))
        }
        
        var boxSizes: [Int] = []
        var fluctuations: [Float] = []
        
        // Logarithmically spaced box sizes
        var boxSize = minBoxSize
        while boxSize <= maxBoxSize && boxSize < cumulativeSum.count / 4 {
            boxSizes.append(boxSize)
            
            let fluctuation = calculateFluctuationScalar(cumulativeSum, boxSize: boxSize)
            fluctuations.append(fluctuation)
            
            boxSize = Int(Float(boxSize) * 1.2) // Increase by 20%
        }
        
        guard boxSizes.count >= 3 else { return 0.0 }
        
        // Linear regression in log-log space
        let logBoxSizes = boxSizes.map { log(Float($0)) }
        let logFluctuations = fluctuations.map { log(max($0, 1e-10)) }
        
        return calculateSlopeScalar(logFluctuations, logBoxSizes)
    }
    
    private static func calculateFluctuationScalar(_ cumulativeSum: [Int32], boxSize: Int) -> Float {
        let numBoxes = cumulativeSum.count / boxSize
        var totalFluctuation: Float = 0.0
        
        for i in 0..<numBoxes {
            let startIndex = i * boxSize
            let endIndex = min(startIndex + boxSize, cumulativeSum.count)
            
            let boxData = Array(cumulativeSum[startIndex..<endIndex])
            
            guard boxData.count > 1 else { continue }
            
            // Linear trend removal - scalar implementation
            let (slope, intercept) = linearTrendScalar(boxData)
            
            // Calculate RMS of residuals
            var sumSquaredResiduals: Float = 0.0
            for j in 0..<boxData.count {
                let x = Float(j)
                let y = Float(boxData[j]) * 256.0 / Float(1 << 15) // Undo scaling
                let fitted = slope * x + intercept
                let residual = y - fitted
                sumSquaredResiduals += residual * residual
            }
            
            let rms = sqrt(sumSquaredResiduals / Float(boxData.count))
            totalFluctuation += rms * rms * Float(boxSize)
        }
        
        guard numBoxes > 0 else { return 0.0 }
        return sqrt(totalFluctuation / Float(numBoxes * boxSize))
    }
    
    private static func linearTrendScalar(_ data: [Int32]) -> (slope: Float, intercept: Float) {
        guard !data.isEmpty else { return (0.0, 0.0) }
        
        let n = Float(data.count)
        var sumX: Float = 0.0
        var sumY: Float = 0.0
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        
        // Scalar calculation
        for i in 0..<data.count {
            let x = Float(i)
            let y = Float(data[i]) * 256.0 / Float(1 << 15) // Undo scaling
            
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
    
    private static func calculateSlopeScalar(_ yValues: [Float], _ xValues: [Float]) -> Float {
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
    
    // MARK: - Cumulative Sum (Scalar)
    
    static func cumulativeSumScalar(_ input: [Q15], mean: Q15) -> [Int32] {
        var result: [Int32] = []
        result.reserveCapacity(input.count)
        
        var sum: Int64 = 0
        
        // Scalar cumulative sum
        for value in input {
            sum += Int64(value) - Int64(mean)
            
            // Scale to prevent overflow
            let scaled = sum / 256
            
            // Clamp to Int32 range
            if scaled > Int64(Int32.max) {
                result.append(Int32.max)
            } else if scaled < Int64(Int32.min) {
                result.append(Int32.min)
            } else {
                result.append(Int32(scaled))
            }
        }
        
        return result
    }
}