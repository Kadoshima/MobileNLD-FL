# Nordic PPK2 電力測定手順書

## 概要
Nordic Power Profiler Kit II (PPK2)を使用してnRF52の消費電力を測定します。
- **測定モード**: Source Mode (電源供給しながら測定)
- **電圧**: 3.0V
- **サンプリング**: 10ksps
- **所要時間**: 2-3時間（セットアップ含む）

## 必要機材
- [ ] Nordic PPK2本体
- [ ] USB-A to USB-Cケーブル（PPK2付属）
- [ ] ジャンパーワイヤー（2本）
- [ ] PC（Windows/Mac/Linux）
- [ ] nRF52840 DK

## Step 1: ソフトウェアインストール

### 1.1 nRF Connect for Desktop
1. [Nordic公式](https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-Desktop)からダウンロード
2. インストール（デフォルト設定でOK）

### 1.2 Power Profiler アプリ
1. nRF Connect for Desktopを起動
2. "Power Profiler"を検索
3. "Install"をクリック
4. インストール完了後、"Open"

## Step 2: ハードウェア接続

### 2.1 PPK2の準備
```
PPK2の端子配置:
+--------+--------+--------+
| VOUT   | GND    | VIN    |  <- 上段（Source Mode用）
+--------+--------+--------+
| VOUT   | GND    |        |  <- 下段（Ampere Meter Mode用）
+--------+--------+--------+
```

### 2.2 nRF52 DKとの接続

**重要**: DKの電源スイッチをOFFにしてから接続

1. **PPK2をSource Modeに設定**
   - PPK2のスイッチを"Source Meter"側に

2. **配線接続**
   ```
   PPK2 (上段)        nRF52 DK
   -----------        ---------
   VOUT  ─────────>   P20 (VDD)
   GND   ─────────>   GND
   ```

3. **DKの電源設定**
   - SW9 (nRF power source)を"USB"から"VDD"に切り替え
   - これによりPPK2からの給電に切り替わる

### 2.3 USB接続
1. PPK2をPCにUSB接続
2. nRF52 DKもPCにUSB接続（J-Link用、給電はしない）

## Step 3: Power Profiler設定

### 3.1 基本設定
1. Power Profilerアプリを開く
2. PPK2デバイスを選択
3. 設定パラメータ:
   ```
   Mode: Source Meter
   Supply voltage: 3000 mV (3.0V)
   Current limit: 500 mA
   Sample rate: 100000 (100ksps推奨、10kspsでも可)
   ```

### 3.2 測定開始前の確認
1. "Enable power output"をON
2. 電流値が表示されることを確認（アイドル時: 約5-10mA）
3. nRF52 DKのLEDが点灯することを確認

## Step 4: 測定実行

### 4.1 ベースライン測定（固定100ms広告）

1. **ファームウェア書き込み**
   ```bash
   # 固定100ms広告のファームウェアを書き込み
   nrfjprog --program firmware_fixed_100ms.hex --sectorerase --verify
   nrfjprog --reset
   ```

2. **測定開始**
   - Power Profilerで"Start"ボタンをクリック
   - 5分間測定（安定した波形を取得）

3. **波形の確認**
   - 周期的な電流スパイク（広告パケット送信）が見える
   - ズームして個々のスパイクを確認
   ```
   期待される波形:
   ┌─┐   ┌─┐   ┌─┐
   │ │   │ │   │ │  <- 広告スパイク（~8-15mA）
   ┘ └───┘ └───┘ └─  <- アイドル（~5μA）
     100ms  100ms
   ```

4. **データ保存**
   - "Stop"をクリック
   - File → Export → CSV
   - ファイル名: `ppk2_20241217_120000Z_S01_Fixed-100ms_001.csv`

### 4.2 測定データの内容

CSVフォーマット:
```csv
Time(s),Current(uA)
0.000000,5234.567
0.000010,5245.123
0.000020,5256.789
...
```

## Step 5: データ解析

### 5.1 基本統計量の算出

