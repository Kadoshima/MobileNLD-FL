//
//  RunExperiment.swift
//  MobileNLD-FL
//
//  実験実行スクリプト - 実際の測定を行い、実験ディレクトリに保存
//

import Foundation

struct RunExperiment {
    
    static let experimentDir = "/Users/kadoshima/Documents/MobileNLD-FL/実験"
    
    // MARK: - Main Experiment Runner
    
    static func runAllExperiments() {
        let timestamp = DateFormatter.experimentTimestamp.string(from: Date())
        let logPath = "\(experimentDir)/logs/\(timestamp)_experiment_session.log"
        
        var log = ExperimentLog()
        log.startTime = Date()
        log.device = getDeviceInfo()
        
        print("=== MobileNLD-FL 実験セッション開始 ===")
        print("時刻: \(timestamp)")
        print("デバイス: \(log.device.model)")
        print("実験データは \(experimentDir) に保存されます")
        print("")
        
        // 1. テストデータの読み込み
        guard let testData = loadTestData() else {
            print("エラー: テストデータの読み込みに失敗しました")
            return
        }
        
        print("テストデータ読み込み完了: \(testData.count) サンプル")
        
        // 2. ウォームアップ
        print("\nウォームアップ中...")
        warmup(with: Array(testData.prefix(50)))
        
        // 3. 実験1: 基本性能測定（4構成の比較）
        print("\n--- 実験1: 基本性能測定 ---")
        let basicResults = measureBasicPerformance(testData: testData)
        saveResults(basicResults, name: "basic_performance", timestamp: timestamp)
        
        // 4. 実験2: 実際のSIMD利用率測定
        print("\n--- 実験2: SIMD利用率測定 ---")
        print("注意: 正確な測定にはInstrumentsでのプロファイリングが必要です")
        let simdResults = measureActualSIMDUtilization(testData: testData)
        saveResults(simdResults, name: "simd_utilization", timestamp: timestamp)
        
        // 5. 実験3: 近似アルゴリズムの評価
        print("\n--- 実験3: 近似最近傍探索の評価 ---")
        let approxResults = evaluateApproximateAlgorithms(testData: testData)
        saveResults(approxResults, name: "approximate_nn", timestamp: timestamp)
        
        // 6. ログの保存
        log.endTime = Date()
        log.summary = generateSummary(basicResults, simdResults, approxResults)
        saveLog(log, path: logPath)
        
        print("\n=== 実験セッション完了 ===")
        print("所要時間: \(Int(log.endTime!.timeIntervalSince(log.startTime!)))秒")
        print("ログ保存先: \(logPath)")
    }
    
    // MARK: - Individual Experiments
    
    private static func measureBasicPerformance(testData: [Q15]) -> [String: Any] {
        var results: [String: Any] = [:]
        let dataSizes = [50, 100, 200, 500, 1000]
        let implementations = ["scalar", "simd_only", "adaptive_only", "proposed"]
        
        var allMeasurements: [[String: Any]] = []
        
        for size in dataSizes {
            guard size <= testData.count else { continue }
            let data = Array(testData.prefix(size))
            
            print("  データサイズ: \(size)")
            
            for impl in implementations {
                let measurement = measureSingleImplementation(
                    data: data,
                    implementation: impl,
                    iterations: 10
                )
                
                var record = measurement
                record["data_size"] = size
                record["implementation"] = impl
                allMeasurements.append(record)
                
                print("    \(impl): \(String(format: "%.2f", measurement["avg_time_ms"] as? Double ?? -1))ms")
            }
        }
        
        results["measurements"] = allMeasurements
        results["timestamp"] = Date()
        
        return results
    }
    
    private static func measureSingleImplementation(
        data: [Q15],
        implementation: String,
        iterations: Int
    ) -> [String: Any] {
        
        var times: [Double] = []
        
        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            
            let result: Float
            switch implementation {
            case "scalar":
                result = NonlinearDynamicsScalar.lyapunovExponentScalar(data)
            case "simd_only":
                result = NonlinearDynamicsSIMDOnly.lyapunovExponentSIMDOnly(data)
            case "adaptive_only":
                result = NonlinearDynamicsAdaptiveOnly.lyapunovExponentAdaptive(data)
            case "proposed":
                result = NonlinearDynamics.lyapunovExponent(data)
            default:
                result = 0
            }
            
            let time = (CFAbsoluteTimeGetCurrent() - start) * 1000
            times.append(time)
        }
        
        // 統計計算
        let avgTime = times.reduce(0, +) / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        let stdDev = calculateStandardDeviation(times)
        
