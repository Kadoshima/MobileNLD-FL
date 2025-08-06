# Lyapunov指数（リアプノフ指数）

## 概要
カオス系における初期値の微小な違いが時間とともにどれだけ指数的に拡大するかを定量化する指標。正の値はカオス的振る舞いを示す。

## 基本概念

### 数学的定義
```
λ = lim(t→∞) 1/t * ln(|δx(t)|/|δx(0)|)
```
- λ: Lyapunov指数
- δx(t): 時刻tでの軌道間の距離
- δx(0): 初期の微小距離

### Rosenstein法（実装で使用）
1. **位相空間再構成**: 時系列データから高次元空間を構築
2. **最近傍探索**: 各点の最も近い点を見つける（時間的に離れた点）
3. **発散追跡**: 時間経過による距離の変化を記録
4. **線形回帰**: log(距離)の時間変化の傾きがLyapunov指数

## 実装での計算手順

### 1. 位相空間再構成
```swift
embeddings = phaseSpaceReconstruction(timeSeries, 
                                    dimension: 5,  // 埋め込み次元
                                    delay: 4)      // 時間遅れ
```

### 2. 最近傍探索（SIMD最適化）
```swift
nearestIndex = findNearestNeighbor(embeddings, 
                                  targetIndex: i,
                                  minSeparation: 10)  // 時間窓
```

### 3. 発散の追跡
```swift
for step in 1...maxSteps {
    distance = euclideanDistance(embeddings[i+step], 
                               embeddings[neighbor+step])
    logDivergences.append(log(distance))
}
```

## なぜ重要か
1. **カオス判定**: システムがカオス的か周期的かを判定
2. **予測可能性**: 長期予測の可能性を評価
3. **異常検知**: 正常な動的パターンからの逸脱を検出
4. **健康状態評価**: 生体信号の複雑性変化を捉える

## Rösslerシステムでの理論値
論文で使用したパラメータ（a=0.2, b=0.2, c=5.7）では、理論的なLyapunov指数は約0.071。