# MobileNLD-FL API リファレンス

## 目次

- [ComprehensiveNonlinearDynamics](#comprehensivenonlineardynamics)
- [DynamicRangeMonitor](#dynamicrangemonitor)
- [AdaptiveScalingEngine](#adaptivescalingengine)
- [CrossStageCoordinator](#crossstagecoordinator)
- [データ型](#データ型)
- [列挙型](#列挙型)

---

## ComprehensiveNonlinearDynamics

包括的動的調整システムを統合した非線形動力学解析クラス。

### クラス定義

```swift
public class ComprehensiveNonlinearDynamics
```

### 初期化

#### init(signalType:)

```swift
public init(signalType: SignalType = .general)
```

**パラメータ**
- `signalType`: 信号の種類を指定（デフォルト: `.general`）

**使用例**
```swift
let nld = ComprehensiveNonlinearDynamics(signalType: .ecg)
```

### メソッド

#### lyapunovExponent(_:embeddingDim:delay:samplingRate:)

Lyapunov指数を計算します。

```swift
public func lyapunovExponent(
    _ timeSeries: [Q15],
    embeddingDim: Int = 5,
    delay: Int = 4,
    samplingRate: Int = 50
) -> (value: Float, metrics: CalculationMetrics)
```

**パラメータ**
- `timeSeries`: Q15形式の時系列データ
- `embeddingDim`: 埋め込み次元（デフォルト: 5）
- `delay`: 時間遅延（デフォルト: 4）
- `samplingRate`: サンプリングレート [Hz]（デフォルト: 50）

**戻り値**
- `value`: 計算されたLyapunov指数
- `metrics`: 計算に関するメトリクス

**使用例**
```swift
let signal = generateChaoticSignal()
let (lyapunov, metrics) = nld.lyapunovExponent(signal, 
                                               embeddingDim: 5,
                                               delay: 4,
                                               samplingRate: 256)
print("Lyapunov指数: \(lyapunov)")
print("処理時間: \(metrics.processingTime)秒")
```

#### dfaAlpha(_:minBoxSize:maxBoxSize:)

DFA（Detrended Fluctuation Analysis）のスケーリング指数αを計算します。

```swift
public func dfaAlpha(
    _ timeSeries: [Q15],
    minBoxSize: Int = 4,
    maxBoxSize: Int = 64
) -> (value: Float, metrics: CalculationMetrics)
```

**パラメータ**
- `timeSeries`: Q15形式の時系列データ
- `minBoxSize`: 最小ボックスサイズ（デフォルト: 4）
- `maxBoxSize`: 最大ボックスサイズ（デフォルト: 64）

**戻り値**
- `value`: DFAスケーリング指数（α）
- `metrics`: 計算に関するメトリクス

#### setQualityMode(_:)

処理品質モードを設定します。

```swift
public func setQualityMode(_ mode: QualityMode)
```

**パラメータ**
- `mode`: 品質モード（`.highSpeed`, `.balanced`, `.highAccuracy`）

#### getSystemStatus()

システムの現在の状態を取得します。

```swift
public func getSystemStatus() -> SystemStatus
```

**戻り値**
- `SystemStatus`: パフォーマンス統計、調整状態などを含む

### ファクトリーメソッド

#### forECG()

ECG解析に最適化されたインスタンスを生成します。

```swift
public static func forECG() -> ComprehensiveNonlinearDynamics
```

#### forEEG()

EEG解析に最適化されたインスタンスを生成します。

```swift
public static func forEEG() -> ComprehensiveNonlinearDynamics
```

#### forRealtime()

リアルタイム処理に最適化されたインスタンスを生成します。

```swift
public static func forRealtime() -> ComprehensiveNonlinearDynamics
```

---

## DynamicRangeMonitor

信号の動的レンジをリアルタイム監視し、オーバーフロー/アンダーフローのリスクを予測します。

### クラス定義

```swift
public class DynamicRangeMonitor
```

### 初期化

#### init(windowSize:)

```swift
public init(windowSize: Int = 128)
```

**パラメータ**
- `windowSize`: スライディングウィンドウのサイズ（デフォルト: 128）

### メソッド

#### monitorSample(_:)

単一サンプルを監視し、レンジ状態を返します。

```swift
@inline(__always)
public func monitorSample(_ sample: Q15) -> RangeStatus
```

**パラメータ**
- `sample`: 監視するQ15サンプル

**戻り値**
- `RangeStatus`: 現在のレンジ状態

#### monitorBatch(_:)

サンプルのバッチを効率的に監視します。

```swift
public func monitorBatch(_ samples: [Q15]) -> RangeStatus
```

#### getStatistics()

現在の信号統計を取得します。

```swift
public func getStatistics() -> SignalStatistics
```

**戻り値**
```swift
struct SignalStatistics {
    let mean: Float          // 平均値
    let variance: Float      // 分散
    let peakValue: Float     // ピーク値
    let dynamicRange: Float  // 動的レンジ
}
```

#### predictRisk(horizon:)

将来のオーバーフローリスクを予測します。

```swift
public func predictRisk(horizon: Int = 10) -> RiskPrediction
```

**パラメータ**
- `horizon`: 予測する将来のサンプル数（デフォルト: 10）

**戻り値**
```swift
struct RiskPrediction {
    let probability: Float   // リスク確率 [0.0, 1.0]
    let timeToRisk: Int     // リスクまでのサンプル数
}
```

### 静的メソッド

#### optimalMonitor(for:)

信号タイプに最適化されたモニターを作成します。

```swift
public static func optimalMonitor(for signalType: SignalType) -> DynamicRangeMonitor
```

---

## AdaptiveScalingEngine

信号特性に応じた適応的スケーリングと精度補償を実行します。

### クラス定義

```swift
public class AdaptiveScalingEngine
```

### メソッド

#### scaleSignal(_:stage:)

信号に適応的スケーリングを適用します。

```swift
public func scaleSignal(
    _ signal: [Q15], 
    stage: String = "default"
) -> (scaled: [Q15], scaleInfo: ScalingInfo)
```

**パラメータ**
- `signal`: スケーリングする信号
- `stage`: 処理ステージの識別子（デフォルト: "default"）

**戻り値**
- `scaled`: スケーリング後の信号
- `scaleInfo`: スケーリング情報（逆変換用）

#### reverseScale(_:scaleInfo:)

精度補償付きで逆スケーリングを実行します。

```swift
public func reverseScale(
    _ signal: [Q15], 
    scaleInfo: ScalingInfo
) -> [Q15]
```

#### scaleBatch(_:stage:)

複数の信号に一括でスケーリングを適用します。

```swift
public func scaleBatch(
    _ batch: [[Q15]], 
    stage: String = "default"
) -> [(scaled: [Q15], scaleInfo: ScalingInfo)]
```

#### getScalingStrategy(for:)

複数ステージの最適なスケーリング戦略を取得します。

```swift
public func getScalingStrategy(for stages: [String]) -> ScalingStrategy
```

### 静的メソッド

#### engineForNLD(type:)

特定の非線形動力学計算に最適化されたエンジンを作成します。

```swift
public static func engineForNLD(type: NLDType) -> AdaptiveScalingEngine
```

---

## CrossStageCoordinator

複数の処理ステージ間の調整と最適化を管理します。

### クラス定義

```swift
public class CrossStageCoordinator
```

### メソッド

#### processSignal(_:through:)

信号を協調パイプラインで処理します。

```swift
public func processSignal(
    _ signal: [Q15], 
    through stages: [ProcessingStage]
) -> ProcessingResult
```

**パラメータ**
- `signal`: 処理する信号
- `stages`: 処理ステージの配列

**戻り値**
```swift
struct ProcessingResult {
    let finalOutput: [Q15]
    let stageResults: [ProcessingStage: StageResult]
    let cumulativeScale: Float
    let processingChain: [ProcessingStage]
}
```

#### optimizeForAlgorithm(_:)

特定のアルゴリズムに対する最適化設定を取得します。

```swift
public func optimizeForAlgorithm(_ algorithm: NLDAlgorithm) -> AlgorithmOptimization
```

#### getCoordinationStatus()

現在の調整状態を取得します。

```swift
public func getCoordinationStatus() -> CoordinationStatus
```

---

## データ型

### Q15

16ビット固定小数点型のエイリアス。

```swift
public typealias Q15 = Int16
```

**範囲**: [-1.0, 0.999969482421875]  
**精度**: 2^-15 ≈ 0.0000305

### CalculationMetrics

計算のメトリクス情報。

```swift
public struct CalculationMetrics {
    public let processingTime: Double        // 処理時間（秒）
    public let cumulativeScale: Float        // 累積スケール係数
    public let qualityScore: Float           // 品質スコア [0.0, 1.0]
    public let stageBreakdown: [ProcessingStage: Float]  // ステージ別品質
}
```

### ScalingInfo

スケーリング情報（逆変換用）。

```swift
public struct ScalingInfo {
    public let scaleFactor: Float    // 適用されたスケール係数
    public let stage: String         // ステージ識別子
}
```

### SystemStatus

システムの状態情報。

```swift
public struct SystemStatus {
    public let performanceMetrics: PerformanceMetrics
    public let coordinationStatus: CoordinationStatus
    public let currentQualityMode: QualityMode
    public let averageProcessingTime: Double
    public let successRate: Float
}
```

---

## 列挙型

### SignalType

信号の種類。

```swift
public enum SignalType {
    case ecg          // 心電図
    case eeg          // 脳波
    case accelerometer // 加速度センサー
    case general      // 汎用
}
```

### QualityMode

処理品質モード。

```swift
public enum QualityMode {
    case highSpeed      // 高速処理優先（精度80%）
    case balanced       // バランス（精度90%）
    case highAccuracy   // 高精度優先（精度95%）
}
```

### RangeStatus

動的レンジの状態。

```swift
public enum RangeStatus: Equatable {
    case optimal(currentRange: Float)      // 最適範囲
    case nearLimit(currentRange: Float)    // 限界に近い
    case overflowRisk(scale: Float)        // オーバーフローリスク
    case underflowRisk(scale: Float)       // アンダーフローリスク
}
```

### ProcessingStage

処理ステージ。

```swift
public enum ProcessingStage: String, CaseIterable {
    case phaseSpaceReconstruction = "phase_space"
    case distanceCalculation = "distance"
    case indexCalculation = "index"
    case aggregation = "aggregation"
}
```

### NLDAlgorithm

非線形動力学アルゴリズム。

```swift
public enum NLDAlgorithm {
    case lyapunovExponent        // Lyapunov指数
    case dfa                     // DFA
    case correlationDimension    // 相関次元
}
```

### NLDType

非線形動力学計算タイプ。

```swift
public enum NLDType {
    case lyapunovExponent
    case dfa
    case correlationDimension
}
```

### ScalingHealth

スケーリングの健全性。

```swift
public enum ScalingHealth {
    case good    // 良好
    case fair    // 普通
    case poor    // 不良
}
```

---

## エラー処理

### よくあるエラー

```swift
// 信号が短すぎる場合
guard timeSeries.count >= embeddingDim * delay + 100 else {
    return (0.0, CalculationMetrics(...))  // デフォルト値を返す
}

// オーバーフローリスクが高い場合
switch rangeStatus {
case .overflowRisk(let scale):
    // 自動的にスケーリングが適用される
    print("Warning: High overflow risk, applying scale: \(scale)")
default:
    break
}
```

### エラー回復

システムは自動的にエラーを検出し、回復を試みます：

1. **数値オーバーフロー**: 自動スケーリング適用
2. **精度劣化**: 誤差補償の実行
3. **処理遅延**: 品質モードの自動調整

---

## パフォーマンスのヒント

### メモリ効率

```swift
// 大きなデータセットの場合、バッチ処理を使用
let batchSize = 1000
for i in stride(from: 0, to: data.count, by: batchSize) {
    let batch = Array(data[i..<min(i + batchSize, data.count)])
    let (result, _) = nld.lyapunovExponent(batch)
    // 結果を処理
}
```

### リアルタイム処理

```swift
// ストリーミング処理用の設定
let nld = ComprehensiveNonlinearDynamics.forRealtime()
nld.setQualityMode(.highSpeed)

// 固定サイズウィンドウで処理
var buffer = CircularBuffer<Q15>(capacity: windowSize)
```

### 精度優先

```swift
// 研究用途の高精度設定
let nld = ComprehensiveNonlinearDynamics()
nld.setQualityMode(.highAccuracy)

// 複数回実行して平均を取る
let results = (0..<5).map { _ in
    nld.lyapunovExponent(signal).value
}
let average = results.reduce(0, +) / Float(results.count)
```

---

*API バージョン: 1.0.0*  
*最終更新: 2025年7月31日*