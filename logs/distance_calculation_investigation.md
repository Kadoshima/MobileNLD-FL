# 距離計算エラー詳細調査

## 発生日時: 2025-07-31
## 問題: High-Dimensional Distance テストのみFAIL（5/6 PASS）

## テスト結果の詳細分析

### 成功したテスト ✅
1. **Q15 Arithmetic**: PASSED
2. **Lyapunov Exponent**: PASSED (RMSE 0.150)
3. **DFA**: PASSED (Large data も成功！)
4. **Cumulative Sum**: PASSED
5. **Performance Benchmark**: PASSED (9.51ms)

### 失敗したテスト ❌
**High-Dimensional Distance**: FAILED
- Dimension 5: ✅ 正しい（error 0%）
- Dimension 10: ❌ 間違い（error 55.27%）

## デバッグ出力の分析

### Dimension 5 の結果（正しい）
```
Debug: Q15 values: a=16384 (0.5), b=-16384 (-0.5), diff=1.0
Manual calculation: sum=5368709120, scaledSum=5.0, distance=2.236068
Dimension 5: distance=2.236068, expected=2.236068, error=0.0%
```
- 手動計算: sqrt(5) = 2.236... ✅
- SIMD計算: 2.236... ✅
- **完全一致**

### Dimension 10 の結果（エラー）
```
Debug: Q15 values: a=16384 (0.5), b=-16384 (-0.5), diff=1.0
Manual calculation: sum=10737418240, scaledSum=10.0, distance=3.1622777
Dimension 10: distance=1.4142135, expected=3.1622777, error=55.27864%
```
- 手動計算: sqrt(10) = 3.162... ✅
- SIMD計算: 1.414... = sqrt(2) ❌
- **なぜsqrt(2)になるのか？**

## 重要な観察

### 1. 手動計算は正しい
- sum = 10737418240 = 10 × (32768)²
- scaledSum = 10.0
- distance = sqrt(10) = 3.162...

### 2. SIMD関数の返り値が異なる
- 期待: 3.162...
- 実際: 1.414... = sqrt(2)

### 3. パターンの推測
- 1.414 = sqrt(2)
- これは何かが2倍になっている、または10が2に置き換わっている可能性

## 考えられる原因

### 1. SIMD処理でのループエラー
- dimension=10 の時、実際には2要素しか処理していない？
- ループの早期終了？

### 2. アンロール処理のバグ
```swift
// 4-way unrolling
let unrollFactor = 32
let unrolledIterations = dimension / unrollFactor
```
- dimension=10 の場合、unrolledIterations = 0
- メインループがスキップされ、残り処理だけ？

### 3. SIMD幅の問題
```swift
static let simdWidth = 8
```
- dimension=10 の時、8要素+2要素の処理
- 2要素だけが計算される？

## 追加調査が必要な点

### 1. dimension による結果の変化
現在のテスト:
- dim=5: 正しい
- dim=10: エラー（sqrt(2)）

追加すべきテスト:
- dim=2: sqrt(2)になるはず
- dim=8: 正しいはず（SIMD幅の倍数）
- dim=16: 正しいはず

### 2. euclideanDistanceSIMD の内部動作
- ループカウンタの確認
- 実際に処理される要素数
- アンロール処理の影響

## 結論

**問題は euclideanDistanceSIMD 関数内のループ処理**にある可能性が高い：

1. dimension=10 の時、なぜか2要素しか処理されていない
2. 4-way unrolling が dimension < 32 で正しく動作しない
3. 残り要素の処理に問題がある

## 推奨される次のステップ

1. euclideanDistanceSIMD にデバッグプリントを追加
2. 各ループで処理される要素数を確認
3. dimension=2, 8, 16 でのテスト追加
4. アンロール処理を一時的に無効化してテスト