        return [
            "avg_time_ms": avgTime,
            "min_time_ms": minTime,
            "max_time_ms": maxTime,
            "std_dev_ms": stdDev,
            "iterations": iterations,
            "result_value": 0  // 実際の計算結果も保存可能
        ]
    }
    
    private static func measureActualSIMDUtilization(testData: [Q15]) -> [String: Any] {
        // 実際のSIMD利用率はInstrumentsで測定する必要があるため、
        // ここでは処理時間のみを測定
        
        print("  実測にはInstrumentsを使用してください")
        print("  Xcode > Product > Profile > Time Profiler")
        
        let measurements = RealisticSIMDMeasurement.measurementConfigs.map { config in
            let data = Array(testData.prefix(config.dataLength))
            
            let start = CFAbsoluteTimeGetCurrent()
            _ = NonlinearDynamics.lyapunovExponent(data, embeddingDim: config.embeddingDimension)
            let time = (CFAbsoluteTimeGetCurrent() - start) * 1000
            
            return [
                "data_length": config.dataLength,
                "embedding_dim": config.embeddingDimension,
                "expected_cache": config.expectedCacheLevel,
                "processing_time_ms": time,
                "simd_utilization": -1.0  // Instrumentsで測定
            ]
        }
        
        return ["measurements": measurements]
    }
    
    private static func evaluateApproximateAlgorithms(testData: [Q15]) -> [String: Any] {
        let embeddingDim = 5
        let delay = 4
        let testSize = 500
        
        guard testSize <= testData.count else { return [:] }
        
        // 位相空間再構成
        let timeSeries = Array(testData.prefix(testSize))
        let numPoints = timeSeries.count - (embeddingDim - 1) * delay
        var phaseSpace: [[Q15]] = []
        
        for i in 0..<numPoints {
            var embedding: [Q15] = []
            for j in 0..<embeddingDim {
                embedding.append(timeSeries[i + j * delay])
            }
            phaseSpace.append(embedding)
        }
        
        // 比較実験
        let comparison = ApproximateNearestNeighbor.comparePerformance(
            phaseSpace: phaseSpace,
            sampleIndices: Array(0..<min(10, phaseSpace.count))
        )
        
        return [
            "exact_time_ms": comparison.exactAverageTimeMs,
            "grid_time_ms": comparison.gridAverageTimeMs,
            "lsh_time_ms": comparison.lshAverageTimeMs,
            "grid_speedup": comparison.gridSpeedup,
            "lsh_speedup": comparison.lshSpeedup,
            "grid_accuracy": comparison.gridAverageAccuracy,
            "lsh_accuracy": comparison.lshAverageAccuracy
        ]
    }
    
    // MARK: - Helper Functions
    
    private static func loadTestData() -> [Q15]? {
        let path = "\(experimentDir)/raw_data/rossler_data/rossler_q15.csv"
        
        guard let csvData = try? String(contentsOfFile: path) else {
            return nil
        }
        
        let lines = csvData.components(separatedBy: .newlines)
        guard lines.count > 1 else { return nil }
        
        var q15Data: [Q15] = []
        
        // ヘッダーをスキップして、x_q15列を読み込む
        for i in 1..<lines.count {
            let values = lines[i].components(separatedBy: ",")
            if values.count > 1, let xQ15 = Int16(values[1]) {
                q15Data.append(xQ15)
            }
        }
        
        return q15Data
    }
    
    private static func warmup(with data: [Q15]) {
        for _ in 0..<5 {
            _ = NonlinearDynamics.lyapunovExponent(data)
        }
    }
    
    private static func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: "iPhone/Mac",  // 実際にはsysctlで取得
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            memory: ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        )
    }
    
    private static func saveResults(_ results: Any, name: String, timestamp: String) {
        let filename = "\(experimentDir)/results/\(timestamp)_\(name).json"
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: filename))
            print("  結果を保存: \(filename)")
        } catch {
            print("  エラー: 結果の保存に失敗 - \(error)")
        }
    }
    
    private static func saveLog(_ log: ExperimentLog, path: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(log)
            try data.write(to: URL(fileURLWithPath: path))
        } catch {
            print("ログ保存エラー: \(error)")
        }
    }
    
    private static func generateSummary(_ results: Any...) -> String {
        return "実験完了 - 詳細は個別の結果ファイルを参照"
    }
    
    private static func calculateStandardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}

// MARK: - Supporting Types

struct ExperimentLog: Codable {
    var startTime: Date?
    var endTime: Date?
    var device: DeviceInfo
    var conditions: [String: Any]?
    var summary: String?
    
    init() {
        self.device = DeviceInfo(model: "", os: "", memory: 0)
    }
    
    enum CodingKeys: String, CodingKey {
        case startTime, endTime, device, summary
    }
}

struct DeviceInfo: Codable {
    let model: String
    let os: String
    let memory: UInt64  // GB
}

// DateFormatter.experimentTimestamp is defined in ExperimentView.swift