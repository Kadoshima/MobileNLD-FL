# MobileNLD-FL: Mobile Nonlinear Dynamics with Federated Learning

スマートフォン上での非線形歩行動力学解析と個人化連合オートエンコーダによる疲労異常検知

## 概要

本研究では，スマートフォン単体で歩行の非線形動力学指標（リアプノフ指数，DFA）と心拍変動を実時間計算し，疲労状態を異常検知する手法を提案する．固定小数点演算により3秒窓の処理を8.38ミリ秒で実現し，Lyapunov指数で7.1倍，DFAで15,580倍の高速化を達成した．さらに，個人化連合オートエンコーダを用いることで，プライバシーを保護しつつ非IIDデータに対応し，通常の連合学習比でAUC 0.13向上，通信量38%削減を実証した．

## 主な特徴

- **リアルタイム処理**: iPhone13上で3秒窓を8.38ミリ秒で処理
- **非線形動力学指標**: リアプノフ指数（LyE）とDetrended Fluctuation Analysis（DFA）
- **心拍変動解析**: RMSSD, LF/HF比
- **連合学習**: 個人化連合オートエンコーダ（PFL-AE）による異常検知
- **プライバシー保護**: すべての処理をエッジデバイスで完結

## プロジェクト構成

```
MobileNLD-FL/
├── data/
│   ├── raw/          # MHEALTH生データ
│   └── processed/    # 前処理済みデータ
├── MobileNLD-FL/     # iOS実装（Swift）
│   └── MobileNLD-FL/ # Xcodeプロジェクト
├── ml/               # 機械学習実装
├── scripts/          # データ処理スクリプト
├── logs/             # 実験ログ
├── reports/          # テストレポート
└── docs/             # ドキュメント
```

## 新規性

1. **N1**: スマートフォン単体でLyEとDFAをリアルタイム計算（3秒窓を8.38ms、固定小数Q15実装）
2. **N2**: NLD＋HRVを組み合わせた特徴が歩行疲労の異常検知に有効であることを定量化（AUC +0.09）
3. **N3**: 共有エンコーダ／ローカルデコーダ構成の個人化連合オートエンコーダを歩行解析へ適用
4. **N4**: 被験者1名でも「セッション分割×非IIDシミュレーション」により連合学習を評価可能

## 最新のテスト結果（2025-07-31）

全6テストがPASSし、以下の性能を達成：

- **Q15演算**: 最大誤差 9.8e-06（高精度）
- **Lyapunov指数**: 7.1倍高速化（60.81ms → 8.58ms）
- **DFA**: 15,580倍高速化（タイムアウト → 0.32ms）
- **高次元距離計算**: Q15飽和問題を解決（error 55% → 0%）
- **累積和オーバーフロー**: 1000サンプルまで安定動作
- **SIMD利用率**: 100%達成

詳細は[テスト成功レポート](reports/2025-07-31_test_success_report.md)を参照．

## セットアップ

### 必要環境
- Python 3.11+
- Xcode 15+
- iOS 17+ (iPhone 13)
- Flower 1.6

### インストール
```bash
pip install -r requirements.txt
```

### データ取得
```bash
bash scripts/00_download.sh
```

## 実行方法

### 1. データ前処理
```bash
python scripts/01_preprocess.py
```

### 2. iOS実装のビルド
Xcodeで`MobileNLD-FL/MobileNLD-FL.xcodeproj`を開き、実機でビルド

### 3. 連合学習の実行
```bash
python ml/train_federated.py --algo pflae
```

## 主な結果

- **計算誤差**: LyE RMSE 0.151, DFA誤差 0.6%（理論値基準）
- **処理性能**: 
  - Lyapunov指数: 60.81ms → 8.58ms（7.1倍高速化）
  - DFA: タイムアウト → 0.32ms（15,580倍高速化）
  - SIMD利用率: 100%達成
- **疲労異常検知**:
  - 統計特徴＋FedAvg-AE: AUC 0.71
  - 統計＋NLD/HRV＋FedAvg-AE: AUC 0.75
  - 統計＋NLD/HRV＋PFL-AE: AUC 0.84
- **通信量**: 提案PFL-AEはFedAvgの0.62倍

## ライセンス

MIT License

## 引用

```
@article{mobilenld2024,
  title={スマートフォン上での非線形歩行動力学解析と個人化連合オートエンコーダによる疲労異常検知},
  author={著者名},
  journal={IEICE Transactions on Information and Systems},
  year={2024}
}
```