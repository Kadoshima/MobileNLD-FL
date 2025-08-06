# MobileNLD-FL 勉強ディレクトリ

このディレクトリには、プロジェクトで使用されている重要な概念、アルゴリズム、技術についての解説が含まれています。

## 基礎技術

1. **[Q15固定小数点演算](01_Q15固定小数点演算.md)**
   - 16ビット固定小数点形式の基礎
   - モバイル環境での重要性
   - 演算時の注意点

2. **[SIMD並列化](02_SIMD並列化.md)**
   - ARM NEONとvDSPによる並列処理
   - ループアンローリングとILP
   - 95%のSIMD利用率達成の秘訣

## 非線形動力学解析

3. **[Lyapunov指数](03_Lyapunov指数.md)**
   - カオス系の特徴量
   - Rosenstein法による実装
   - モバイルヘルスケアへの応用

4. **[DFA解析](04_DFA解析.md)**
   - 時系列の長期相関評価
   - スケーリング指数の意味
   - 生体信号解析での重要性

5. **[位相空間再構成](06_位相空間再構成.md)**
   - Takensの埋め込み定理
   - パラメータ選択の指針
   - 非線形解析の前処理

## システム設計

6. **[動的調整システム](05_動的調整システム.md)**
   - Monitor→Scale→Processアーキテクチャ
   - 多段階スケーリング戦略
   - 実装での課題と限界

## 最適化技術

7. **[vDSPフレームワーク](08_vDSPフレームワーク.md)**
   - Appleの高速信号処理ライブラリ
   - 主要な関数と使用例
   - パフォーマンスの秘密

8. **[最適化分析](07_最適化分析.md)**
   - 実験結果の分析
   - 動的調整の効果が限定的だった理由
   - 改善提案

## 学習の進め方

### 初心者向け
1. Q15固定小数点演算から始める
2. Lyapunov指数とDFAで非線形解析を理解
3. SIMD並列化で高速化の基礎を学ぶ

### 実装者向け
1. vDSPフレームワークの使い方を習得
2. 動的調整システムの設計思想を理解
3. 最適化分析で改善点を把握

### 研究者向け
1. 位相空間再構成の理論的背景
2. 各手法の数学的基礎
3. モバイル環境特有の制約と対策

## キーワード一覧

- **Q15**: 16ビット固定小数点形式
- **SIMD**: Single Instruction Multiple Data
- **ILP**: Instruction Level Parallelism
- **vDSP**: Vector Digital Signal Processing
- **Lyapunov exponent**: リアプノフ指数
- **DFA**: Detrended Fluctuation Analysis
- **Phase space**: 位相空間
- **Takens' theorem**: ターケンスの定理
- **Rössler system**: レスラー系
- **NEON**: ARMのSIMD拡張命令セット
- **Accelerate**: Appleの数値計算フレームワーク
- **Overflow/Underflow**: オーバーフロー/アンダーフロー
- **RMS**: Root Mean Square（二乗平均平方根）
- **Embedding dimension**: 埋め込み次元
- **Time delay**: 時間遅れ
- **Scaling exponent**: スケーリング指数
- **Cumulative sum**: 累積和
- **Linear regression**: 線形回帰
- **Cache efficiency**: キャッシュ効率
- **Pipeline stall**: パイプラインストール