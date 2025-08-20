# Phase 1 実現可能性検証 - STATUS

## 🎯 目標
**1-2日以内にM5StickC Plus2で基本動作確認し、削減率データを取得**

## 📊 現在の進捗

### Track 1: Firmware (M5StickC)
| タスク | ステータス | ファイル | 次のアクション |
|--------|-----------|----------|----------------|
| 環境構築 | ✅ 完了 | `docs/手順書_M5StickC_Plus2_環境構築.md` | - |
| BLE固定広告 | ✅ 完了 | `firmware/m5stick/ble_fixed_100ms/` | nRF Connectで確認 |
| IMUテスト | 🔄 **実行中** | `firmware/m5stick/imu_har_test/` | **👉 アップロードして動作確認** |
| 電力測定 | ⏳ 待機 | `firmware/m5stick/power_test/` | IMU後に実施 |

### Track 2: Phone Logger
| タスク | ステータス | ファイル | 次のアクション |
|--------|-----------|----------|----------------|
| Androidアプリ | ⏳ 待機 | `docs/手順書_Android_BLEロガー.md` | 並行で開発可能 |

## 🚀 今すぐやること

### 1. IMUテスト（30分）
```bash
# Arduino IDEで開く
firmware/m5stick/imu_har_test/imu_har_test.ino

# アップロード後、動作確認:
# - 静止 → "IDLE"表示
# - 歩行 → "ACTIVE"表示  
# - ゆっくり → "UNCERTAIN"表示

# 結果記録
./scripts/quick_test.sh  # Option 2を選択
```

### 2. 電力測定テスト（30分）
```bash
# Arduino IDEで開く
firmware/m5stick/power_test/power_test.ino

# シリアルモニタ(115200)でCSV出力確認
# 100ms vs 2000msで比較

# 結果記録
./scripts/quick_test.sh  # Option 3を選択
```

### 3. 統合テスト（1時間）
- BLE + IMU + 電力を統合
- 5分シナリオ実行
- データ収集

## 📁 重要ファイル

### コード（すべて作成済み）
- ✅ `firmware/m5stick/ble_fixed_100ms/ble_fixed_100ms.ino`
- ✅ `firmware/m5stick/imu_har_test/imu_har_test.ino`
- ✅ `firmware/m5stick/power_test/power_test.ino`

### ドキュメント
- 📖 `docs/手順書_M5StickC_Plus2_環境構築.md` - セットアップ手順
- 📝 `docs/logs/daily_log_20241217.md` - 本日の作業ログ

### ツール
- 🔧 `scripts/quick_test.sh` - テスト結果記録ヘルパー
- 🔧 `scripts/new_run.sh` - 実験Run ID生成

## 📈 期待される結果

### Phase 1完了時
- **削減率**: 10-20%（ESP32での現実的な値）
- **遅延**: p95 < 300ms
- **データ**: CSVファイル生成

### 判断基準
- 削減率 > 30% → ESP32で継続
- 削減率 < 30% → Nordic調達検討

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
**残り作業時間**: 約2-3時間でPhase 1完了可能
**ボトルネック**: Androidアプリ（並行開発推奨）