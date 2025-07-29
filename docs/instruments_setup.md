# Instruments計測セットアップガイド (Day 3)

## 目標
- iPhone13実機での電力測定とパフォーマンス計測
- 5分間連続ベンチマークでのEnergy Impact測定
- Points of Interestによる詳細分析

## 必要環境
- **デバイス**: iPhone 13 (iOS 17+)
- **Xcode**: 15.0+
- **macOS**: Sonoma 14.0+
- **ケーブル**: Lightning/USB-C (データ転送対応)

## セットアップ手順

### 1. iPhone13の準備

```bash
# iPhone設定
1. 設定 > デベロッパ > Point of Interest Logging を有効
2. 設定 > バッテリー > バッテリーの状態で最大容量確認
3. 設定 > 一般 > ストレージで十分な空き容量確認
4. 機内モード OFF、Wi-Fi ON (安定した通信環境)
```

### 2. Xcodeプロジェクトの設定

```swift
// 既に実装済み
// PerformanceBenchmark.swift に以下が含まれている:
// - OSLog subsystem設定
// - Signpost ID設定  
// - Points of Interest埋め込み
```

### 3. Instrumentsの起動と設定

#### Step 1: Instrumentsを開く
```bash
# Xcodeから
Product > Profile (⌘+I)

# または直接起動
open -a Instruments
```

#### Step 2: テンプレート選択
1. **Energy Log** テンプレートを選択
2. 対象デバイス: iPhone13を選択
3. アプリ: MobileNLD-FLを選択

#### Step 3: 追加計測設定
```
1. + ボタンで以下を追加:
   - Time Profiler (CPU使用率)
   - Activity Monitor (メモリ使用量)
   - Points of Interest (カスタムログ)

2. 計測時間設定:
   - Duration: 6分 (5分ベンチマーク + 1分バッファ)
   - Sample Rate: High Frequency
```

## 計測実行手順

### Phase 1: 準備
```bash
1. iPhone13をLightningケーブルでMacに接続
2. MobileNLD-FLアプリをiPhone13にビルド・インストール
3. Instrumentsでプロファイリング開始
4. アプリを起動し、「5-Min Instruments Benchmark」ボタンを確認
```

### Phase 2: ベンチマーク実行
```bash
1. Instruments記録開始 (赤い●ボタン)
2. iPhone画面で「5-Min Instruments Benchmark」をタップ
3. 5分間の自動ベンチマーク実行を待機
4. 完了後、Instruments記録停止
```

### Phase 3: データ分析
```bash
1. Energy Log:
   - Average Energy Impact を確認
   - Peak Energy Usage を記録
   - Battery Drain Rate を測定

2. Points of Interest:
   - WindowProcessing の時間分布
   - LyapunovCalculation の個別性能
   - DFACalculation の処理時間

3. Time Profiler:
   - CPU使用率の推移
   - ホットスポット関数の特定
```

## 期待される結果

### パフォーマンス目標
- **処理時間**: 3秒窓 < 4ms (目標達成率 > 95%)
- **CPU使用率**: < 30% (平均)
- **メモリ使用量**: < 50MB
- **Energy Impact**: Low レベル維持

### Points of Interest 分析
```
WindowProcessing:
├── LyapunovCalculation: ~2.5ms
├── DFACalculation: ~1.2ms  
└── Total: ~4.0ms (目標値)
```

## データエクスポート

### CSV出力
```bash
# アプリ内で自動生成される
/Documents/benchmark_results.csv

# 内容:
iteration,timestamp,processing_time_ms,target_met,cpu_usage,memory_mb
```

### Instruments データ
```bash
# Instrumentsから手動エクスポート
File > Export > Data...
Format: CSV または JSON
```

## 図表生成 (論文用)

### 自動生成される図表
1. **time_hist.pdf**: 処理時間ヒストグラム
2. **performance_timeline.pdf**: 5分間の性能推移
3. **speedup_comparison.pdf**: Python比較バーチャート
4. **energy_efficiency.pdf**: エネルギー効率スキャッタープロット

### Python実行
```bash
# アプリから生成されるスクリプトを実行
cd /Documents/
python3 generate_figures.py

# 出力: figs/*.pdf (論文品質)
```

## トラブルシューティング

### 問題1: デバイス認識されない
```bash
解決策:
1. ケーブル接続確認
2. iPhone「このコンピュータを信頼」を選択
3. Xcodeでデバイス登録確認
```

### 問題2: Points of Interest表示されない
```bash
解決策:
1. iPhone設定 > デベロッパ > Point of Interest Logging 有効化
2. アプリを一度終了・再起動
3. Instrumentsテンプレートに「Points of Interest」が含まれているか確認
```

### 問題3: Energy Impact が High表示
```bash
原因と対策:
1. バックグラウンドアプリを終了
2. 画面輝度を50%に設定
3. 他の高負荷アプリを停止
4. iPhoneを充電器から外して測定
```

## 成功基準

### ✅ 計測成功の指標
- [x] 5分間連続動作 (300回処理完了)
- [x] 平均処理時間 < 4ms
- [x] 目標達成率 > 95%
- [x] Energy Impact: Low レベル
- [x] CSV/PDF出力完了

### 📊 論文用データ取得完了
- [x] 統計データ (平均・標準偏差・最大・最小)
- [x] ヒストグラム図表
- [x] 時系列性能グラフ
- [x] Python比較チャート
- [x] エネルギー効率分析

---

**次ステップ**: Day 4 - Flower連合学習実装