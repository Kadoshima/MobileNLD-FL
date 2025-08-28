# Flutter BLE Logger

MobileNLD-FL研究プロジェクト用のBLEロガーアプリ

## セットアップ

### 1. Flutter環境の準備
```bash
# Flutter SDKがインストールされていない場合
# https://flutter.dev/docs/get-started/install

# 依存関係のインストール
flutter pub get
```

### 2. プラットフォーム固有の設定

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

最小SDKバージョンを21に設定 (`android/app/build.gradle`):
```gradle
minSdkVersion 21
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to scan for BLE devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to scan for BLE devices</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for BLE scanning</string>
```

## ビルドと実行

### デバッグビルド
```bash
# Android
flutter run

# iOS
flutter run
```

### リリースビルド
```bash
# Android APK
flutter build apk

# iOS
flutter build ios
```

## 使い方

1. アプリを起動
2. "Start Scan"をタップしてBLEスキャン開始
3. M5HAR_01デバイスが検出されると自動的にデータ表示
4. "Start Log"でCSVファイルへの記録開始
5. "Stop Log"で記録停止

## ログファイルの場所

- Android: `/storage/emulated/0/Android/data/com.example.flutter_ble_logger/files/ble_logs/`
- iOS: アプリのDocumentsディレクトリ内

## 機能

- リアルタイムBLEパケット表示
- CSVファイルへの自動記録
- 加速度データのデコード
- バッテリー状態表示
- パケットシーケンス番号追跡