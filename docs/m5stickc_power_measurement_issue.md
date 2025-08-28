# M5StickC Plus2 電力測定問題の詳細レポート

## 問題の概要
M5StickC Plus2でバッテリー動作時の消費電流を測定しようとしているが、AXP192から正しい電流値が取得できない。USBを外してバッテリー動作にしても、電流値が常に0.0mAと表示される。

## ハードウェア環境
- **デバイス**: M5StickC Plus2
- **MCU**: ESP32-PICO-V3-02 (revision v3.1)
- **電源管理IC**: AXP192
- **バッテリー**: 135mAh内蔵
- **MAC**: f0:24:f9:9b:e5:90

## 試行したアプローチと結果

### 1. 標準API使用 (test_power_simple.ino)
```cpp
float ibat = M5.Power.getBatteryCurrent();
bool charging = M5.Power.isCharging();
```
**結果**:
- USBケーブルを物理的に外した状態でも：
  - `Battery Current: 0.00 mA`
  - `Charging: Yes`
  - `Battery Level: 100%` → 時間経過で96%に低下
- バッテリーレベルは減少しているのに、充電中と認識されている

### 2. AXP192レジスタ直接アクセス試行 (test_power_reading.ino)
```cpp
uint16_t vbat_raw = M5.Power.Axp192.readRegister12(0x78);
uint16_t ibat_raw_charge = M5.Power.Axp192.readRegister12(0x7A);
uint16_t ibat_raw_discharge = M5.Power.Axp192.readRegister13(0x7C);
```
**結果**:
- コンパイルエラー: `readRegister12/13` がprivateメンバー
- M5Unifiedライブラリでは直接アクセス不可

### 3. 高負荷による電流増加試行 (test_power_with_load.ino)
```cpp
// CPU負荷
for (int i = 0; i < 10000; i++) {
    dummy_result = sqrt(i) * sin(i) * cos(i);
    dummy_result += log(i + 1) * exp(i / 1000.0);
}
// ディスプレイ最大輝度、派手な更新
```
**結果**:
- 高負荷モードでも電流値は0.0mAのまま
- バッテリーレベルは96%まで低下（実際に電力消費している）
- CHGステータスは依然としてYes

### 4. 電圧降下からの推定試行
```cpp
// 内部抵抗50mΩと仮定
if (voltage_drop > 0) {
    estimated_current = (voltage_drop / 0.05) * 1000;  // mA
}
```
**結果**:
- 推定値は0mAベースで時々跳ね上がる
- 安定した測定値が得られない

## フラッシュログでの記録結果
`ble_adaptive_har_flash_log.ino`で記録したデータ：
```csv
timestamp_ms,control_state,har_state,uncertainty,adv_interval_ms,voltage_V,current_mA,power_mW,battery_pct,packets_sent
197087,0,0,0.100,2000,4.216,0.00,0.00,100,144
```
- 全エントリーで`current_mA`が0.00
- バッテリー動作でデータ収集したにも関わらず電流値が取得できていない

## 考えられる原因

1. **AXP192の初期化問題**
   - 電流測定機能が有効化されていない可能性
   - USBからバッテリーへの切り替えが正しく認識されていない

2. **M5Unifiedライブラリの制限**
   - `getBatteryCurrent()`が正しく実装されていない
   - AXP192のレジスタへの直接アクセスが制限されている

3. **ハードウェアの仕様**
   - M5StickC Plus2のAXP192実装に制限がある可能性
   - 電流測定用のセンス抵抗が実装されていない？

## 代替案の検討

### 1. 別のライブラリの使用
- ESP32-AXP192ライブラリの直接使用
- M5StickC-Plusの旧ライブラリの参照

### 2. I2C経由でのAXP192直接制御
```cpp
// I2C経由でAXP192のレジスタを読む
Wire.beginTransmission(0x34);  // AXP192のI2Cアドレス
Wire.write(0x7C);  // 放電電流レジスタ
Wire.endTransmission();
Wire.requestFrom(0x34, 2);
```

### 3. 外部電流センサーの使用
- INA219などの外部電流センサーを追加

## 次のステップ

1. **M5Stack公式フォーラムでの確認**
   - M5StickC Plus2での電流測定の既知の問題
   - 推奨される測定方法

2. **代替ライブラリの調査**
   - ESP32-AXP192ライブラリ
   - M5StickC（初代）のコード参照

3. **I2C直接アクセスの実装**
   - AXP192データシートの確認
   - レジスタマップの詳細調査

## 参考情報

- AXP192レジスタマップ：
  - 0x78-0x79: Battery voltage
  - 0x7A-0x7B: Battery charge current
  - 0x7C-0x7D: Battery discharge current
  - LSB = 0.5mA for current registers

- 関連ファイル：
  - `/firmware/m5stick/test_power/test_power_simple.ino`
  - `/firmware/m5stick/test_power/test_power_reading.ino`
  - `/firmware/m5stick/test_power/test_power_with_load.ino`
  - `/firmware/m5stick/ble_adaptive_har/ble_adaptive_har_flash_log.ino`

## 結論
現時点でM5StickC Plus2の標準APIでは電流測定が正常に動作していない。根本的な解決には、AXP192への低レベルアクセスか、外部測定手段が必要。