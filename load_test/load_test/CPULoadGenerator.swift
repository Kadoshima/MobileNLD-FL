import Foundation
import os

class CPULoadGenerator: ObservableObject {
    @Published var isRunning = false
    @Published var currentLoadPercent: Int = 0
    @Published var actualCPUUsage: Double = 0.0
    
    private var workItems: [DispatchWorkItem] = []
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.mobilenld.loadtest", category: "CPULoad")
    
    // 負荷レベルの定義
    enum LoadLevel: CaseIterable {
        case idle       // 0%
        case light      // 25%
        case medium     // 50%
        case heavy      // 75%
        case maximum    // 100%
        
        var targetPercent: Int {
            switch self {
            case .idle: return 0
            case .light: return 25
            case .medium: return 50
            case .heavy: return 75
            case .maximum: return 100
            }
        }
        
        var description: String {
            switch self {
            case .idle: return "Idle (0%)"
            case .light: return "Light (25%)"
            case .medium: return "Medium (50%)"
            case .heavy: return "Heavy (75%)"
            case .maximum: return "Maximum (100%)"
            }
        }
        
        var color: String {
            switch self {
            case .idle: return "green"
            case .light: return "yellow"
            case .medium: return "orange"
            case .heavy: return "red"
            case .maximum: return "purple"
            }
        }
    }
    
    func startLoad(level: LoadLevel) {
        stopLoad()
        
        isRunning = true
        currentLoadPercent = level.targetPercent
        
        logger.info("Starting CPU load: \(level.description)")
        
        // CPU使用率モニタリング開始
        startCPUMonitoring()
        
        switch level {
        case .idle:
            // アイドル状態（何もしない）
            break
            
        case .light:
            // 25%負荷：間欠的な軽い計算
            generateIntermittentLoad(dutyCycle: 0.25, intensity: .low)
            
        case .medium:
            // 50%負荷：中程度の連続計算
            generateIntermittentLoad(dutyCycle: 0.5, intensity: .medium)
            
        case .heavy:
            // 75%負荷：重い計算を高頻度で実行
            generateIntermittentLoad(dutyCycle: 0.75, intensity: .high)
            
        case .maximum:
            // 100%負荷：全コアを使用した連続計算
            generateMaximumLoad()
        }
    }
    
    func stopLoad() {
        logger.info("Stopping CPU load")
        
        isRunning = false
        currentLoadPercent = 0
        
        // すべてのワークアイテムをキャンセル
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
        
        // タイマー停止
        timer?.invalidate()
        timer = nil
    }
    
    private func generateIntermittentLoad(dutyCycle: Double, intensity: IntensityLevel) {
        let activeTime = 100.0 // 100ms active
        let totalTime = activeTime / dutyCycle
        let sleepTime = totalTime - activeTime
        
        // 利用可能なコア数を取得
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        let activeCores = Int(Double(coreCount) * dutyCycle)
        
        for i in 0..<activeCores {
            let workItem = DispatchWorkItem { [weak self] in
                while !(self?.workItems[i].isCancelled ?? true) {
                    // アクティブフェーズ
                    let endTime = Date().addingTimeInterval(activeTime / 1000.0)
                    
                    switch intensity {
                    case .low:
                        self?.performLightCalculation(until: endTime)
                    case .medium:
                        self?.performMediumCalculation(until: endTime)
                    case .high:
                        self?.performHeavyCalculation(until: endTime)
                    }
                    
                    // スリープフェーズ
                    if sleepTime > 0 {
                        Thread.sleep(forTimeInterval: sleepTime / 1000.0)
                    }
                }
            }
            
            workItems.append(workItem)
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }
    
    private func generateMaximumLoad() {
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        
        for _ in 0..<coreCount {
            let workItem = DispatchWorkItem { [weak self] in
                while !(self?.workItems.last?.isCancelled ?? true) {
                    // 最大負荷：連続的な重い計算
                    self?.performHeavyCalculation(until: Date().addingTimeInterval(1.0))
                }
            }
            
            workItems.append(workItem)
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }
    
    // MARK: - 計算負荷の実装
    
    private func performLightCalculation(until endTime: Date) {
        var result: Double = 1.0
        var counter = 0
        
        while Date() < endTime {
            // 軽い浮動小数点演算
            result = sin(Double(counter)) * cos(Double(counter))
            counter += 1
            
            // 定期的にキャンセルチェック
            if counter % 1000 == 0 && (workItems.first?.isCancelled ?? true) {
                break
            }
        }
    }
    
    private func performMediumCalculation(until endTime: Date) {
        var matrix = [[Double]](repeating: [Double](repeating: 1.0, count: 10), count: 10)
        var counter = 0
        
        while Date() < endTime {
            // 行列演算
            for i in 0..<10 {
                for j in 0..<10 {
                    matrix[i][j] = sin(Double(i * j + counter)) * exp(-Double(counter) / 1000.0)
                }
            }
            counter += 1
            
            if counter % 100 == 0 && (workItems.first?.isCancelled ?? true) {
                break
            }
        }
    }
    
    private func performHeavyCalculation(until endTime: Date) {
        var result: Double = 1.0
        var counter = 0
        
        while Date() < endTime {
            // 重い計算：素数判定のような処理
            let n = 10000 + counter % 1000
            var isPrime = true
            
            if n > 1 {
                for i in 2..<Int(sqrt(Double(n))) + 1 {
                    if n % i == 0 {
                        isPrime = false
                        break
                    }
                }
            }
            
            result = isPrime ? result * 1.01 : result * 0.99
            counter += 1
            
            if counter % 10 == 0 && (workItems.first?.isCancelled ?? true) {
                break
            }
        }
    }
    
    // MARK: - CPU使用率モニタリング
    
    private func startCPUMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
        }
    }
    
    private func updateCPUUsage() {
        // 簡易的なCPU使用率の推定
        // 実際のInstruments測定時は、Energy LogとTime Profilerで正確な値を取得
        DispatchQueue.main.async {
            self.actualCPUUsage = Double(self.currentLoadPercent) * (0.9 + Double.random(in: 0...0.2))
        }
    }
    
    enum IntensityLevel {
        case low
        case medium
        case high
    }
}

// MARK: - Signpost for Instruments
extension CPULoadGenerator {
    private static let signpostLog = OSLog(subsystem: "com.mobilenld.loadtest", category: .pointsOfInterest)
    
    func measureLoadWithSignpost(level: LoadLevel, duration: TimeInterval) {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        
        os_signpost(.begin, log: Self.signpostLog, name: "CPU Load Test", signpostID: signpostID,
                    "Load Level: %{public}s", level.description)
        
        startLoad(level: level)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stopLoad()
            
            os_signpost(.end, log: Self.signpostLog, name: "CPU Load Test", signpostID: signpostID,
                        "Completed: %{public}s", level.description)
        }
    }
}