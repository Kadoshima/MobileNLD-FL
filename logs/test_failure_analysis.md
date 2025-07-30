# テスト失敗の原因分析

## 発生日時: 2025-07-31

## テスト結果サマリー
- **合格**: 3/6 テスト
- **失敗**: Lyapunov指数、DFA、高次元距離計算

## 失敗したテストの詳細分析

### 1. Lyapunov指数計算の問題

#### 症状
- **Original**: 2.4764084e-05（ほぼゼロ）
- **Optimized**: -0.07554952（負の値）
- **期待値**: 0.15
- **エラー**: 0.226（期待値から大幅に乖離）

#### 原因分析
1. **テスト信号の問題**
   - 単純な正弦波では非線形性が不足
   - カオス的振る舞いが生成されていない
   
2. **アルゴリズムの問題**
   - サンプリング率が過度（200点制限）
   - 近傍探索の範囲が狭すぎる可能性

### 2. DFA計算の問題

#### 症状
- **Optimized**: 1.3264（期待値1.0から32%乖離）
- **処理時間**: 0.32ms（異常に速い）
- **Original**: 5秒でタイムアウト

#### 原因分析
1. **1/fノイズ生成の問題**
   ```swift
   // 現在の実装
   noise[i] = noise[i-1] * 0.9 + noise[i] * 0.1
   ```
   - フィルタ係数が不適切
   - 真の1/fノイズになっていない

2. **ボックスサイズの問題**
   - 最大32に制限（本来64必要）
   - ボックス数が少なすぎて精度低下

### 3. 高次元距離計算の致命的エラー

#### 症状
- **全次元で99.99%以上のエラー**
- **計算結果**: 0.00006（期待値の0.003%）
- **スケーリングが完全に間違っている**

#### 原因分析 - これが最も深刻
```swift
// 問題のコード
return Q15(sqrt(Double(sum)) / Double(1 << 15))
```

**根本原因**: Q15形式での距離表現の限界
- sqrt(sum)は大きな値（例: 1000）
- これを32768で割ると0.03程度
- Q15の表現範囲（-1.0〜1.0）に収まらない

#### 正しい実装
```swift
// 距離をFloat で返すべき
static func euclideanDistanceSIMD(...) -> Float {
    // ...
    return Float(sqrt(Double(sum))) / Float(1 << 15)
}
```

## 優先度順の修正案

### 1. 高次元距離計算の修正（最優先）
```swift
// SIMDOptimizations.swift
static func euclideanDistanceSIMD(_ a: UnsafePointer<Q15>, 
                                 _ b: UnsafePointer<Q15>, 
                                 dimension: Int) -> Float {  // 戻り値をFloatに
    // ... 計算 ...
    // Q15同士の差分の二乗和なので、スケーリングを考慮
    return sqrt(Float(sum)) / Float(1 << 15)
}
```

### 2. テスト信号の改善
```swift
// より現実的なカオス信号
static func generateChaoticSignal(length: Int) -> [Q15] {
    var x: Float = 0.1
    var y: Float = 0.0
    var z: Float = 0.0
    let dt: Float = 0.01
    
    var signal: [Float] = []
    
    // Lorenzアトラクタ
    for _ in 0..<length {
        let dx = 10.0 * (y - x) * dt
        let dy = (x * (28.0 - z) - y) * dt
        let dz = (x * y - 8.0/3.0 * z) * dt
        
        x += dx
        y += dy
        z += dz
        
        signal.append(x)
    }
    
    // 正規化してQ15へ
    return FixedPointMath.floatArrayToQ15(normalizeSignal(signal))
}
```

### 3. 1/fノイズ生成の修正
```swift
static func generateOneFNoise(length: Int) -> [Float] {
    var noise = [Float](repeating: 0, count: length)
    
    // Pink noise generation using multiple white noise sources
    var b0: Float = 0, b1: Float = 0, b2: Float = 0
    var b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    
    for i in 0..<length {
        let white = Float.random(in: -1...1)
        
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        
        noise[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
    }
    
    return normalizeSignal(noise)
}
```

## 影響と重要性

### 最も深刻な問題
**高次元距離計算のスケーリングエラー**
- Lyapunov指数計算の基礎となる距離計算が完全に間違っている
- これが他のテスト失敗の根本原因の可能性

### 論文への影響
1. **正直に記載すべき課題**
   - Q15形式の表現範囲の限界
   - Float型とのハイブリッド実装の必要性

2. **改善後の再測定が必須**
   - 修正後の性能を正確に測定
   - 理論値との比較を再実施

## 結論

テスト失敗の主因は：
1. **距離計算の戻り値型の誤り**（Q15→Float必須）
2. **テスト信号の品質**（真のカオス/1fノイズ必要）
3. **過度な最適化によるアルゴリズムの劣化**

特に距離計算は、すべての非線形解析の基礎となるため、この修正は必須です。