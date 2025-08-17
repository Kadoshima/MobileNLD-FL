# TO DO List - BLE Adaptive Advertising Project

## 📅 Project Timeline: 6 Weeks Sprint

### Week 1-2: 環境構築 & 実装 (Environment & Implementation)

#### 🔧 環境構築 (Environment Setup)
- [ ] **nRF Connect SDK セットアップ**
  - nRF52840 DK用の開発環境
  - Zephyr RTOS or nRF SDK選択
  - J-Link debugger設定

- [ ] **Python環境構築**
  ```bash
  pip install tensorflow==2.x pandas matplotlib scikit-learn
  ```

- [ ] **Android Studio インストール・設定**
  - Kotlin環境セットアップ
  - BLE permissions設定
  - デバッグ用実機設定

#### 📊 データ準備 (Data Preparation)
- [ ] **UCI HARデータセットのダウンロード**
  ```bash
  python scripts/download_uci_har.py
  ```
  - 30人×6活動×561特徴量
  - 2クラス（Active/Idle）への変換

#### 🧠 機械学習 (Machine Learning)
- [ ] **2クラスHARモデル（Active/Idle）の学習**
  - 1D-CNN architecture
  - 入力: 100×6 (2秒@50Hz)
  - 精度目標: >95%

- [ ] **TFLite Microへの量子化**
  - INT8量子化
  - モデルサイズ: <20KB
  - C headerへの変換

### Week 2-3: ファームウェア実装 (Firmware Implementation)

#### 💻 コア機能 (Core Features)
- [ ] **IMUドライバ実装**
  - サンプリング: 50Hz
  - DMA転送設定
  - 循環バッファ (2秒分)

- [ ] **TFLite Micro推論エンジン統合**
  - メモリアロケーション最適化
  - 推論時間: <30ms目標

- [ ] **不確実度計算モジュール**
  ```c
  // エントロピーベース
  uncertainty = -Σ(p_i * log(p_i))
  ```

- [ ] **BLE適応制御**
  - 3状態: Quiet(1000-2000ms) / Uncertain(200-500ms) / Active(100-200ms)
  - ヒステリシス付き状態遷移
  - EWMA平滑化

- [ ] **UARTデバッグインターフェース**
  - リアルタイムステータス出力
  - パラメータ調整コマンド
  - 統計情報ダンプ

### Week 3-4: Android & 統合 (Android App & Integration)

#### 📱 Androidアプリ (Android Application)
- [ ] **BLEスキャナーアプリ基本実装**
  - フォアグラウンドサービス
  - 継続的スキャンモード
  - パケットパーサー

- [ ] **CSVロギング機能実装**
  - タイムスタンプ (ns精度)
  - RSSI記録
  - シーケンス番号チェック

- [ ] **リアルタイムモニタリングUI**
  - 受信パケット数/秒
  - 現在の状態表示
  - バッテリーレベル

#### 🔄 統合テスト (Integration Testing)
- [ ] **End-to-End動作確認**
  - センサー → 推論 → BLE → Android
  - 遅延測定 (<300ms)
  - パケットロス率 (<1%)

### Week 5: 実験 (Experiments)

#### 🔬 実験準備 (Experiment Preparation)
- [ ] **PPK2セットアップ・キャリブレーション**
  - 測定レンジ設定
  - サンプリングレート: 100kHz
  - 基準電流確認

- [ ] **被験者募集（3-5名）・同意書準備**
  - 実験説明書作成
  - 倫理審査（必要な場合）
  - スケジュール調整

#### 📈 実験実施 (Experiment Execution)
- [ ] **ベースライン測定**
  - Fixed 100ms: 20分×3回
  - Fixed 200ms: 20分×3回
  - Fixed 500ms: 20分×3回

- [ ] **適応制御測定**
  - 活動プロトコル: 歩行/着座/起立/階段
  - 各被験者: 20分×4条件
  - PPK2 + Androidログ同時記録

### Week 6: 解析 & 論文 (Analysis & Paper)

#### 📊 データ解析 (Data Analysis)
- [ ] **PPK2データパース・電力削減率算出**
  ```python
  reduction = (baseline_mA - adaptive_mA) / baseline_mA * 100
  ```

- [ ] **遅延分布解析**
  - p50/p95パーセンタイル
  - ヒストグラム作成
  - 状態別統計

- [ ] **統計的有意性検定**
  - paired t-test
  - p値 < 0.05
  - 効果量 (Cohen's d)

#### 📝 論文執筆 (Paper Writing)
- [ ] **図表作成**
  - Figure 1: Pareto曲線（電力 vs 精度 vs 遅延）
  - Table 1: BLE実測パラメータ
  - Figure 2: 状態遷移と電力消費

- [ ] **4ページ原稿執筆（IEICE ComEX形式）**
  - Introduction: 0.5ページ
  - Related Work: 0.3ページ
  - Proposed Method: 1.2ページ
  - Experiments: 1.5ページ
  - Conclusion: 0.5ページ

- [ ] **内部レビュー・最終校正**
  - 共著者レビュー
  - 英文校正
  - 投稿準備

## 🎯 成功基準 (Success Criteria)

### 必須達成項目
- ✅ 平均電流削減 ≥40% (vs 固定100ms)
- ✅ p95遅延 ≤300ms
- ✅ F1スコア低下 ≤1.5ポイント
- ✅ 4ページ論文完成

### 追加目標
- ⭐ オープンソース公開
- ⭐ デモ動画作成
- ⭐ 追加実験（8クラス版）

## 📅 重要マイルストーン

| 日付 | マイルストーン |
|------|---------------|
| Week 2終了 | ファームウェア動作確認 |
| Week 4終了 | システム統合完了 |
| Week 5終了 | 実験データ収集完了 |
| Week 6終了 | 論文ドラフト完成 |

## 🚨 リスク管理

### 高リスク項目
1. **BLE広告間隔の制約** → 事前検証実施
2. **メモリ不足** → 早期プロファイリング
3. **被験者不足** → 早期募集開始

### 対策
- 週次進捗レビュー
- バッファ時間の確保
- 代替案の準備

---
*Last Updated: 2024-12-17*  
*Total Tasks: 25*  
*Estimated Duration: 6 weeks*