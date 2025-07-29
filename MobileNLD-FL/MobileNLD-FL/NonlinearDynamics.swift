//
//  NonlinearDynamics.swift
//  MobileNLD-FL
//
//  Nonlinear dynamics indicators implementation using Q15 fixed-point arithmetic
//  Implements Lyapunov Exponent (Rosenstein method) and DFA analysis
//

import Foundation

struct NonlinearDynamics {
    
    // MARK: - Lyapunov Exponent (Rosenstein Method)
    
    /// Calculate Lyapunov exponent using Rosenstein method with Q15 arithmetic
    /// - Parameters:
    ///   - timeSeries: Input time series data in Q15 format
    ///   - embeddingDim: Embedding dimension (typically 3-10)
    ///   - delay: Time delay for embedding (typically 1-5)
    ///   - samplingRate: Sampling rate in Hz
    /// - Returns: Lyapunov exponent as Q15 value
    static func lyapunovExponent(_ timeSeries: [Q15], 
                                embeddingDim: Int = 5, 
                                delay: Int = 4, 
                                samplingRate: Int = 50) -> Float {
        
        guard timeSeries.count >= embeddingDim * delay + 100 else {
            return 0.0 // Insufficient data
        }
        
        // Phase space reconstruction
        let embeddings = phaseSpaceReconstruction(timeSeries, 
                                                 dimension: embeddingDim, 
                                                 delay: delay)
        
        guard embeddings.count > 10 else { return 0.0 }
        
        // Find nearest neighbors and calculate divergence
        var divergences: [Float] = []
        let maxSteps = min(50, timeSeries.count / 10) // Limit for real-time performance
        
        for i in 0..<embeddings.count - maxSteps {
            if let nearestIndex = findNearestNeighbor(embeddings, targetIndex: i, minSeparation: 10) {
                
                // Track divergence evolution
                var logDivergences: [Float] = []
                
                for step in 1...maxSteps {
                    let currentIndex = i + step
                    let neighborIndex = nearestIndex + step
                    
                    guard currentIndex < embeddings.count && neighborIndex < embeddings.count else { break }
                    
                    let distance = euclideanDistance(embeddings[currentIndex], embeddings[neighborIndex])
                    
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
        let lyapunovExponent = calculateSlope(divergences, timeStep: timeStep)
        
        return lyapunovExponent
    }
    
    // MARK: - Phase Space Reconstruction
    
    private static func phaseSpaceReconstruction(_ timeSeries: [Q15], 
                                               dimension: Int, 
                                               delay: Int) -> [[Q15]] {
        let numPoints = timeSeries.count - (dimension - 1) * delay
        guard numPoints > 0 else { return [] }
        
        var embeddings: [[Q15]] = []
        
        for i in 0..<numPoints {
            var embedding: [Q15] = []
            for j in 0..<dimension {
                let index = i + j * delay
                embedding.append(timeSeries[index])
            }
            embeddings.append(embedding)
        }
        
        return embeddings
    }
    
    // MARK: - Nearest Neighbor Search
    
    private static func findNearestNeighbor(_ embeddings: [[Q15]], 
                                          targetIndex: Int, 
                                          minSeparation: Int) -> Int? {
        let target = embeddings[targetIndex]
        var minDistance: Float = Float.infinity
        var nearestIndex: Int?
        
        for i in 0..<embeddings.count {
            // Skip points too close in time
            if abs(i - targetIndex) < minSeparation { continue }
            
            let distance = euclideanDistance(target, embeddings[i])
            if distance < minDistance {
                minDistance = distance
                nearestIndex = i
            }
        }
        
        return nearestIndex
    }
    
    // MARK: - Distance Calculation
    
    private static func euclideanDistance(_ a: [Q15], _ b: [Q15]) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        var sumSquares: Float = 0.0
        for i in 0..<a.count {
            let diff = FixedPointMath.q15ToFloat(FixedPointMath.subtract(a[i], b[i]))
            sumSquares += diff * diff
        }
        
        return sqrt(sumSquares)
    }
    
    // MARK: - Linear Regression for Slope
    
    private static func calculateSlope(_ values: [Float], timeStep: Float) -> Float {
        guard values.count > 1 else { return 0.0 }
        
        let n = Float(values.count)
        var sumX: Float = 0.0
        var sumY: Float = 0.0
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        
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
    
    // MARK: - Detrended Fluctuation Analysis (DFA)
    
    /// Calculate DFA scaling exponent using Q15 arithmetic
    /// - Parameters:
    ///   - timeSeries: Input time series data in Q15 format
    ///   - minBoxSize: Minimum box size for analysis
    ///   - maxBoxSize: Maximum box size for analysis
    /// - Returns: DFA scaling exponent (alpha)
    static func dfaAlpha(_ timeSeries: [Q15], 
                        minBoxSize: Int = 4, 
                        maxBoxSize: Int = 64) -> Float {
        
        guard timeSeries.count >= maxBoxSize * 2 else { return 0.0 }
        
        // Convert to cumulative sum (integration)
        let floatSeries = timeSeries.map { FixedPointMath.q15ToFloat($0) }
        let mean = floatSeries.reduce(0.0, +) / Float(floatSeries.count)
        let centeredSeries = floatSeries.map { $0 - mean }
        
        var cumulativeSum: [Float] = [0.0]
        for value in centeredSeries {
            cumulativeSum.append(cumulativeSum.last! + value)
        }
        
        var boxSizes: [Int] = []
        var fluctuations: [Float] = []
        
        // Logarithmically spaced box sizes
        var boxSize = minBoxSize
        while boxSize <= maxBoxSize && boxSize < cumulativeSum.count / 4 {
            boxSizes.append(boxSize)
            
            let fluctuation = calculateFluctuation(cumulativeSum, boxSize: boxSize)
            fluctuations.append(fluctuation)
            
            boxSize = Int(Float(boxSize) * 1.2) // Increase by 20%
        }
        
        guard boxSizes.count >= 3 else { return 0.0 }
        
        // Linear regression in log-log space
        let logBoxSizes = boxSizes.map { log(Float($0)) }
        let logFluctuations = fluctuations.map { log(max($0, 1e-10)) }
        
        return calculateSlope(logFluctuations, logBoxSizes)
    }
    
    private static func calculateFluctuation(_ cumulativeSum: [Float], boxSize: Int) -> Float {
        let numBoxes = cumulativeSum.count / boxSize
        var totalFluctuation: Float = 0.0
        
        for i in 0..<numBoxes {
            let startIndex = i * boxSize
            let endIndex = min(startIndex + boxSize, cumulativeSum.count)
            
            let boxData = Array(cumulativeSum[startIndex..<endIndex])
            let trend = linearTrend(boxData)
            
            var sumSquaredResiduals: Float = 0.0
            for (j, value) in boxData.enumerated() {
                let trendValue = trend.slope * Float(j) + trend.intercept
                let residual = value - trendValue
                sumSquaredResiduals += residual * residual
            }
            
            totalFluctuation += sumSquaredResiduals
        }
        
        return sqrt(totalFluctuation / Float(numBoxes * boxSize))
    }
    
    private static func linearTrend(_ data: [Float]) -> (slope: Float, intercept: Float) {
        let n = Float(data.count)
        guard n > 1 else { return (0.0, data.first ?? 0.0) }
        
        var sumX: Float = 0.0
        var sumY: Float = 0.0
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        
        for (i, y) in data.enumerated() {
            let x = Float(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return (0.0, sumY / n) }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        
        return (slope, intercept)
    }
    
    private static func calculateSlope(_ yValues: [Float], _ xValues: [Float]) -> Float {
        guard yValues.count == xValues.count && yValues.count > 1 else { return 0.0 }
        
        let n = Float(yValues.count)
        let sumX = xValues.reduce(0.0, +)
        let sumY = yValues.reduce(0.0, +)
        let sumXY = zip(xValues, yValues).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = xValues.reduce(0.0) { $0 + $1 * $1 }
        
        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return 0.0 }
        
        return (n * sumXY - sumX * sumY) / denominator
    }
}