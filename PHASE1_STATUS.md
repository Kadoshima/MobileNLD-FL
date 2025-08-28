# Phase 1 実現可能性検証 - STATUS

## 🎯 目標
**1-2日以内にM5StickC Plus2で基本動作確認し、削減率データを取得**

## 📊 現在の進捗

### Track 1: Firmware (M5StickC)
| タスク | ステータス | ファイル | 次のアクション |
|--------|-----------|----------|----------------|
| 環境構築 | ✅ 完了 | `docs/手順書_M5StickC_Plus2_環境構築.md` | - |
| BLE固定広告 | ✅ 完了 | `firmware/m5stick/ble_fixed_100ms/` | - |
| IMUテスト | ✅ 完了 | `firmware/m5stick/imu_har_test/` | - |
| 適応型BLE | ✅ 完了 | `firmware/m5stick/ble_adaptive_har/` | **動作確認済み** |
| 電力測定 | ⏳ **次の作業** | `firmware/m5stick/power_test/` | **👉 AXP192実装** |

### Track 2: Phone Logger
| タスク | ステータス | ファイル | 次のアクション |
|--------|-----------|----------|----------------|
| Androidアプリ | ✅ 完了 | `mobile_app/flutter_ble_logger/` | CSV共有機能付き |

## 🚀 今すぐやること

### 1. AXP192電力測定実装（30分）
```bash
# power_test.inoにAXP192電流測定機能を追加
# - getBatteryLevel()
# - getBatteryVoltage()
# - getBatteryCurrent()
# - CSVログ出力
```

### 2. 比較実験の実施（1時間）
```bash
# 実験プロトコル:
# 1. Fixed-100ms版を15分測定
# 2. Adaptive版を15分測定（同じ活動パターン）
# 3. CSVデータを収集（電力データ + BLEログ）
# 4. 削減率を計算
```

### 3. データ解析（30分）
```bash
# Python解析スクリプトで:
# - 平均消費電流の比較
# - パケット受信間隔のp95計算
# - 削減率の統計的検証
```

## 📁 重要ファイル

### コード
- ✅ `firmware/m5stick/ble_fixed_100ms/ble_fixed_100ms.ino` - 固定間隔BLE広告
- ✅ `firmware/m5stick/imu_har_test/imu_har_test.ino` - HAR基本動作確認
- ✅ `firmware/m5stick/ble_adaptive_har/ble_adaptive_har.ino` - 適応型統合版
- ⏳ `firmware/m5stick/power_test/power_test.ino` - AXP192電力測定（要更新）
- ✅ `mobile_app/flutter_ble_logger/` - Androidロガーアプリ（CSV共有機能付き）

### ドキュメント
- 📖 `docs/手順書_M5StickC_Plus2_環境構築.md` - セットアップ手順
- 📝 `docs/logs/daily_log_20241217.md` - 本日の作業ログ

### ツール
- 🔧 `scripts/quick_test.sh` - テスト結果記録ヘルパー
- 🔧 `scripts/new_run.sh` - 実験Run ID生成

## 📈 期待される結果

### Phase 1完了時の達成状況
- ✅ **HAR実装**: 3状態分類（IDLE/ACTIVE/UNCERTAIN）動作確認済み
- ✅ **適応制御**: 不確実度ベースのBLE間隔変更（100-2000ms）実装済み
- ✅ **Androidアプリ**: BLEログ収集・CSV共有機能完成
- ⏳ **電力測定**: AXP192実装待ち
- ⏳ **削減率**: 測定データ待ち（目標30%以上）

### 次の判断基準
- 削減率 ≥ 30% → ESP32で本実験へ
- 削減率 < 30% → アルゴリズム最適化 or Nordic検討

## ⚡ コマンドまとめ

```bash
# テストヘルパー起動
./scripts/quick_test.sh

# 本日のログ確認
cat docs/logs/daily_log_20241217.md

# Run ID生成
./scripts/new_run.sh
```

---
**現在の状況**: 適応型BLE HARまで実装完了！
**残り作業**: AXP192電力測定 → 比較実験 → データ解析
**所要時間**: 約2時間でPhase 1完了可能
**最終更新**: 2025-08-20