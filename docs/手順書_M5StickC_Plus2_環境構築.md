# M5StickC Plus2 環境構築・実装手順書

## 概要
M5StickC Plus2を使用してBLE適応広告制御システムを実装します。
- **MCU**: ESP32-PICO-V3-02
- **IMU**: MPU6886（内蔵）
- **電力測定**: AXP192（内蔵）
- **所要時間**: Phase 1は2-3時間で完了可能

## Phase 1: 実現可能性検証（今日中に完了）

### Step 1: Arduino IDE環境構築（30分）

#### 1.1 Arduino IDEインストール
```bash
# macOSの場合
brew install --cask arduino-ide

# または公式サイトから
# https://www.arduino.cc/en/software
```

#### 1.2 ESP32ボードマネージャー追加
1. Arduino IDE → Preferences
2. Additional Board Manager URLsに追加:
```
https://m5stack.oss-cn-shenzhen.aliyuncs.com/resource/arduino/package_m5stack_index.json
```

#### 1.3 M5StickC Plus2ボード選択
1. Tools → Board → Board Manager
2. "M5Stack"を検索してインストール
3. Tools → Board → M5Stack → M5StickC Plus2

#### 1.4 必要なライブラリインストール
```
Library Manager経由:
- M5StickCPlus2
- ArduinoBLE (ESP32 BLE代替)
```

### Step 2: BLE広告テスト（固定100ms）- 1時間

#### 2.1 基本BLE広告コード
`firmware/m5stick/ble_fixed_100ms/ble_fixed_100ms.ino`:
```cpp
#include <M5StickCPlus2.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEAdvertising.h>

// Configuration
#define DEVICE_NAME     "M5HAR_01"
#define COMPANY_ID      0x5900  // 研究用仮ID
#define ADV_INTERVAL_MS 100     // 固定100ms

// Global variables
BLEAdvertising *pAdvertising;
uint32_t packet_count = 0;
uint8_t sequence_num = 0;

// Manufacturer data structure (23 bytes total)
struct __attribute__((packed)) ManufacturerData {
    uint16_t company_id;    // 0x5900
    uint8_t  device_type;   // 0x01 = M5StickC
    uint8_t  sequence;      // Packet sequence number
    uint8_t  state;         // HAR state (0=Idle, 1=Active)
    uint8_t  uncertainty;   // Uncertainty metric (0-255)
    uint16_t interval_ms;   // Current advertising interval
    uint8_t  battery_pct;   // Battery percentage
    int16_t  acc_x;         // Accelerometer X (mg)
    int16_t  acc_y;         // Accelerometer Y (mg)
    int16_t  acc_z;         // Accelerometer Z (mg)
    uint32_t timestamp;     // Device uptime (ms)
};

void setup() {
    // Initialize M5StickC Plus2
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.fillScreen(BLACK);
    M5.Display.setTextColor(WHITE);
    M5.Display.setTextSize(2);
    
    // Display startup info
    M5.Display.setCursor(0, 0);
    M5.Display.println("BLE Test");
    M5.Display.println("Fixed 100ms");
    
    // Initialize IMU
    M5.Imu.begin();
    
    // Initialize BLE
    Serial.begin(115200);
    Serial.println("Starting BLE Advertising...");
    
    BLEDevice::init(DEVICE_NAME);
    
    // Create BLE Server (required for advertising)
    BLEServer *pServer = BLEDevice::createServer();
    
    // Get advertising instance
    pAdvertising = BLEDevice::getAdvertising();
    
    // Configure advertising
    pAdvertising->setMinInterval(ADV_INTERVAL_MS * 0.625); // Convert to 0.625ms units
    pAdvertising->setMaxInterval(ADV_INTERVAL_MS * 0.625);
    
    // Start advertising
    updateAdvertisingData();
    pAdvertising->start();
    
    Serial.println("BLE Advertising started!");
}

void updateAdvertisingData() {
    // Read IMU data
    float acc_x, acc_y, acc_z;
    M5.Imu.getAccelData(&acc_x, &acc_y, &acc_z);
    
    // Read battery level
    uint8_t battery_pct = M5.Power.getBatteryLevel();
    
    // Create manufacturer data
    ManufacturerData mfg_data;
    mfg_data.company_id = COMPANY_ID;
    mfg_data.device_type = 0x01;
    mfg_data.sequence = sequence_num++;
    mfg_data.state = 0;  // Will be updated with HAR
    mfg_data.uncertainty = 0;  // Will be calculated
    mfg_data.interval_ms = ADV_INTERVAL_MS;
    mfg_data.battery_pct = battery_pct;
    mfg_data.acc_x = (int16_t)(acc_x * 1000);  // Convert to mg
    mfg_data.acc_y = (int16_t)(acc_y * 1000);
    mfg_data.acc_z = (int16_t)(acc_z * 1000);
    mfg_data.timestamp = millis();
    
    // Set manufacturer data
    BLEAdvertisementData adv_data;
    adv_data.setManufacturerData(std::string((char*)&mfg_data, sizeof(mfg_data)));
    adv_data.setFlags(0x06); // BR/EDR not supported, General discoverable
    
    pAdvertising->setAdvertisementData(adv_data);
}

void loop() {
    M5.update();
    
    // Update advertising data every interval
    static uint32_t last_update = 0;
    if (millis() - last_update >= ADV_INTERVAL_MS) {
        last_update = millis();
        
        // Stop, update, restart (required for data change)
        pAdvertising->stop();
        updateAdvertisingData();
        pAdvertising->start();
        
        packet_count++;
        
        // Update display
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("BLE Active");
        M5.Display.printf("Pkts: %lu\n", packet_count);
        M5.Display.printf("Seq: %d\n", sequence_num);
        M5.Display.printf("Batt: %d%%\n", M5.Power.getBatteryLevel());
        
        // Log to serial
        if (packet_count % 10 == 0) {
            Serial.printf("Packets sent: %lu\n", packet_count);
        }
    }
    
    // Button A: Reset counter
    if (M5.BtnA.wasPressed()) {
        packet_count = 0;
        sequence_num = 0;
        Serial.println("Counters reset");
    }
    
    // Prevent WDT reset
    delay(1);
}
```

