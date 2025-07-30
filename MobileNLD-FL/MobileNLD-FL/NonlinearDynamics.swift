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
        guard !embeddings.isEmpty else { return nil }
        
        // Convert to contiguous memory layout for SIMD
        let embeddingDim = embeddings[0].count
        let flatEmbeddings = embeddings.flatMap { $0 }
        
        return flatEmbeddings.withUnsafeBufferPointer { flatPtr in
            let neighbors = SIMDOptimizations.findNearestNeighborsSIMD(
                phaseSpace: flatPtr.baseAddress!,
                dimensions: (points: embeddings.count, embedding: embeddingDim),
                pointIndex: targetIndex,
                temporalWindow: minSeparation
            )
            
            // Return the nearest neighbor (first in sorted list)
            return neighbors.first?.index
        }
    }
    
    // MARK: - Distance Calculation
    
    private static func euclideanDistance(_ a: [Q15], _ b: [Q15]) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        // Use SIMD-optimized version for better performance
        return a.withUnsafeBufferPointer { aPtr in
            b.withUnsafeBufferPointer { bPtr in
                let q15Distance = SIMDOptimizations.euclideanDistanceSIMD(
                    aPtr.baseAddress!,
                    bPtr.baseAddress!,
                    dimension: a.count
                )
                return FixedPointMath.q15ToFloat(q15Distance)
            }
        }
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
        
        // Convert to cumulative sum using SIMD
        let mean = timeSeries.reduce(Q15(0), &+) / Q15(timeSeries.count)
        let cumulativeSumInt32 = SIMDOptimizations.cumulativeSumSIMD(timeSeries, mean: mean)
        
        // Convert to Float for DFA calculations
        let cumulativeSum = cumulativeSumInt32.map { Float($0) / Float(1 << 15) }
        
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
            
            // Ensure we have valid data
            guard boxData.count > 1 else { continue }
            
            // boxData is already in Float format - use direct SIMD linear regression
            let x = Array(0..<boxData.count).map { Float($0) }
            
            // Check for any extreme values that might cause issues
            let maxValue = boxData.max() ?? 0
            let minValue = boxData.min() ?? 0
            
            // If values are too extreme, scale them down
            var scaledBoxData = boxData
            var scaleFactor: Float = 1.0
            
            if abs(maxValue) > 1e6 || abs(minValue) > 1e6 {
                scaleFactor = 1e6 / max(abs(maxValue), abs(minValue))
                scaledBoxData = boxData.map { $0 * scaleFactor }
            }
            
            let (slope, intercept) = SIMDOptimizations.linearRegressionSIMD(x: x, y: scaledBoxData)
            
            // Calculate RMS of residuals
            var rms: Float = 0.0
            for j in 0..<scaledBoxData.count {
                let fitted = slope * Float(j) + intercept
                let residual = scaledBoxData[j] - fitted
                rms += residual * residual
            }
            rms = sqrt(rms / Float(scaledBoxData.count))
            
            // Scale back if we scaled down
            rms = rms / scaleFactor
            
            totalFluctuation += rms * rms * Float(boxSize)
        }
        
        guard numBoxes > 0 else { return 0.0 }
        return sqrt(totalFluctuation / Float(numBoxes * boxSize))
    }
    
    private static func linearTrend(_ data: [Float]) -> (slope: Float, intercept: Float) {
        guard !data.isEmpty else { return (0.0, 0.0) }
        
        // Use SIMD-optimized linear regression
        let x = Array(0..<data.count).map { Float($0) }
        return SIMDOptimizations.linearRegressionSIMD(x: x, y: data)
    }
    
    private static func calculateSlope(_ yValues: [Float], _ xValues: [Float]) -> Float {
        guard yValues.count == xValues.count && yValues.count > 1 else { return 0.0 }
        
        // Use SIMD-optimized linear regression
        let (slope, _) = SIMDOptimizations.linearRegressionSIMD(x: xValues, y: yValues)
        return slope
    }
}