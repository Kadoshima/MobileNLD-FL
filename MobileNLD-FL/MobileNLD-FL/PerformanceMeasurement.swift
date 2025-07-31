//
//  PerformanceMeasurement.swift
//  MobileNLD-FL
//
//  Signpostを使った正確なSIMD利用率測定
//

import Foundation
import os.log
import os.signpost

class PerformanceMeasurement {
    private static let log = OSLog(subsystem: "com.mobileNLD.performance", category: "SIMD")
    
    /// NLD計算のパフォーマンス測定
    static func measureNLDPerformance() {
        let signpostID = OSSignpostID(log: log)
        
        // テストデータ生成
        let testLength = 10000  // より長いデータで測定
        let testSignal = NonlinearDynamicsTests.generateTestSignal(length: testLength, samplingRate: 50)
        
        print("=== SIMD Performance Measurement ===")
        print("Starting NLD calculations with Signpost...")
        
        // ウォームアップ
        for _ in 0..<5 {
            _ = OptimizedNonlinearDynamics.lyapunovExponentOptimized(
                testSignal[0..<150], 
                embeddingDim: 5, 
                delay: 4, 
                samplingRate: 50
            )
        }
        
        // 1. Lyapunov指数の測定
        os_signpost(.begin, log: log, name: "Lyapunov", signpostID: signpostID)
        
        var lyeResults: [Float] = []
        for i in stride(from: 0, to: testLength - 150, by: 50) {
            let window = Array(testSignal[i..<i+150])
            let result = OptimizedNonlinearDynamics.lyapunovExponentOptimized(
                window,
                embeddingDim: 5,
                delay: 4,
                samplingRate: 50
            )
            lyeResults.append(result)
        }
        
        os_signpost(.end, log: log, name: "Lyapunov", signpostID: signpostID)
        
        // 2. DFAの測定
        os_signpost(.begin, log: log, name: "DFA", signpostID: signpostID)
        
        var dfaResults: [Float] = []
        for i in stride(from: 0, to: testLength - 150, by: 50) {
            let window = Array(testSignal[i..<i+150])
            let result = OptimizedNonlinearDynamics.dfaAlphaOptimized(
                window,
                minBoxSize: 4,
                maxBoxSize: 32
            )
            dfaResults.append(result)
        }
        
        os_signpost(.end, log: log, name: "DFA", signpostID: signpostID)
        
        // 3. 統合測定（両方の計算）
        os_signpost(.begin, log: log, name: "Combined_NLD", signpostID: signpostID)
        
        for i in stride(from: 0, to: testLength - 150, by: 50) {
            let window = Array(testSignal[i..<i+150])
            
            _ = OptimizedNonlinearDynamics.lyapunovExponentOptimized(
                window,
                embeddingDim: 5,
                delay: 4,
                samplingRate: 50
            )
            
            _ = OptimizedNonlinearDynamics.dfaAlphaOptimized(
                window,
                minBoxSize: 4,
                maxBoxSize: 32
            )
        }
        
        os_signpost(.end, log: log, name: "Combined_NLD", signpostID: signpostID)
        
        print("Measurement completed!")
        print("Lyapunov calculations: \(lyeResults.count)")
        print("DFA calculations: \(dfaResults.count)")
        print("\nNow capture with Instruments using the Signpost regions")
    }
    
    /// 特定の関数のSIMD利用率測定
    static func measureSpecificFunctions() {
        let signpostID = OSSignpostID(log: log)
        let testData = Array(repeating: Q15(100), count: 1000)
        
        // 距離計算の測定
        os_signpost(.begin, log: log, name: "EuclideanDistance", signpostID: signpostID)
        for _ in 0..<1000 {
            _ = SIMDOptimizations.euclideanDistanceSIMD(testData, testData, dimension: 10)
        }
        os_signpost(.end, log: log, name: "EuclideanDistance", signpostID: signpostID)
        
        // 累積和の測定
        os_signpost(.begin, log: log, name: "CumulativeSum", signpostID: signpostID)
        for _ in 0..<1000 {
            _ = SIMDOptimizations.cumulativeSumSIMD(testData, mean: 0)
        }
        os_signpost(.end, log: log, name: "CumulativeSum", signpostID: signpostID)
        
        print("Specific function measurement completed!")
    }
}