Pythonスクリプト例:
```python
import pandas as pd
import numpy as np

# Load PPK2 CSV
df = pd.read_csv('ppk2_data.csv')

# Convert to mA
df['Current(mA)'] = df['Current(uA)'] / 1000

# Calculate statistics
avg_current = df['Current(mA)'].mean()
peak_current = df['Current(mA)'].max()
min_current = df['Current(mA)'].min()

# Calculate energy
voltage = 3.0  # V
avg_power = avg_current * voltage  # mW
duration = df['Time(s)'].max() - df['Time(s)'].min()
energy = avg_power * duration / 3600  # mWh

print(f"Average Current: {avg_current:.3f} mA")
print(f"Peak Current: {peak_current:.3f} mA")
print(f"Average Power: {avg_power:.3f} mW")
print(f"Energy (5min): {energy:.3f} mWh")
```

### 5.2 広告間隔の検出

```python
# Detect advertising peaks
threshold = avg_current + (peak_current - avg_current) * 0.5
peaks = df[df['Current(mA)'] > threshold]

# Calculate intervals
if len(peaks) > 1:
    intervals = np.diff(peaks['Time(s)'].values)
    avg_interval = np.mean(intervals) * 1000  # ms
    print(f"Average advertising interval: {avg_interval:.1f} ms")
```

## Step 6: 複数条件での測定

### 測定条件リスト
1. Fixed-100ms（ベースライン）
2. Fixed-200ms
3. Fixed-500ms
4. Adaptive（100-2000ms可変）

各条件で20分測定を実施:
```bash
# 測定スクリプト例
#!/bin/bash
CONDITIONS=("Fixed-100ms" "Fixed-200ms" "Fixed-500ms" "Adaptive")
DURATION=1200  # 20 minutes in seconds

for CONDITION in "${CONDITIONS[@]}"; do
    echo "Testing: $CONDITION"
    
    # Flash firmware
    nrfjprog --program "firmware_${CONDITION}.hex" --sectorerase --verify
    nrfjprog --reset
    
    # Wait for stabilization
    sleep 5
    
    # Note: Manual measurement in Power Profiler
    echo "Start measurement in Power Profiler"
    echo "Duration: $DURATION seconds"
    echo "Save as: ppk2_$(date +%Y%m%d_%H%M%S)_S01_${CONDITION}_001.csv"
    
    # Wait for measurement
    sleep $DURATION
    
    echo "Stop measurement and save CSV"
    read -p "Press Enter when ready for next condition..."
done
```

## トラブルシューティング

### PPK2が認識されない
- USB-Cケーブルを確認（データ転送対応か）
- 別のUSBポートを試す
- nRF Connect for Desktopを再起動

### 電流値が0または異常に高い
- 配線を確認（VOUT→VDD、GND→GND）
- DKのスイッチSW9が"VDD"側か確認
- Current limitを1000mAに増やしてみる

### 波形にノイズが多い
- サンプリングレートを下げる（10ksps）
- 配線を短くする
- USB延長ケーブルを使わない

### CSVエクスポートできない
- 測定を停止してからエクスポート
- ディスク容量を確認（長時間測定は大容量）

## 完了チェックリスト

- [ ] PPK2とnRF Connect for Desktopインストール完了
- [ ] PPK2とnRF52 DKの配線完了
- [ ] Source Mode 3.0Vで給電確認
- [ ] 固定100ms広告の波形取得
- [ ] CSVエクスポート成功
- [ ] 平均電流値の算出（期待値: 約50-200μA）
- [ ] 広告間隔の確認（100±5ms）

## データ品質基準

良好なデータの条件:
- 測定時間: 最低5分以上
- サンプリング: 10ksps以上
- 電流範囲: 5μA～20mA
- 広告間隔の変動: ±5%以内
- ノイズレベル: ピーク値の5%未満

## 次のステップ
1. 全条件での測定完了
2. 電力削減率の算出
3. 統計的有意性の検証

---
作成日: 2024-12-17
プロジェクト: BLE適応広告制御による省電力HAR