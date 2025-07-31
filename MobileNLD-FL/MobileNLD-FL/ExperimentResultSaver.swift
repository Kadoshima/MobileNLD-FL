//
//  ExperimentResultSaver.swift
//  MobileNLD-FL
//
//  実験結果をファイルシステムに保存
//

import Foundation

struct ExperimentResultSaver {
    
    static let experimentDir = "/Users/kadoshima/Documents/MobileNLD-FL/実験"
    
    static func saveResults(_ results: [ExperimentRunner.ImplementationResult], dataSize: Int) {
        let timestamp = DateFormatter.experimentTimestamp.string(from: Date())
        let fileName = "\(timestamp)_4impl_comparison_\(dataSize).json"
        let filePath = "\(experimentDir)/results/\(fileName)"
        
        // 結果をDictionaryに変換
        let resultsDict: [String: Any] = [
            "timestamp": timestamp,
            "dataSize": dataSize,
            "device": getDeviceInfo(),
            "implementations": results.map { result in
                [
                    "name": result.implementation,
                    "avgTime": result.avgTime,
                    "minTime": result.minTime,
                    "maxTime": result.maxTime,
                    "stdDev": result.stdDev,
                    "unit": "milliseconds"
                ]
            },
            "analysis": performAnalysis(results)
        ]
        
        // JSON変換前に無限大やNaNをチェック
        let sanitizedDict = sanitizeForJSON(resultsDict)
        
        // JSONに変換して保存
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sanitizedDict, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: filePath))
            print("Results saved to: \(filePath)")
            
            // ログエントリも作成
            createLogEntry(results: results, dataSize: dataSize, timestamp: timestamp)
            
        } catch {
            print("Error saving results: \(error)")
        }
    }
    
    private static func getDeviceInfo() -> [String: Any] {
        return [
            "model": getDeviceModel(),
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "processorCount": ProcessInfo.processInfo.processorCount,
            "memory": ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024) // GB
        ]
    }
    
    private static func getDeviceModel() -> String {
        #if targetEnvironment(simulator)
        return "iOS Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #endif
    }
    
    private static func performAnalysis(_ results: [ExperimentRunner.ImplementationResult]) -> [String: Any] {
        // 基準実装（スカラー）を見つける
        guard let scalarResult = results.first(where: { $0.implementation == "Scalar" }) else {
            return [:]
        }
        
        var analysis: [String: Any] = [:]
        
        // 各実装のスピードアップを計算
        var speedups: [[String: Any]] = []
        for result in results {
            let speedup = scalarResult.avgTime / result.avgTime
            speedups.append([
                "implementation": result.implementation,
                "speedup": speedup,
                "improvement": String(format: "%.1f%%", (speedup - 1) * 100)
            ])
        }
        analysis["speedups"] = speedups
        
        // 最速実装
        if let fastest = results.min(by: { $0.avgTime < $1.avgTime }) {
            analysis["fastest"] = [
                "name": fastest.implementation,
                "time": fastest.avgTime
            ]
        }
        
        // 標準偏差の分析
        let avgStdDev = results.map { $0.stdDev }.reduce(0, +) / Double(results.count)
        analysis["avgStdDev"] = avgStdDev
        analysis["stability"] = avgStdDev < 0.5 ? "High" : "Medium"
        
        return analysis
    }
    
    private static func sanitizeForJSON(_ object: Any) -> Any {
        if let dict = object as? [String: Any] {
            var sanitized: [String: Any] = [:]
            for (key, value) in dict {
                sanitized[key] = sanitizeForJSON(value)
            }
            return sanitized
        } else if let array = object as? [Any] {
            return array.map { sanitizeForJSON($0) }
        } else if let number = object as? Double {
            if number.isInfinite {
                return "Infinity"
            } else if number.isNaN {
                return "NaN"
            } else {
                return number
            }
        } else if let number = object as? Float {
            if number.isInfinite {
                return "Infinity"
            } else if number.isNaN {
                return "NaN"
            } else {
                return number
            }
        }
        return object
    }
    
    private static func createLogEntry(results: [ExperimentRunner.ImplementationResult], dataSize: Int, timestamp: String) {
        let logFileName = "\(timestamp)_experiment_log.md"
        let logPath = "\(experimentDir)/logs/\(logFileName)"
        
        var logContent = """
        # 実験ログ: 4実装比較
        
        ## 実験情報
        - 日時: \(timestamp)
        - データサイズ: \(dataSize) サンプル
        - 反復回数: 10回/実装
        
        ## 結果サマリー
        
        | 実装 | 平均時間(ms) | 最小(ms) | 最大(ms) | 標準偏差 |
        |------|-------------|----------|----------|----------|
        """
        
        for result in results.sorted(by: { $0.avgTime < $1.avgTime }) {
            logContent += "\n| \(result.implementation) | "
            logContent += String(format: "%.2f", result.avgTime) + " | "
            logContent += String(format: "%.2f", result.minTime) + " | "
            logContent += String(format: "%.2f", result.maxTime) + " | "
            logContent += String(format: "%.2f", result.stdDev) + " |"
        }
        
        logContent += "\n\n## 分析\n"
        
        // スピードアップ計算
        if let scalarResult = results.first(where: { $0.implementation == "Scalar" }) {
            logContent += "\n### スカラー実装に対するスピードアップ:\n"
            for result in results {
                let speedup = scalarResult.avgTime / result.avgTime
                logContent += "- \(result.implementation): \(String(format: "%.2fx", speedup))\n"
            }
        }
        
        logContent += "\n## 注意事項\n"
        logContent += "- SIMD利用率の実測にはInstrumentsプロファイリングが必要\n"
        logContent += "- この測定は処理時間のみ（エネルギー消費は未測定）\n"
        
        do {
            try logContent.write(toFile: logPath, atomically: true, encoding: .utf8)
            print("Log created at: \(logPath)")
        } catch {
            print("Error creating log: \(error)")
        }
    }
}