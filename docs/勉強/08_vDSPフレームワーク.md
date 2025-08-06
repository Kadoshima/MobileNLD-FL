# vDSP (Vector Digital Signal Processing) フレームワーク

## 概要
AppleのAccelerateフレームワークの一部で、ベクトル化された信号処理関数を提供。ARM NEONやAMXを活用した高度な最適化。

## 主要な関数（実装で使用）

### ベクトル演算
```swift
// ベクトルの和
vDSP_sve(input, stride, &sum, length)

// ドット積
vDSP_dotpr(a, strideA, b, strideB, &result, length) 

// 二乗和
vDSP_svesq(input, stride, &sumOfSquares, length)

// スカラー乗算
vDSP_vsmul(vector, stride, &scalar, &result, stride, length)
```

### 統計関数
```swift
// RMS（二乗平均平方根）
vDSP_rmsqv(input, stride, &rms, length)

// 最小値・最大値
vDSP_minv(input, stride, &min, length)
vDSP_maxv(input, stride, &max, length)
```

### 型変換
```swift
// Int16 → Float変換
vDSP_vflt16(int16_input, stride, &float_output, stride, length)
```

## なぜ高速なのか

### 1. ハードウェア最適化
- ARM NEON命令を直接使用
- Apple独自のAMX（Apple Matrix coprocessor）活用
- キャッシュラインに最適化されたメモリアクセス

### 2. ループアンローリングとプリフェッチ
内部実装で高度な最適化技術を使用。

### 3. 並列処理
複数のコアを自動的に活用（大規模データの場合）。

## 実装での使用例

### 累積和計算（cumulativeSumSIMD）
```swift
// Float変換
vDSP_vflt16(inputPtr.baseAddress!, 1, &floatInput, 1, vDSP_Length(count))

// スケーリング
vDSP_vsmul(floatInput, 1, &invScale, &floatInput, 1, vDSP_Length(count))

// 平均を引く
vDSP_vsadd(floatInput, 1, &negMean, &floatInput, 1, vDSP_Length(count))

// 累積和
vDSP_vrsum(floatInput, 1, &one, &floatInput, 1, vDSP_Length(count))
```

### 線形回帰（linearRegressionSIMD）
```swift
vDSP_sve(xPtr.baseAddress!, 1, &sumX, vDSP_Length(count))    // Σx
vDSP_sve(yPtr.baseAddress!, 1, &sumY, vDSP_Length(count))    // Σy
vDSP_dotpr(xPtr.baseAddress!, 1, yPtr.baseAddress!, 1, &sumXY, vDSP_Length(count))  // Σxy
vDSP_svesq(xPtr.baseAddress!, 1, &sumX2, vDSP_Length(count)) // Σx²
```

## 注意点

### メモリアライメント
最高性能のため、16バイト境界にアラインされたメモリを使用。

### ストライド
連続メモリ（stride=1）が最も効率的。

### 精度
一部の関数は精度よりも速度を優先（要確認）。

## パフォーマンス測定
Instrumentsの"Counters"テンプレートでvDSP関数の使用率を確認可能。