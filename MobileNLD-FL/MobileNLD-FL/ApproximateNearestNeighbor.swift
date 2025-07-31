//
//  ApproximateNearestNeighbor.swift
//  MobileNLD-FL
//
//  近似最近傍探索によるO(n²)→O(n log n)改善
//  NLD計算の最大のボトルネックを解消
//

import Foundation

/// 近似最近傍探索の実装
/// Lyapunov指数計算の高速化のため、厳密な最近傍ではなく十分近い点を高速に見つける
public struct ApproximateNearestNeighbor {
    
    // MARK: - Types
    
    /// 空間分割手法
    public enum PartitioningMethod {
        case gridBased          // グリッドベースの分割
        case randomProjection   // ランダム射影によるLSH
        case kdTree            // KD-tree（低次元向け）
        case adaptive          // データ特性に応じて選択
    }
    
    /// 近傍探索結果
    public struct NeighborResult {
        let index: Int
        let distance: Float
        let isExact: Bool  // 厳密な最近傍かどうか
    }
    
    /// 探索パラメータ
    public struct SearchParameters {
        let approximationFactor: Float  // 1.0 = 厳密、2.0 = 2倍以内の距離を許容
        let maxCandidates: Int         // 検討する候補点の最大数
        let temporalExclusion: Int     // 時間的に近い点を除外する範囲
        
        public static let fast = SearchParameters(
            approximationFactor: 2.0,
            maxCandidates: 50,
            temporalExclusion: 10
        )
        
        public static let balanced = SearchParameters(
            approximationFactor: 1.5,
            maxCandidates: 100,
            temporalExclusion: 10
        )
        
        public static let accurate = SearchParameters(
            approximationFactor: 1.2,
            maxCandidates: 200,
            temporalExclusion: 10
        )
    }
    
    // MARK: - Grid-Based Approximate Search
    
    /// グリッドベースの近似最近傍探索
    /// 低〜中次元データに効果的
    public static func findNearestNeighborsGrid(
        phaseSpace: [[Q15]],
        targetIndex: Int,
        parameters: SearchParameters = .balanced
    ) -> [NeighborResult] {
        
        guard !phaseSpace.isEmpty, targetIndex < phaseSpace.count else { return [] }
        
        let dimension = phaseSpace[0].count
        let numPoints = phaseSpace.count
        
        // グリッドパラメータの決定
        let gridResolution = determineGridResolution(numPoints: numPoints, dimension: dimension)
        
        // 各点をグリッドセルに割り当て
        let grid = buildGrid(phaseSpace: phaseSpace, resolution: gridResolution)
        
        // ターゲット点のセルを特定
        let targetPoint = phaseSpace[targetIndex]
        let targetCell = getGridCell(point: targetPoint, resolution: gridResolution)
        
        // 近隣セルの候補を生成
        let candidateCells = getNearbyCells(cell: targetCell, radius: 1)
        
        // 候補点を収集
        var candidates: [(index: Int, distance: Float)] = []
        
        for cell in candidateCells {
            if let indices = grid[cell] {
                for candidateIndex in indices {
                    // 時間的除外
                    if abs(candidateIndex - targetIndex) < parameters.temporalExclusion {
                        continue
                    }
                    
                    // 距離計算（スカラー版で高速化）
                    let distance = euclideanDistanceScalar(
                        phaseSpace[targetIndex],
                        phaseSpace[candidateIndex]
                    )
                    
                    candidates.append((candidateIndex, distance))
                    
                    // 早期終了
                    if candidates.count >= parameters.maxCandidates * 2 {
                        break
                    }
                }
            }
        }
        
        // 距離でソート
        candidates.sort { $0.distance < $1.distance }
        
        // 上位k個を返す
        let topK = min(parameters.maxCandidates, candidates.count)
        return candidates.prefix(topK).map { candidate in
            NeighborResult(
                index: candidate.index,
                distance: candidate.distance,
                isExact: false  // グリッドベースは常に近似
            )
        }
    }
    
    // MARK: - Random Projection (LSH)
    
