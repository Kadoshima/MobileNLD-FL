# Android BLEロガーアプリ実装手順書

## 概要
nRF52からのBLE広告パケットを受信し、CSVログとして記録するAndroidアプリを実装します。
- **開発環境**: Android Studio (Kotlin)
- **最小SDK**: API 26 (Android 8.0)
- **所要時間**: 4-6時間

## Step 1: Android Studio プロジェクト作成

### 1.1 新規プロジェクト
1. Android Studioを起動
2. "New Project" → "Empty Activity"
3. 設定:
   - Name: `BLEAdaptiveLogger`
   - Package: `com.research.blelogger`
   - Language: Kotlin
   - Minimum SDK: API 26

### 1.2 必要な権限を追加
`app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## Step 2: 依存関係の追加

`app/build.gradle`:
```gradle
dependencies {
    implementation 'org.jetbrains.kotlin:kotlin-stdlib:1.8.22'
    implementation 'androidx.core:core-ktx:1.10.1'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.9.0'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    
    // Coroutines
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1'
    
    // ViewModel
    implementation 'androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.1'
    implementation 'androidx.lifecycle:lifecycle-runtime-ktx:2.6.1'
    
    // CSV Writer
    implementation 'com.opencsv:opencsv:5.7.1'
}
```

## Step 3: BLEスキャンサービスの実装

### 3.1 フォアグラウンドサービス
`app/src/main/java/com/research/blelogger/BLEScanService.kt`:
```kotlin
package com.research.blelogger

import android.app.*
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import com.opencsv.CSVWriter
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*

class BLEScanService : Service() {
    
    companion object {
        private const val TAG = "BLEScanService"
        private const val CHANNEL_ID = "BLEScanChannel"
        private const val NOTIFICATION_ID = 1
        private const val COMPANY_ID = 0x5900  // 研究用仮ID
    }
    
    private lateinit var bluetoothAdapter: BluetoothAdapter
    private lateinit var bluetoothLeScanner: BluetoothLeScanner
    private lateinit var csvWriter: CSVWriter
    private lateinit var logFile: File
    
    private val scanSettings = ScanSettings.Builder()
        .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
        .setReportDelay(0)
        .build()
    
    private val scanFilters = mutableListOf<ScanFilter>().apply {
        add(ScanFilter.Builder()
            .setManufacturerData(COMPANY_ID, null)
            .build())
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        
        // Initialize Bluetooth
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeScanner = bluetoothAdapter.bluetoothLeScanner
        
        // Create notification channel
        createNotificationChannel()
        
        // Initialize CSV file
        initializeCsvFile()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand")
        
        // Start foreground service
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Start BLE scan
        startBleScan()
        
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "BLE Scan Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "BLE scanning for research data collection"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BLE Logger Active")
            .setContentText("Scanning and logging BLE advertisements")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun initializeCsvFile() {
        // Create log directory
        val logDir = File(getExternalFilesDir(null), "ble_logs")
        if (!logDir.exists()) {
            logDir.mkdirs()
        }
        
        // Create CSV file with timestamp
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        logFile = File(logDir, "phone_${timestamp}.csv")
        
        // Initialize CSV writer
        csvWriter = CSVWriter(FileWriter(logFile))
        
        // Write header
        val header = arrayOf(
            "timestamp_phone_unix_ms",
            "timestamp_phone_iso8601",
            "device_address",
            "rssi",
            "mfg_company_id",
            "mfg_raw_hex",
            "adv_interval_ms"
        )
        csvWriter.writeNext(header)
        csvWriter.flush()
        
        Log.d(TAG, "CSV file created: ${logFile.absolutePath}")
    }
    
