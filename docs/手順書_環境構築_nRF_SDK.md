# nRF Connect SDK 環境構築手順書

## 概要
BLE適応広告制御プロジェクトのファームウェア開発環境を構築します。
- **対象**: nRF52840 Development Kit
- **SDK**: nRF5 SDK v17.1.0 + SoftDevice S140
- **所要時間**: 4-6時間

## 必要なハードウェア
- [ ] nRF52840 DK (PCA10056) - 約8,000円
- [ ] USB-A to Micro-USBケーブル
- [ ] PC (Windows/Mac/Linux)

## Step 1: ツールのインストール

### 1.1 SEGGER J-Link ドライバ
1. [SEGGER Downloads](https://www.segger.com/downloads/jlink/)にアクセス
2. "J-Link Software and Documentation Pack"をダウンロード
3. インストール（デフォルト設定でOK）

### 1.2 nRF Command Line Tools
1. [Nordic Downloads](https://www.nordicsemi.com/Products/Development-tools/nrf-command-line-tools/download)にアクセス
2. OS別インストーラをダウンロード
3. インストール後、コマンドラインで確認:
```bash
nrfjprog --version
# 期待出力: nrfjprog version: 10.x.x
```

### 1.3 ARM GCC Toolchain
1. [ARM Developer](https://developer.arm.com/downloads/-/gnu-rm)にアクセス
2. "gcc-arm-none-eabi-10-2020-q4-major"をダウンロード
3. 解凍して適切な場所に配置（例: `/opt/gcc-arm-none-eabi/`）
4. PATHに追加:
```bash
# ~/.bashrc or ~/.zshrc に追加
export PATH=$PATH:/opt/gcc-arm-none-eabi/bin
```

## Step 2: nRF5 SDK セットアップ

### 2.1 SDK ダウンロード
```bash
# 作業ディレクトリ作成
mkdir -p ~/nrf-projects
cd ~/nrf-projects

# SDK v17.1.0 ダウンロード
wget https://developer.nordicsemi.com/nRF5_SDK/nRF5_SDK_v17.x.x/nRF5_SDK_17.1.0_ddde560.zip
unzip nRF5_SDK_17.1.0_ddde560.zip -d nRF5_SDK_17.1.0
```

### 2.2 SDK 設定ファイル編集
```bash
cd nRF5_SDK_17.1.0
# components/toolchain/gcc/Makefile.posix を編集
```

`Makefile.posix`の内容:
```makefile
GNU_INSTALL_ROOT ?= /opt/gcc-arm-none-eabi/bin/
GNU_VERSION ?= 10.2.1
GNU_PREFIX ?= arm-none-eabi
```

## Step 3: 初期動作確認

### 3.1 BLE Beacon サンプルのビルド
```bash
cd examples/ble_peripheral/ble_app_beacon/pca10056/s140/armgcc

# ビルド
make clean
make

# 期待される出力:
# Linking target: _build/nrf52840_xxaa.out
# text    data     bss     dec     hex filename
# xxxxx    xxxx    xxxx   xxxxx    xxxx _build/nrf52840_xxaa.out
# Preparing: _build/nrf52840_xxaa.hex
```

### 3.2 nRF52840 DK への書き込み

1. **DKをPCに接続**
   - J-Link USBポート（左側のMicro-USB）に接続
   - 電源スイッチをON
   - LED1が点灯することを確認

2. **SoftDevice書き込み**
```bash
# SoftDevice S140 を書き込み（初回のみ）
nrfjprog --family nrf52 --program ../../../../../../../../components/softdevice/s140/hex/s140_nrf52_7.2.0_softdevice.hex --sectorerase
nrfjprog --family nrf52 --reset
```

3. **アプリケーション書き込み**
```bash
# Beacon アプリを書き込み
nrfjprog --family nrf52 --program _build/nrf52840_xxaa.hex --sectorerase
nrfjprog --family nrf52 --reset
```

## Step 4: 動作確認

### 4.1 UART出力確認
1. シリアルターミナル（TeraTerm/screen）を開く
2. 設定: 115200 bps, 8-N-1
3. DKのリセットボタンを押す
4. 期待出力:
```
Beacon example started.
Advertising interval: 100 ms
TX Power: 0 dBm
```

### 4.2 BLE広告確認
1. スマートフォンで「nRF Connect」アプリを開く
2. スキャン開始
3. "Nordic_Beacon"が表示されることを確認
4. RSSI値と広告間隔を確認

## Step 5: プロジェクト用カスタマイズ

### 5.1 固定100ms広告に修正
`main.c`を編集:
```c
#define APP_ADV_INTERVAL  MSEC_TO_UNITS(100, UNIT_0_625_MS)  // 100ms固定
#define APP_BEACON_INFO_LENGTH  0x17  // 23 bytes
```

### 5.2 製造者データ設定
```c
// Company ID: 0x5900 (研究用仮ID)
#define APP_COMPANY_IDENTIFIER  0x5900

// 広告データ構造
static uint8_t m_beacon_info[APP_BEACON_INFO_LENGTH] = {
    APP_DEVICE_TYPE,     // 0x02
    APP_ADV_DATA_LENGTH, // 0x15
    APP_MEASURED_RSSI,   // 0xC3 (-61 dBm)
    // 以下、実験データ用ペイロード
};
```

### 5.3 再ビルド・書き込み
```bash
make clean && make
nrfjprog --program _build/nrf52840_xxaa.hex --sectorerase --verify
nrfjprog --reset
```

## トラブルシューティング

### エラー: "Cannot find JLink device"
- DKの電源スイッチを確認
- USBケーブルを差し直す
- `nrfjprog --recover`を実行

### エラー: "make: arm-none-eabi-gcc: command not found"
- PATHの設定を確認
- `which arm-none-eabi-gcc`で存在確認
- シェルを再起動

### 広告が見えない
- SoftDeviceが書き込まれているか確認
- `nrfjprog --readcode softdevice.hex`で読み出し
- アプリのアドレスが正しいか確認（0x26000から開始）

## 完了チェックリスト
- [ ] J-Linkドライバインストール完了
- [ ] nRF Command Line Tools動作確認
- [ ] ARM GCC Toolchain設定完了
- [ ] nRF5 SDK v17.1.0 配置完了
- [ ] Beaconサンプルビルド成功
- [ ] DKへの書き込み成功
- [ ] UART出力確認（"Beacon started, interval 100ms"）
- [ ] スマホアプリで広告受信確認

## 次のステップ
1. IMUドライバの統合（I2C/SPI）
2. TensorFlow Lite Microの組み込み
3. BLE適応制御ロジックの実装

---
作成日: 2024-12-17
プロジェクト: BLE適応広告制御による省電力HAR