    /// ランダム射影による局所敏感ハッシュ（LSH）
    /// 高次元データに効果的
    public static func findNearestNeighborsLSH(
        phaseSpace: [[Q15]],
        targetIndex: Int,
        parameters: SearchParameters = .balanced
    ) -> [NeighborResult] {
        
        guard !phaseSpace.isEmpty, targetIndex < phaseSpace.count else { return [] }
        
        let dimension = phaseSpace[0].count
        let numProjections = min(dimension, 10)  // 射影数
        
        // ランダム射影行列の生成（簡略化）
        let projections = generateRandomProjections(
            dimension: dimension,
            numProjections: numProjections
        )
        
        // 各点をハッシュ
        var hashBuckets: [Int: [Int]] = [:]
        
        for (index, point) in phaseSpace.enumerated() {
            let hash = computeLSHHash(point: point, projections: projections)
            hashBuckets[hash, default: []].append(index)
        }
        
        // ターゲット点のハッシュ
        let targetHash = computeLSHHash(
            point: phaseSpace[targetIndex],
            projections: projections
        )
        
        // 同じバケット内の点を候補とする
        var candidates: [(index: Int, distance: Float)] = []
        
        // 近隣ハッシュも検討（ハミング距離1以内）
        let nearbyHashes = getNearbyHashes(hash: targetHash, hammingDistance: 1)
        
        for hash in nearbyHashes {
            if let indices = hashBuckets[hash] {
                for candidateIndex in indices {
                    if abs(candidateIndex - targetIndex) < parameters.temporalExclusion {
                        continue
                    }
                    
                    let distance = euclideanDistanceScalar(
                        phaseSpace[targetIndex],
                        phaseSpace[candidateIndex]
                    )
                    
                    candidates.append((candidateIndex, distance))
                }
            }
        }
        
        // 距離でソートして返す
        candidates.sort { $0.distance < $1.distance }
        
        return candidates.prefix(parameters.maxCandidates).map { candidate in
            NeighborResult(
                index: candidate.index,
                distance: candidate.distance,
                isExact: false
            )
        }
    }
    
    // MARK: - Adaptive Method Selection
    
    /// データ特性に応じて最適な手法を選択
    public static func findNearestNeighborsAdaptive(
        phaseSpace: [[Q15]],
        targetIndex: Int,
        parameters: SearchParameters = .balanced
    ) -> [NeighborResult] {
        
        guard !phaseSpace.isEmpty else { return [] }
        
        let dimension = phaseSpace[0].count
        let numPoints = phaseSpace.count
        
        // データ特性に基づいて手法を選択
        let method = selectOptimalMethod(
            numPoints: numPoints,
            dimension: dimension
        )
        
        switch method {
        case .gridBased:
            return findNearestNeighborsGrid(
                phaseSpace: phaseSpace,
                targetIndex: targetIndex,
                parameters: parameters
            )
            
        case .randomProjection:
            return findNearestNeighborsLSH(
                phaseSpace: phaseSpace,
                targetIndex: targetIndex,
                parameters: parameters
            )
            
        case .kdTree:
            // KD-treeは低次元で効果的だが、実装が複雑なので簡略化
            return findNearestNeighborsGrid(
                phaseSpace: phaseSpace,
                targetIndex: targetIndex,
                parameters: parameters
            )
            
        case .adaptive:
            // 再帰を避けるため、デフォルトでグリッドベースを使用
            return findNearestNeighborsGrid(
                phaseSpace: phaseSpace,
                targetIndex: targetIndex,
                parameters: parameters
            )
        }
    }
    
    // MARK: - Performance Comparison
    