    private val scanCallback = object : ScanCallback() {
        private var lastTimestamp = 0L
        
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            super.onScanResult(callbackType, result)
            
            val currentTime = System.currentTimeMillis()
            val device = result.device
            val rssi = result.rssi
            val scanRecord = result.scanRecord
            
            // Get manufacturer data
            val mfgData = scanRecord?.getManufacturerSpecificData(COMPANY_ID)
            
            if (mfgData != null) {
                // Calculate interval
                val interval = if (lastTimestamp > 0) {
                    currentTime - lastTimestamp
                } else {
                    0L
                }
                lastTimestamp = currentTime
                
                // Convert to hex string
                val hexString = mfgData.joinToString("") { 
                    String.format("%02X", it)
                }
                
                // Format ISO8601 timestamp
                val iso8601 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }.format(Date(currentTime))
                
                // Write to CSV
                val row = arrayOf(
                    currentTime.toString(),
                    iso8601,
                    device.address,
                    rssi.toString(),
                    COMPANY_ID.toString(),
                    hexString,
                    interval.toString()
                )
                
                synchronized(csvWriter) {
                    csvWriter.writeNext(row)
                    csvWriter.flush()
                }
                
                Log.v(TAG, "Logged: ${device.address} RSSI=$rssi Interval=${interval}ms")
            }
        }
        
        override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
            Log.e(TAG, "Scan failed with error: $errorCode")
        }
    }
    
    private fun startBleScan() {
        try {
            bluetoothLeScanner.startScan(scanFilters, scanSettings, scanCallback)
            Log.d(TAG, "BLE scan started")
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing Bluetooth permission", e)
        }
    }
    
    private fun stopBleScan() {
        try {
            bluetoothLeScanner.stopScan(scanCallback)
            Log.d(TAG, "BLE scan stopped")
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing Bluetooth permission", e)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopBleScan()
        csvWriter.close()
        Log.d(TAG, "Service destroyed")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}
```

## Step 4: メインアクティビティUI

### 4.1 レイアウト
`app/src/main/res/layout/activity_main.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp">
    
    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="BLE Adaptive Logger"
        android:textSize="24sp"
        android:textStyle="bold"
        android:layout_marginBottom="16dp"/>
    
    <EditText
        android:id="@+id/etRunId"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:hint="Run ID (e.g., 20241217_120000Z_S01_Fixed-100ms_001)"
        android:layout_marginBottom="16dp"/>
    
    <Button
        android:id="@+id/btnStartScan"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Start Logging"
        android:layout_marginBottom="8dp"/>
    
    <Button
        android:id="@+id/btnStopScan"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Stop Logging"
        android:enabled="false"
        android:layout_marginBottom="16dp"/>
    
    <TextView
        android:id="@+id/tvStatus"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Status: Idle"
        android:textSize="16sp"
        android:layout_marginBottom="8dp"/>
    
    <TextView
        android:id="@+id/tvPacketCount"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Packets: 0"
        android:textSize="16sp"
        android:layout_marginBottom="8dp"/>
    
    <TextView
        android:id="@+id/tvLogFile"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Log file: -"
        android:textSize="14sp"/>
    
</LinearLayout>
```

### 4.2 MainActivity
`app/src/main/java/com/research/blelogger/MainActivity.kt`:
```kotlin
package com.research.blelogger

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    
    companion object {
        private const val PERMISSION_REQUEST_CODE = 100
    }
    
    private lateinit var etRunId: EditText
    private lateinit var btnStartScan: Button
    private lateinit var btnStopScan: Button
    private lateinit var tvStatus: TextView
    private lateinit var tvPacketCount: TextView
    private lateinit var tvLogFile: TextView
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // Initialize views
        etRunId = findViewById(R.id.etRunId)
        btnStartScan = findViewById(R.id.btnStartScan)
        btnStopScan = findViewById(R.id.btnStopScan)
        tvStatus = findViewById(R.id.tvStatus)
        tvPacketCount = findViewById(R.id.tvPacketCount)
        tvLogFile = findViewById(R.id.tvLogFile)
        
        // Set click listeners
        btnStartScan.setOnClickListener {
            if (checkPermissions()) {
                startBleService()
            } else {
                requestPermissions()
            }
        }
        
        btnStopScan.setOnClickListener {
            stopBleService()
        }
    }
    
    private fun checkPermissions(): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }
        
        return permissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }
    
    private fun requestPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }
        
        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
    }
    
    private fun startBleService() {
        val runId = etRunId.text.toString()
        if (runId.isEmpty()) {
            Toast.makeText(this, "Please enter Run ID", Toast.LENGTH_SHORT).show()
            return
        }
        
        val serviceIntent = Intent(this, BLEScanService::class.java).apply {
            putExtra("run_id", runId)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        
        // Update UI
        btnStartScan.isEnabled = false
        btnStopScan.isEnabled = true
        tvStatus.text = "Status: Logging"
        Toast.makeText(this, "BLE logging started", Toast.LENGTH_SHORT).show()
    }
    
    private fun stopBleService() {
        val serviceIntent = Intent(this, BLEScanService::class.java)
        stopService(serviceIntent)
        
        // Update UI
        btnStartScan.isEnabled = true
        btnStopScan.isEnabled = false
        tvStatus.text = "Status: Idle"
        Toast.makeText(this, "BLE logging stopped", Toast.LENGTH_SHORT).show()
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                startBleService()
            } else {
                Toast.makeText(this, "Permissions required for BLE scanning", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
```

## Step 5: サービス登録

`AndroidManifest.xml`に追加:
```xml
<application>
    <!-- ... -->
    <service 
        android:name=".BLEScanService"
        android:foregroundServiceType="location"
        android:exported="false" />
</application>
```

## Step 6: ビルドと実行

### 6.1 ビルド
1. Android Studioで "Build" → "Make Project"
2. エラーがないことを確認

### 6.2 実機テスト
1. Android端末をUSB接続
2. 開発者オプションでUSBデバッグを有効化
3. "Run" → デバイスを選択
4. アプリが起動することを確認

## 動作確認チェックリスト

- [ ] アプリが起動する
- [ ] 権限リクエストが表示される
- [ ] "Start Logging"でフォアグラウンド通知が表示される
- [ ] nRF52の広告パケットを受信できる
- [ ] CSVファイルが生成される
- [ ] CSVに正しいフォーマットでデータが記録される
- [ ] "Stop Logging"で記録が停止する

## CSVファイルの取得方法

### adbコマンドで取得:
```bash
# ファイルリストを確認
adb shell ls /sdcard/Android/data/com.research.blelogger/files/ble_logs/

# PCにコピー
adb pull /sdcard/Android/data/com.research.blelogger/files/ble_logs/phone_*.csv ./
```

## トラブルシューティング

### 権限エラー
- Android 12以降: BLUETOOTH_SCAN, BLUETOOTH_CONNECT権限が必要
- 位置情報権限も必須（BLEスキャンに必要）

### スキャンが開始しない
- Bluetoothが有効か確認
- 位置情報サービスが有効か確認

### CSVファイルが見つからない
- アプリの外部ストレージ権限を確認
- Files appで確認: Android/data/com.research.blelogger/files/

## 次のステップ
1. リアルタイムモニタリングUI追加
2. パケット統計表示
3. エクスポート機能

---
作成日: 2024-12-17
プロジェクト: BLE適応広告制御による省電力HAR