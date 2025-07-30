# デバッグログ追加完了

## 実施日時: 2025-07-31
## 目的: euclideanDistanceSIMD の dimension=10 エラーの詳細調査

## 追加したデバッグログ

### 1. 関数開始時
```swift
#if DEBUG
print("    [euclideanDistanceSIMD] dimension=\(dimension)")
print("    [euclideanDistanceSIMD] unrolledIterations=\(unrolledIterations)")
#endif
```

### 2. SIMD8処理
```swift
#if DEBUG
print("    [euclideanDistanceSIMD] Starting SIMD8 processing at i=\(i)")
print("    [euclideanDistanceSIMD] Processing SIMD8 at i=\(i)")
print("    [euclideanDistanceSIMD] SIMD8 partial sum=\(partialSum), sum0=\(sum0)")
#endif
```

### 3. スカラー処理
```swift
#if DEBUG
print("    [euclideanDistanceSIMD] After SIMD: sum0=\(sum0), sum1=\(sum1), sum2=\(sum2), sum3=\(sum3)")
print("    [euclideanDistanceSIMD] Combined sum before scalar=\(sum)")
print("    [euclideanDistanceSIMD] Starting scalar processing at i=\(i), remaining=\(dimension-i)")
print("    [euclideanDistanceSIMD] Scalar at i=\(i): diff=\(diff), diff²=\(diff*diff), sum=\(sum)")
#endif
```

### 4. 最終結果
```swift
#if DEBUG
print("    [euclideanDistanceSIMD] Final: sum=\(sum), scaledSum=\(scaledSum), result=\(result)")
#endif
```

## 期待されるデバッグ出力（dimension=10の場合）

```
[euclideanDistanceSIMD] dimension=10
[euclideanDistanceSIMD] unrolledIterations=0
[euclideanDistanceSIMD] Starting SIMD8 processing at i=0
[euclideanDistanceSIMD] Processing SIMD8 at i=0
[euclideanDistanceSIMD] SIMD8 partial sum=???, sum0=???
[euclideanDistanceSIMD] After SIMD: sum0=???, sum1=0, sum2=0, sum3=0
[euclideanDistanceSIMD] Combined sum before scalar=???
[euclideanDistanceSIMD] Starting scalar processing at i=8, remaining=2
[euclideanDistanceSIMD] Scalar at i=8: diff=32768, diff²=1073741824, sum=???
[euclideanDistanceSIMD] Scalar at i=9: diff=32768, diff²=1073741824, sum=???
[euclideanDistanceSIMD] Final: sum=???, scaledSum=???, result=1.4142135
```

## これにより判明すること

1. **どこで計算が失われているか**
   - SIMD8処理での sum0 の値
   - スカラー処理での加算
   - 最終的な sum の値

2. **なぜ sqrt(2) になるのか**
   - sum が 2147483648 (2×32768²) になっているか
   - それとも別の値か

3. **処理フローの確認**
   - 期待通り8要素+2要素が処理されているか
   - アキュムレータが正しく動作しているか

## 次のステップ

Debugビルドをデバイスにデプロイして、テストを実行してください。
デバッグログから、具体的にどこで問題が発生しているかが明確になります。