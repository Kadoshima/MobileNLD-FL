# MobileNLD-FL 実験実行ガイド

## アプリ内のボタンと実行順序

### 1. 基本動作確認
**ボタン**: 「Quick Performance Test」（青色）
- **目的**: 基本的なNLD計算機能の動作確認
- **内容**: 各種テスト（Lyapunov、DFA、統計量）の実行
- **確認点**: すべてのテストがPASSすること

### 2. 速度性能比較（最重要）
**ボタン**: 「Run 4-Implementation Comparison」（オレンジ色）
- **目的**: 4つの実装の処理速度比較
- **手順**:
  1. ボタンを押してExperimentViewへ移動
  2. Data Sizeを「1000」または「2000」に設定
  3. 「Run Experiment」ボタンを押す
- **測定内容**:
  - Scalar（ベースライン）
  - SIMD Only（SIMD最適化のみ）
  - Adaptive Only（適応的最適化のみ）
  - Proposed（提案手法：両方の組み合わせ）
- **期待される結果**: SIMD Onlyが最速（NLDのSIMD非適合性により）

### 3. 精度評価（新機能）
**ボタン**: 「Accuracy vs Speed Analysis」（緑色）
- **目的**: 速度と精度のトレードオフ分析
- **手順**:
  1. ボタンを押してAccuracyComparisonViewへ移動
  2. Data Sizeを「1000」に設定
  3. 「Run Accuracy Test」ボタンを押す
- **測定内容**:
  - 処理時間（ms）
  - Lyapunov指数の計算精度
  - Trade-offスコア（速度と精度の総合評価）
- **期待される結果**: Proposedが総合的に優位

### 4. SIMD利用率測定
**ボタン**: 「Measure SIMD Performance」（紫色）
- **目的**: Instrumentsでの詳細分析の準備
- **内容**: Signpostマーカーを使った性能測定

## Instruments解析手順

### Time Profiler（実行時間分析）
1. Xcode: Product > Profile (Cmd+I)
2. 「Time Profiler」を選択
3. アプリで「Run 4-Implementation Comparison」実行（1000サンプル）
4. Call Treeで各関数の実行時間を確認

### CPU Counters（SIMD利用率測定）
1. Xcode: Product > Profile (Cmd+I)
2. 「CPU Counters」を選択
3. 同じ実験を実行
4. PMC Eventsタブで以下を確認：
   - SIMD命令数
   - 総命令数
   - SIMD利用率 = SIMD命令数 / 総命令数

### 期待されるSIMD利用率
- Scalar: 0%（定義上）
- SIMD Only: 20-30%（NLDの特性により低い）
- Adaptive: 15-25%
- Proposed: 25-35%

## 実験結果の保存場所
```
/Users/kadoshima/Documents/MobileNLD-FL/実験/results/
```

各実験結果はJSON形式で自動保存されます：
- `*_comparison_*.json`: 速度比較結果
- `*_accuracy_*.json`: 精度比較結果

## 論文への反映ポイント

1. **速度比較結果**
   - Table: 4実装の処理時間比較
   - 結論：SIMD Onlyが最速だが...

2. **精度評価結果**
   - Figure: Speed-Accuracy trade-off plot
   - 結論：Proposedが総合的に最適

3. **SIMD利用率**
   - 実測値をSection 5.4に記載
   - NLD特有の低SIMD利用率を定量的に示す

## トラブルシューティング

- **ファイル保存エラー**: 実験は正常に実行されているので無視してOK
- **0ms表示**: データサイズが小さすぎる → 1000以上を推奨
- **ビルドエラー**: Clean Build (Shift+Cmd+K) → Build (Cmd+B)

## Next Steps

1. まず速度比較（オレンジボタン）で基本性能確認
2. 次に精度分析（緑ボタン）でtrade-off確認
3. 最後にInstrumentsでSIMD利用率の実測
4. 結果をまとめて論文に反映