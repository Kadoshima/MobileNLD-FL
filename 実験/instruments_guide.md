# Instruments解析ガイド

## 解析タイミング：NOW! 

### なぜ今か
1. ✅ 基本実装完了
2. ✅ 性能測定結果あり（SIMD Onlyが最速）
3. ❓ 実際のSIMD利用率は？（推測 vs 実測）
4. ❓ ボトルネックはどこ？（キャッシュ？分岐？）

## 測定したい項目

### 1. Time Profiler
**目的**: 各関数の実行時間とホットスポット特定
```
Product > Profile (Cmd+I)
→ Time Profiler選択
→ アプリで「Run 4-Implementation Comparison」実行
→ 1000サンプルでテスト
```

**確認ポイント**:
- `lyapunovExponentSIMDOnly` vs `lyapunovExponent` の時間配分
- 最も時間がかかっている関数は？
- 予想外のオーバーヘッドは？

### 2. CPU Counters (重要！)
**目的**: SIMD利用率の実測
```
Product > Profile
→ CPU Counters選択
→ "Instructions" テンプレート
```

**測定メトリクス**:
- **SIMD Instructions**: 実際のベクトル命令数
- **Total Instructions**: 全命令数
- **SIMD利用率** = SIMD Instructions / Total Instructions

**NLD特有の注目点**:
- Phase space reconstruction: SIMD利用率低い？（予想: <10%）
- Distance calculation: SIMD利用率高い？（予想: 40-60%）
- Nearest neighbor search: SIMD利用率最低？（予想: <5%）

### 3. System Trace
**目的**: キャッシュ効率とメモリアクセスパターン
```
Product > Profile
→ System Trace選択
```

**確認項目**:
- L1/L2/L3 キャッシュミス率
- メモリ帯域使用率
- スレッド切り替えオーバーヘッド

### 4. Energy Log
**目的**: 消費電力測定（論文の追加価値）
```
Product > Profile
→ Energy Log選択
→ 実機（iPhone 13）で実行必須
```

## 実行手順

### Step 1: 準備
```swift
// ExperimentView.swiftで1000サンプル選択
// 実機をUSB接続（シミュレータではCPU Counters使えない）
```

### Step 2: Time Profilerで全体像把握
1. Profileビルド実行
2. 4実装比較を1000サンプルで実行
3. Recording停止
4. Call Treeで時間分析
5. スクリーンショット保存

### Step 3: CPU CountersでSIMD利用率測定
1. 新しいProfile実行
2. 同じテストを実行
3. "PMC Events"タブでSIMD命令数確認
4. CSVエクスポート

### Step 4: 結果分析
```python
# 実験ディレクトリに analyze_instruments.py 作成
# SIMD利用率計算
# ボトルネック特定
# 改善提案生成
```

## 期待される発見

1. **SIMD利用率の真実**
   - 予想: NLD全体で20-30%（一般的なDSPの60-80%より大幅に低い）
   - Distance計算部分のみ40-50%

2. **真のボトルネック**
   - キャッシュミス？（phase space reconstructionのランダムアクセス）
   - 分岐予測ミス？（nearest neighbor searchの条件分岐）
   - メモリ帯域？（O(n²)のメモリアクセス）

3. **Proposedメソッドの価値**
   - 適応的スケーリングでキャッシュ効率改善？
   - 近似アルゴリズムでメモリアクセス削減？

## 論文への反映

### Section 5.4 更新
```
実測SIMD利用率:
- Scalar: 0%
- SIMD Only: XX% (measured)
- Adaptive: YY%
- Proposed: ZZ%

ボトルネック分析:
- 主要因: [キャッシュミス/分岐予測/メモリ帯域]
- NLD特有の課題: データ依存性による並列化困難
```

### 新Figure追加
- SIMD utilization breakdown by function
- Cache miss rate comparison
- Energy efficiency comparison

## Next Action
1. Xcodeで `Cmd+I` → Time Profiler選択
2. iPhone実機で1000サンプルテスト実行
3. 結果をスクショ→ `/実験/instruments/` に保存
4. CPU Countersで同じ手順
5. 分析スクリプト作成