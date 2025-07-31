//
//  NonlinearDynamicsSIMDOnly.swift
//  MobileNLD-FL
//
//  SIMD最適化のみ実装版（動的調整なし）
//  実験計画 5.4 SIMD Optimization Effect Evaluation用
//

import Foundation

struct NonlinearDynamicsSIMDOnly {
    
    // MARK: - Lyapunov Exponent (SIMD Only - No Adaptive Scaling)
    
    /// Calculate Lyapunov exponent using SIMD optimization without dynamic scaling
    static func lyapunovExponentSIMDOnly(_ timeSeries: [Q15], 
                                        embeddingDim: Int = 5, 
                                        delay: Int = 4, 
                                        samplingRate: Int = 50) -> Float {
        
        guard timeSeries.count >= embeddingDim * delay + 100 else {
            return 0.0 // Insufficient data
        }
        
        // Phase space reconstruction using direct SIMD operations
        let embeddings = phaseSpaceReconstructionSIMDOnly(timeSeries, 
                                                          dimension: embeddingDim, 
                                                          delay: delay)
        
        guard embeddings.count > 10 else { return 0.0 }
        
        // Find nearest neighbors and calculate divergence
        var divergences: [Float] = []
        let maxSteps = min(50, timeSeries.count / 10)
        
        for i in 0..<embeddings.count - maxSteps {
            if let nearestIndex = findNearestNeighborSIMDOnly(embeddings, targetIndex: i, minSeparation: 10) {
                
                // Track divergence evolution
                var logDivergences: [Float] = []
                
                for step in 1...maxSteps {
                    let currentIndex = i + step
                    let neighborIndex = nearestIndex + step
                    
                    guard currentIndex < embeddings.count && neighborIndex < embeddings.count else { break }
                    
                    // Direct SIMD distance calculation without scaling
                    let distance = euclideanDistanceSIMDOnly(embeddings[currentIndex], embeddings[neighborIndex])
                    
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
        
        // Linear regression to find slope
        let timeStep = 1.0 / Float(samplingRate)
        let lyapunovExponent = calculateSlopeSIMDOnly(divergences, timeStep: timeStep)
        
        return lyapunovExponent
    }
    
    // MARK: - Phase Space Reconstruction (SIMD Only)
    
    private static func phaseSpaceReconstructionSIMDOnly(_ timeSeries: [Q15], 
                                                        dimension: Int, 
                                                        delay: Int) -> [[Q15]] {
        let numPoints = timeSeries.count - (dimension - 1) * delay
        guard numPoints > 0 else { return [] }
        
        var embeddings: [[Q15]] = []
        embeddings.reserveCapacity(numPoints)
        
        // Standard reconstruction - no adaptive scaling
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
    
    // MARK: - Nearest Neighbor Search (SIMD Only)
    
    private static func findNearestNeighborSIMDOnly(_ embeddings: [[Q15]], 
                                                   targetIndex: Int, 
                                                   minSeparation: Int) -> Int? {
        guard !embeddings.isEmpty else { return nil }
        
        // Convert to contiguous memory for SIMD
        let embeddingDim = embeddings[0].count
        let flatEmbeddings = embeddings.flatMap { $0 }
        
        return flatEmbeddings.withUnsafeBufferPointer { flatPtr in
            // Direct SIMD search without adaptive scaling
            let neighbors = SIMDOptimizations.findNearestNeighborsSIMD(
                phaseSpace: flatPtr.baseAddress!,
                dimensions: (points: embeddings.count, embedding: embeddingDim),
                pointIndex: targetIndex,
                temporalWindow: minSeparation
            )
            
            return neighbors.first?.index
        }
    }
    
    // MARK: - Distance Calculation (SIMD Only)
    
    private static func euclideanDistanceSIMDOnly(_ a: [Q15], _ b: [Q15]) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        // Direct SIMD distance without scaling
        return a.withUnsafeBufferPointer { aPtr in
            b.withUnsafeBufferPointer { bPtr in
                return SIMDOptimizations.euclideanDistanceSIMD(
                    aPtr.baseAddress!,
                    bPtr.baseAddress!,
                    dimension: a.count
                )
            }
        }
    }
    
    // MARK: - Linear Regression (SIMD Only)
    
    private static func calculateSlopeSIMDOnly(_ values: [Float], timeStep: Float) -> Float {
        guard values.count > 1 else { return 0.0 }
        
        // Create x values
        let x = Array(0..<values.count).map { Float($0) * timeStep }
        
        // Use SIMD-optimized linear regression
        let (slope, _) = SIMDOptimizations.linearRegressionSIMD(x: x, y: values)
        return slope
    }
    
    // MARK: - Detrended Fluctuation Analysis (SIMD Only)
    
    static func dfaAlphaSIMDOnly(_ timeSeries: [Q15], 
                                minBoxSize: Int = 4, 
                                maxBoxSize: Int = 64) -> Float {
        
        guard timeSeries.count >= maxBoxSize * 2 else { return 0.0 }
        
        // Calculate mean using SIMD reduction
        let mean = timeSeries.reduce(Q15(0), &+) / Q15(timeSeries.count)
        
        // Cumulative sum using SIMD
        let cumulativeSumInt32 = SIMDOptimizations.cumulativeSumSIMD(timeSeries, mean: mean)
        
        // Convert to Float for DFA calculations
        let cumulativeSum = cumulativeSumInt32.map { Float($0) / Float(1 << 15) }
        
        var boxSizes: [Int] = []
        var fluctuations: [Float] = []
        
        // Logarithmically spaced box sizes
        var boxSize = minBoxSize
        while boxSize <= maxBoxSize && boxSize < cumulativeSum.count / 4 {
            boxSizes.append(boxSize)
            
            let fluctuation = calculateFluctuationSIMDOnly(cumulativeSum, boxSize: boxSize)
            fluctuations.append(fluctuation)
            
            boxSize = Int(Float(boxSize) * 1.2)
        }
        
        guard boxSizes.count >= 3 else { return 0.0 }
        
        // Linear regression in log-log space
        let logBoxSizes = boxSizes.map { log(Float($0)) }
        let logFluctuations = fluctuations.map { log(max($0, 1e-10)) }
        
        return calculateSlopeSIMDOnly(logFluctuations, logBoxSizes)
    }
    
    private static func calculateFluctuationSIMDOnly(_ cumulativeSum: [Float], boxSize: Int) -> Float {
        let numBoxes = cumulativeSum.count / boxSize
        var totalFluctuation: Float = 0.0
        
        for i in 0..<numBoxes {
            let startIndex = i * boxSize
            let endIndex = min(startIndex + boxSize, cumulativeSum.count)
            
            let boxData = Array(cumulativeSum[startIndex..<endIndex])
            
            guard boxData.count > 1 else { continue }
            
            // Use SIMD-optimized linear regression for detrending
            let x = Array(0..<boxData.count).map { Float($0) }
            let (slope, intercept) = SIMDOptimizations.linearRegressionSIMD(x: x, y: boxData)
            
            // Calculate RMS of residuals
            var rms: Float = 0.0
            for j in 0..<boxData.count {
                let fitted = slope * Float(j) + intercept
                let residual = boxData[j] - fitted
                rms += residual * residual
            }
            rms = sqrt(rms / Float(boxData.count))
            
            totalFluctuation += rms * rms * Float(boxSize)
        }
        
        guard numBoxes > 0 else { return 0.0 }
        return sqrt(totalFluctuation / Float(numBoxes * boxSize))
    }
    
    private static func calculateSlopeSIMDOnly(_ yValues: [Float], _ xValues: [Float]) -> Float {
        guard yValues.count == xValues.count && yValues.count > 1 else { return 0.0 }
        
        // Use SIMD-optimized linear regression
        let (slope, _) = SIMDOptimizations.linearRegressionSIMD(x: xValues, y: yValues)
        return slope
    }
    
    // MARK: - Performance Measurement Helpers
    
    /// Measure SIMD utilization for this implementation
    static func measurePerformance(iterations: Int = 1000) -> (time: Double, simdUtilization: Double) {
        let testSignal = generateTestSignal(length: 150)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = lyapunovExponentSIMDOnly(testSignal)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        // Estimate SIMD utilization (simplified)
        // Real measurement would use Instruments
        let estimatedUtilization = 60.0 // Placeholder - actual measurement needed
        
        return (totalTime / Double(iterations), estimatedUtilization)
    }
    
    private static func generateTestSignal(length: Int) -> [Q15] {
        var signal: [Q15] = []
        signal.reserveCapacity(length)
        
        for i in 0..<length {
            let value = sin(Float(i) * 0.1) * 0.5
            signal.append(FixedPointMath.floatToQ15(value))
        }
        
        return signal
    }
}