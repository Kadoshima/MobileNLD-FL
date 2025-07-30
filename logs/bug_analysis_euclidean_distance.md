# バグ分析: euclideanDistanceSIMD の問題

## 発見日時: 2025-07-31
## 問題: dimension=10 で sqrt(2) が返される

## 根本原因の特定

### コードの問題箇所
```swift
// Process 32 elements at a time (4x8 SIMD) for better ILP
let unrollFactor = 32
let unrolledIterations = dimension / unrollFactor
```

### 何が起きているか

1. **dimension=5 の場合**:
   - unrolledIterations = 5 / 32 = 0
   - メインループはスキップ
   - 残り処理で正しく5要素を処理
   - 結果: ✅ 正しい

2. **dimension=10 の場合**:
   - unrolledIterations = 10 / 32 = 0
   - メインループはスキップ
   - 残り処理で:
     - i=0, i+simdWidth(8) <= 10 → 8要素処理
     - i=8, i+simdWidth(8) <= 10 → **条件を満たさない！**
     - 最後の2要素だけ個別処理
   - 結果: ❌ なぜか sqrt(2) になる

### 詳細な実行フロー（dimension=10）

```
初期状態: i=0, dimension=10

1. メインループ（32要素単位）:
   - unrolledIterations = 0
   - スキップ

2. 8要素単位の処理:
   - i=0: 0+8 <= 10 ✓ → 8要素処理
   - i=8: 8+8 <= 10 ✗ → ループ終了

3. 個別要素処理:
   - i=8: 要素8を処理
   - i=9: 要素9を処理
   
合計: 8 + 2 = 10要素（正しい）
```

### しかし、なぜ sqrt(2) なのか？

可能性：
1. **SIMD処理でのバグ**: 8要素処理時に何か問題がある
2. **アキュムレータの問題**: sum0 だけが使われ、他が0のまま？
3. **スケーリングの問題**: 最終的な計算で誤りがある

### 追加の観察

```swift
// 残り要素の処理
while i < dimension {
    let diff = Int64(a[i]) - Int64(b[i])  // Use Int64 for safety
    sum += diff * diff
    i += 1
}
```

ここで `sum` に加算しているが、これは `sum0 + sum1 + sum2 + sum3` の結果。
もし sum1, sum2, sum3 が0のままなら、部分的な結果になる可能性。

## 推測される具体的なバグ

dimension=10 の時：
1. 8要素が sum0 に蓄積される
2. 残り2要素が sum に追加される
3. しかし、どこかで計算が途切れている

**sqrt(2) という結果から推測**:
- 10要素中、2要素分しか計算されていない
- または、10ではなく2で除算されている

## 解決策の提案

1. **デバッグプリントの追加**:
   - 各ループで処理される要素数
   - 各アキュムレータの値
   - 最終的な sum の値

2. **シンプルな実装でテスト**:
   - アンロールを無効化
   - 基本的なループだけで実装

3. **テストケースの追加**:
   - dimension=2（sqrt(2)になるはず）
   - dimension=8（SIMDwidth の倍数）
   - dimension=16（2×SIMDwidth）