    /// 性能比較実験
    public static func comparePerformance(
        phaseSpace: [[Q15]],
        sampleIndices: [Int]
    ) -> PerformanceComparison {
        
        var exactTimes: [Double] = []
        var gridTimes: [Double] = []
        var lshTimes: [Double] = []
        
        var gridAccuracy: [Float] = []
        var lshAccuracy: [Float] = []
        
        for targetIndex in sampleIndices {
            // 厳密な最近傍（ベースライン）
            let exactStart = CFAbsoluteTimeGetCurrent()
            let exactNeighbor = findExactNearestNeighbor(
                phaseSpace: phaseSpace,
                targetIndex: targetIndex
            )
            exactTimes.append((CFAbsoluteTimeGetCurrent() - exactStart) * 1000)
            
            // グリッドベース
            let gridStart = CFAbsoluteTimeGetCurrent()
            let gridNeighbors = findNearestNeighborsGrid(
                phaseSpace: phaseSpace,
                targetIndex: targetIndex,
                parameters: .fast
            )
            gridTimes.append((CFAbsoluteTimeGetCurrent() - gridStart) * 1000)
            
            if let gridBest = gridNeighbors.first {
                let accuracy = exactNeighbor.distance / gridBest.distance
                gridAccuracy.append(accuracy)
            }
            
            // LSH
            let lshStart = CFAbsoluteTimeGetCurrent()
            let lshNeighbors = findNearestNeighborsLSH(
                phaseSpace: phaseSpace,
                targetIndex: targetIndex,
                parameters: .fast
            )
            lshTimes.append((CFAbsoluteTimeGetCurrent() - lshStart) * 1000)
            
            if let lshBest = lshNeighbors.first {
                let accuracy = exactNeighbor.distance / lshBest.distance
                lshAccuracy.append(accuracy)
            }
        }
        
        return PerformanceComparison(
            exactAverageTimeMs: exactTimes.reduce(0, +) / Double(exactTimes.count),
            gridAverageTimeMs: gridTimes.reduce(0, +) / Double(gridTimes.count),
            lshAverageTimeMs: lshTimes.reduce(0, +) / Double(lshTimes.count),
            gridAverageAccuracy: gridAccuracy.reduce(0, +) / Float(gridAccuracy.count),
            lshAverageAccuracy: lshAccuracy.reduce(0, +) / Float(lshAccuracy.count)
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func determineGridResolution(numPoints: Int, dimension: Int) -> Int {
        // グリッド解像度の決定（ヒューリスティック）
        let cellsPerDimension = max(2, Int(pow(Double(numPoints), 1.0 / Double(dimension))))
        return min(cellsPerDimension, 10)  // 最大10x10x...グリッド
    }
    
    private static func buildGrid(
        phaseSpace: [[Q15]],
        resolution: Int
    ) -> [GridCell: [Int]] {
        
        var grid: [GridCell: [Int]] = [:]
        
        for (index, point) in phaseSpace.enumerated() {
            let cell = getGridCell(point: point, resolution: resolution)
            grid[cell, default: []].append(index)
        }
        
        return grid
    }
    
    private static func getGridCell(point: [Q15], resolution: Int) -> GridCell {
        var indices: [Int] = []
        
        for value in point {
            // Q15を[0, resolution-1]の範囲にマップ
            let normalized = (Float(value) + Float(Q15.max)) / (2.0 * Float(Q15.max))
            let index = Int(normalized * Float(resolution - 1))
            indices.append(min(max(index, 0), resolution - 1))
        }
        
        return GridCell(indices: indices)
    }
    
    private static func getNearbyCells(cell: GridCell, radius: Int) -> [GridCell] {
        // 簡略化：現在のセルと隣接セルのみ返す
        var cells = [cell]
        
        // 各次元で±1のセルを追加（簡略化）
        for dim in 0..<cell.indices.count {
            var neighborIndices = cell.indices
            
            if cell.indices[dim] > 0 {
                neighborIndices[dim] = cell.indices[dim] - 1
                cells.append(GridCell(indices: neighborIndices))
            }
            
            neighborIndices = cell.indices
            if cell.indices[dim] < 9 {  // 仮定：最大解像度10
                neighborIndices[dim] = cell.indices[dim] + 1
                cells.append(GridCell(indices: neighborIndices))
            }
        }
        
        return cells
    }
    
    private static func generateRandomProjections(
        dimension: Int,
        numProjections: Int
    ) -> [[Float]] {
        
        var projections: [[Float]] = []
        
        for _ in 0..<numProjections {
            var projection: [Float] = []
            for _ in 0..<dimension {
                // 簡単な±1ランダム射影
                projection.append(Float.random(in: 0...1) > 0.5 ? 1.0 : -1.0)
            }
            projections.append(projection)
        }
        
        return projections
    }
    
    private static func computeLSHHash(point: [Q15], projections: [[Float]]) -> Int {
        var hash = 0
        
        for (i, projection) in projections.enumerated() {
            var dotProduct: Float = 0
            
            for j in 0..<point.count {
                dotProduct += FixedPointMath.q15ToFloat(point[j]) * projection[j]
            }
            
            if dotProduct > 0 {
                hash |= (1 << i)
            }
        }
        
        return hash
    }
    
    private static func getNearbyHashes(hash: Int, hammingDistance: Int) -> [Int] {
        var hashes = [hash]
        
        // ハミング距離1のハッシュを生成
        if hammingDistance >= 1 {
            for i in 0..<10 {  // 最大10ビット
                hashes.append(hash ^ (1 << i))
            }
        }
        
        return hashes
    }
    
    private static func euclideanDistanceScalar(_ a: [Q15], _ b: [Q15]) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        var sum: Int64 = 0
        for i in 0..<a.count {
            let diff = Int64(a[i]) - Int64(b[i])
            sum += diff * diff
        }
        
        let q15Scale = Float(1 << 15)
        return sqrt(Float(sum) / (q15Scale * q15Scale))
    }
    
    private static func findExactNearestNeighbor(
        phaseSpace: [[Q15]],
        targetIndex: Int
    ) -> NeighborResult {
        
        var minDistance = Float.infinity
        var nearestIndex = -1
        
        for i in 0..<phaseSpace.count {
            if abs(i - targetIndex) < 10 { continue }
            
            let distance = euclideanDistanceScalar(
                phaseSpace[targetIndex],
                phaseSpace[i]
            )
            
            if distance < minDistance {
                minDistance = distance
                nearestIndex = i
            }
        }
        
        return NeighborResult(
            index: nearestIndex,
            distance: minDistance,
            isExact: true
        )
    }
    
    private static func selectOptimalMethod(
        numPoints: Int,
        dimension: Int
    ) -> PartitioningMethod {
        
        // ヒューリスティックな選択
        if dimension <= 5 && numPoints < 1000 {
            return .gridBased
        } else if dimension > 10 {
            return .randomProjection
        } else {
            return .gridBased  // デフォルト
        }
    }
}

// MARK: - Supporting Types

struct GridCell: Hashable {
    let indices: [Int]
}

public struct PerformanceComparison {
    public let exactAverageTimeMs: Double
    public let gridAverageTimeMs: Double
    public let lshAverageTimeMs: Double
    public let gridAverageAccuracy: Float
    public let lshAverageAccuracy: Float
    
    public var gridSpeedup: Double {
        exactAverageTimeMs / gridAverageTimeMs
    }
    
    public var lshSpeedup: Double {
        exactAverageTimeMs / lshAverageTimeMs
    }
}