#### 2.2 書き込みと確認
1. M5StickC Plus2をUSB接続
2. Tools → Port → 適切なポートを選択
3. Upload（→ボタン）
4. シリアルモニタで出力確認

#### 2.3 スマホで受信確認
1. iPhone/Androidで「nRF Connect」アプリを開く
2. スキャン開始
3. "M5HAR_01"が表示されることを確認
4. Manufacturer Dataに0x5900が含まれることを確認
5. 広告間隔が約100msであることを確認

### Step 3: IMUデータ取得テスト（30分）

#### 3.1 IMU + 簡易HAR判定
`firmware/m5stick/imu_har_test/imu_har_test.ino`:
```cpp
#include <M5StickCPlus2.h>

// HAR parameters
#define SAMPLE_RATE_HZ 50
#define SAMPLE_PERIOD_MS (1000 / SAMPLE_RATE_HZ)
#define WINDOW_SIZE 100  // 2 seconds at 50Hz
#define ACTIVITY_THRESHOLD 0.15  // Acceleration variance threshold

// Circular buffer for accelerometer data
float acc_buffer_x[WINDOW_SIZE];
float acc_buffer_y[WINDOW_SIZE];
float acc_buffer_z[WINDOW_SIZE];
int buffer_index = 0;
bool buffer_full = false;

// HAR state
enum HARState {
    STATE_IDLE = 0,
    STATE_ACTIVE = 1,
    STATE_UNCERTAIN = 2
};

HARState current_state = STATE_IDLE;
float uncertainty = 0.0;

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Imu.begin();
    
    Serial.begin(115200);
    Serial.println("IMU HAR Test Started");
    
    // Initialize buffers
    memset(acc_buffer_x, 0, sizeof(acc_buffer_x));
    memset(acc_buffer_y, 0, sizeof(acc_buffer_y));
    memset(acc_buffer_z, 0, sizeof(acc_buffer_z));
}

float calculateVariance(float* buffer, int size) {
    float mean = 0;
    for (int i = 0; i < size; i++) {
        mean += buffer[i];
    }
    mean /= size;
    
    float variance = 0;
    for (int i = 0; i < size; i++) {
        float diff = buffer[i] - mean;
        variance += diff * diff;
    }
    variance /= size;
    
    return variance;
}

HARState classifyActivity() {
    if (!buffer_full) return STATE_UNCERTAIN;
    
    // Calculate variance for each axis
    float var_x = calculateVariance(acc_buffer_x, WINDOW_SIZE);
    float var_y = calculateVariance(acc_buffer_y, WINDOW_SIZE);
    float var_z = calculateVariance(acc_buffer_z, WINDOW_SIZE);
    
    // Combined variance (simple sum)
    float total_variance = var_x + var_y + var_z;
    
    // Simple threshold-based classification
    if (total_variance > ACTIVITY_THRESHOLD) {
        uncertainty = 0.2;  // Low uncertainty for clear activity
        return STATE_ACTIVE;
    } else if (total_variance < ACTIVITY_THRESHOLD * 0.3) {
        uncertainty = 0.1;  // Low uncertainty for clear idle
        return STATE_IDLE;
    } else {
        uncertainty = 0.8;  // High uncertainty in transition zone
        return STATE_UNCERTAIN;
    }
}

void loop() {
    M5.update();
    
    static uint32_t last_sample = 0;
    if (millis() - last_sample >= SAMPLE_PERIOD_MS) {
        last_sample = millis();
        
        // Read IMU
        float acc_x, acc_y, acc_z;
        M5.Imu.getAccelData(&acc_x, &acc_y, &acc_z);
        
        // Store in circular buffer
        acc_buffer_x[buffer_index] = acc_x;
        acc_buffer_y[buffer_index] = acc_y;
        acc_buffer_z[buffer_index] = acc_z;
        
        buffer_index = (buffer_index + 1) % WINDOW_SIZE;
        if (buffer_index == 0) buffer_full = true;
        
        // Classify activity
        HARState new_state = classifyActivity();
        
        // State change detection
        if (new_state != current_state) {
            Serial.printf("State change: %s -> %s (uncertainty: %.2f)\n",
                current_state == STATE_IDLE ? "IDLE" : 
                current_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN",
                new_state == STATE_IDLE ? "IDLE" : 
                new_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN",
                uncertainty);
            current_state = new_state;
        }
        
        // Update display
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("HAR Test");
        M5.Display.println("");
        M5.Display.print("State: ");
        M5.Display.println(
            current_state == STATE_IDLE ? "IDLE" : 
            current_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN"
        );
        M5.Display.printf("Uncert: %.2f\n", uncertainty);
        M5.Display.printf("Acc: %.2f\n", sqrt(acc_x*acc_x + acc_y*acc_y + acc_z*acc_z));
    }
    
    delay(1);
}
```

