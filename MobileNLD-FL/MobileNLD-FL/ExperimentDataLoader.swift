//
//  ExperimentDataLoader.swift
//  MobileNLD-FL
//
//  実験データ（Rösslerシステム）の読み込み
//

import Foundation

struct ExperimentDataLoader {
    
    static let shared = ExperimentDataLoader()
    
    // キャッシュされたデータ
    private var cachedData: [Q15]?
    
    // Rösslerデータを読み込む
    mutating func loadRosslerData(maxSize: Int = 1000) -> [Q15]? {
        // キャッシュがあればそれを使用
        if let cached = cachedData, cached.count >= maxSize {
            return Array(cached.prefix(maxSize))
        }
        
        // CSVファイルのパスを構築
        let experimentDir = "/Users/kadoshima/Documents/MobileNLD-FL/実験"
        let filePath = "\(experimentDir)/raw_data/rossler_data/rossler_q15.csv"
        
        do {
            let csvContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines)
            
            guard lines.count > 1 else { return nil }
            
            var q15Data: [Q15] = []
            
            // ヘッダーをスキップして、x_q15列を読み込む
            for i in 1..<lines.count {
                let values = lines[i].components(separatedBy: ",")
                if values.count > 1, let xQ15 = Int16(values[1]) {
                    q15Data.append(xQ15)
                }
                
                // 最大サイズに達したら終了
                if q15Data.count >= maxSize {
                    break
                }
            }
            
            // キャッシュに保存
            cachedData = q15Data
            
            return q15Data
            
        } catch {
            print("Warning: Could not load Rössler data from file: \(error.localizedDescription)")
            print("Using fallback generated data instead.")
            
            // フォールバック: カオス的なデータを生成
            return generateFallbackData(size: maxSize)
        }
    }
    
    // フォールバック用のランダムデータ生成
    private func generateFallbackData(size: Int) -> [Q15] {
        // カオス的な振る舞いをシミュレート
        var data: [Q15] = []
        var x: Double = 0.1
        var y: Double = 0.1
        var z: Double = 0.1
        
        let dt = 0.01
        let a = 0.2
        let b = 0.2
        let c = 5.7
        
        for _ in 0..<size {
            // Rössler方程式の簡易版
            let dx = -y - z
            let dy = x + a * y
            let dz = b + z * (x - c)
            
            x += dx * dt
            y += dy * dt
            z += dz * dt
            
            // Q15に変換（-1 to 1の範囲に正規化してから）
            let normalized = max(-1, min(1, x / 10.0))
            let q15Value = Q15(normalized * 32767)
            data.append(q15Value)
        }
        
        return data
    }
    
    // バンドル内のテストデータを読み込む（実機用）
    func loadBundledTestData() -> [Q15]? {
        guard let url = Bundle.main.url(forResource: "test_data", withExtension: "json") else {
            print("Bundled test data not found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let testData = try decoder.decode(TestData.self, from: data)
            return testData.q15Values
        } catch {
            print("Error loading bundled test data: \(error)")
            return nil
        }
    }
    
    struct TestData: Codable {
        let q15Values: [Q15]
        let normalizationParams: NormalizationParams
    }
    
    struct NormalizationParams: Codable {
        let xMin: Double
        let xMax: Double
        let yMin: Double
        let yMax: Double
        let zMin: Double
        let zMax: Double
    }
}