#### 3.2 動作テスト
1. コードをアップロード
2. M5StickCを手に持って静止 → "IDLE"表示
3. 歩く・振る → "ACTIVE"表示
4. ゆっくり動かす → "UNCERTAIN"表示

### Step 4: 電力測定テスト（30分）

#### 4.1 AXP192電力読み取り
`firmware/m5stick/power_test/power_test.ino`:
```cpp
#include <M5StickCPlus2.h>

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    
    Serial.begin(115200);
    Serial.println("Power Measurement Test");
}

void loop() {
    M5.update();
    
    // Read power metrics every second
    static uint32_t last_read = 0;
    if (millis() - last_read >= 1000) {
        last_read = millis();
        
        // Get power readings
        float vbat = M5.Power.getBatteryVoltage() / 1000.0;  // Convert to V
        float ibat = M5.Power.getBatteryCurrent();  // mA
        float power = vbat * abs(ibat);  // mW
        int battery_level = M5.Power.getBatteryLevel();  // %
        
        // Display
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("Power Monitor");
        M5.Display.println("");
        M5.Display.printf("Batt: %d%%\n", battery_level);
        M5.Display.printf("V: %.2f V\n", vbat);
        M5.Display.printf("I: %.1f mA\n", ibat);
        M5.Display.printf("P: %.1f mW\n", power);
        
        // Log to serial (CSV format)
        static bool header_printed = false;
        if (!header_printed) {
            Serial.println("timestamp_ms,voltage_V,current_mA,power_mW,battery_pct");
            header_printed = true;
        }
        Serial.printf("%lu,%.3f,%.2f,%.2f,%d\n", 
            millis(), vbat, ibat, power, battery_level);
    }
    
    delay(10);
}
```

#### 4.2 電力比較テスト
1. 固定100ms広告を5分実行 → 平均電流記録
2. 固定2000ms広告を5分実行 → 平均電流記録
3. 削減率を計算: `(I_100ms - I_2000ms) / I_100ms * 100`
4. 期待値: 10-20%削減（ESP32の特性上、nRF52より削減率は低い）

## Phase 2: 適応制御実装（Day 2-3）

### 統合コード（BLE + IMU + 適応制御）
後続の手順書で提供します。主な実装内容:
- 3状態遷移（Quiet/Uncertain/Active）
- 不確実度ベースの広告間隔調整（100/500/2000ms）
- ヒステリシスとレート制限

## トラブルシューティング

### M5StickCが認識されない
- USB-Cケーブルを確認（データ転送対応か）
- CP2104ドライバをインストール
- ボード選択が正しいか確認

### BLE広告が見えない
- スマホのBluetooth ON確認
- nRF Connectの設定でフィルタ解除
- M5StickCのリセット（電源ボタン長押し）

### IMUデータが異常
- M5.Imu.begin()が成功しているか確認
- キャリブレーション実施（8の字動作）

### 電流値が読めない
- M5StickC Plus2であることを確認（Plus1は非対応）
- USBから外してバッテリー駆動で測定

## 完了チェックリスト

### Phase 1完了条件
- [ ] Arduino IDE環境構築完了
- [ ] BLE広告をスマホで受信確認
- [ ] IMUで動作判定（Active/Idle）確認
- [ ] AXP192で電流値取得確認
- [ ] 固定100ms vs 2000msで消費電力差確認

## 次のステップ
1. Phase 2: 適応制御アルゴリズム実装
2. Phone側CSVロガー実装
3. 3台同時測定環境構築
4. 統計的評価

---
作成日: 2024-12-17
プロジェクト: BLE適応広告制御（M5StickC Plus2版）