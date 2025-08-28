# M5StickC Plus2 電流測定 - 試行したコード一覧

## 1. test_power_simple.ino - 標準API使用
```cpp
#include <M5StickCPlus2.h>

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("=== M5StickC Plus2 Power Test (Simple) ===");
    Serial.println("USBを外してバッテリー動作にしてください");
    Serial.println("電流値が正しく表示されるか確認します");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Power Test");
    M5.Display.println("Simple");
}

void loop() {
    M5.update();
    
    // 電源情報を取得
    float vbat = M5.Power.getBatteryVoltage();
    float ibat = M5.Power.getBatteryCurrent();
    int level = M5.Power.getBatteryLevel();
    bool charging = M5.Power.isCharging();
    
    // シリアルに出力
    Serial.println("\n--- Power Status ---");
    Serial.printf("Battery Voltage: %.3f V\n", vbat/1000.0);
    Serial.printf("Battery Current: %.2f mA\n", ibat);
    Serial.printf("Battery Level: %d%%\n", level);
    Serial.printf("Charging: %s\n", charging ? "Yes" : "No");
    Serial.printf("Power Mode: %s\n", charging ? "USB Power" : "Battery Power");
    
    // 電流の符号を確認
    if (ibat > 0) {
        Serial.println("Current > 0: Charging or No current");
    } else if (ibat < 0) {
        Serial.printf("Current < 0: Discharging at %.2f mA\n", -ibat);
    } else {
        Serial.println("Current = 0: No current flow detected");
    }
    
    // ディスプレイに表示
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Power Test");
    M5.Display.println("");
    M5.Display.printf("V: %.3fV\n", vbat/1000.0);
    M5.Display.printf("I: %.1fmA\n", ibat);
    M5.Display.printf("Bat: %d%%\n", level);
    M5.Display.printf("CHG: %s\n", charging ? "Yes" : "No");
    M5.Display.println("");
    
    // 絶対値で表示
    if (ibat != 0) {
        M5.Display.printf("Use: %.1fmA\n", abs(ibat));
    } else {
        M5.Display.println("Use: 0mA");
    }
    
    // 1秒待機
    delay(1000);
}
```

## 2. test_power_reading.ino - AXP192レジスタ直接読み取り試行（失敗）
```cpp
#include <M5StickCPlus2.h>

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("=== M5StickC Plus2 Power Test ===");
    Serial.println("USBを外してバッテリー動作にしてください");
    Serial.println("電流値が正しく表示されるか確認します");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Power Test");
}

void loop() {
    M5.update();
    
    // 電源情報を取得
    float vbat = M5.Power.getBatteryVoltage();
    float ibat = M5.Power.getBatteryCurrent();
    int level = M5.Power.getBatteryLevel();
    bool usb = M5.Power.isCharging();
    
    // AXP192の生データも確認 - コンパイルエラー
    // uint16_t vbat_raw = M5.Power.Axp192.readRegister12(0x78);  // Battery voltage
    // uint16_t ibat_raw_charge = M5.Power.Axp192.readRegister12(0x7A);  // Charge current
    // uint16_t ibat_raw_discharge = M5.Power.Axp192.readRegister13(0x7C);  // Discharge current
    
    // エラー: readRegister12/13 is private within this context
}
```

## 3. test_power_with_load.ino - 高負荷での電流増加試行
```cpp
#include <M5StickCPlus2.h>

// 計算負荷用の変数
volatile float dummy_result = 0;
bool high_load_mode = false;

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    M5.Display.setBrightness(255);  // 最大輝度
    
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("=== M5StickC Plus2 Power Test with Load ===");
    Serial.println("ボタンAで高負荷モードON/OFF");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Power Load");
    M5.Display.println("Test");
}

// CPU負荷をかける関数
void generateCPULoad() {
    for (int i = 0; i < 10000; i++) {
        dummy_result = sqrt(i) * sin(i) * cos(i);
        dummy_result += log(i + 1) * exp(i / 1000.0);
    }
}

void loop() {
    M5.update();
    
    // ボタンAで負荷モード切り替え
    if (M5.BtnA.wasPressed()) {
        high_load_mode = !high_load_mode;
        Serial.printf("High load mode: %s\n", high_load_mode ? "ON" : "OFF");
    }
    
    // 高負荷モードの場合、計算を実行
    if (high_load_mode) {
        generateCPULoad();
        
        // ディスプレイを派手に更新（電力消費増）
        static uint8_t color_cycle = 0;
        color_cycle++;
        if (color_cycle % 10 == 0) {
            M5.Display.fillScreen(color_cycle % 2 ? RED : GREEN);
        }
    }
    
    // 電源情報を取得
    float vbat = M5.Power.getBatteryVoltage();
    float ibat = M5.Power.getBatteryCurrent();
    int level = M5.Power.getBatteryLevel();
    bool charging = M5.Power.isCharging();
    
    // AXP192の代替方法：電圧降下から推定
    static float last_vbat = 0;
    static uint32_t last_time = 0;
    float voltage_drop = 0;
    float estimated_current = 0;
    
    if (last_time > 0) {
        uint32_t time_diff = millis() - last_time;
        voltage_drop = last_vbat - vbat;
        
        // 電圧降下から電流を推定（簡易的）
        // 内部抵抗を50mΩと仮定
        if (voltage_drop > 0) {
            estimated_current = (voltage_drop / 0.05) * 1000;  // mA
        }
    }
    last_vbat = vbat;
    last_time = millis();
    
    // シリアルに出力
    Serial.println("\n--- Power Status ---");
    Serial.printf("Battery Voltage: %.3f V\n", vbat/1000.0);
    Serial.printf("Battery Current: %.2f mA\n", ibat);
    Serial.printf("Estimated Current: %.2f mA\n", estimated_current);
    Serial.printf("Battery Level: %d%%\n", level);
    Serial.printf("Charging: %s\n", charging ? "Yes" : "No");
    Serial.printf("Load Mode: %s\n", high_load_mode ? "HIGH" : "LOW");
    
    // ディスプレイに表示（省略）
}
```

## 4. ble_adaptive_har_flash_log_fixed.ino - カスタム電流読み取り関数
```cpp
// AXP192の電流測定用（動作せず）
float getBatteryCurrent() {
    // 放電電流レジスタを直接読む (0x7C-0x7D)
    uint16_t discharge_raw = M5.Power.Axp192.readRegister13(0x7C);  // コンパイルエラー
    float discharge_current = discharge_raw * 0.5;  // LSB = 0.5mA
    
    // 充電電流レジスタも読む (0x7A-0x7B)
    uint16_t charge_raw = M5.Power.Axp192.readRegister12(0x7A);  // コンパイルエラー
    float charge_current = charge_raw * 0.5;  // LSB = 0.5mA
    
    // 放電中は負の値、充電中は正の値として返す
    if (discharge_raw > 0) {
        return -discharge_current;  // 放電中（消費電流）
    } else if (charge_raw > 0) {
        return charge_current;  // 充電中
    }
    
    return 0.0;  // どちらでもない場合
}
```

## 5. 試していない代替案

### I2C直接アクセス
```cpp
#include <Wire.h>

float readAXP192Current() {
    Wire.beginTransmission(0x34);  // AXP192 I2Cアドレス
    Wire.write(0x7C);  // 放電電流レジスタアドレス
    Wire.endTransmission();
    
    Wire.requestFrom(0x34, 2);
    if (Wire.available() == 2) {
        uint16_t raw = Wire.read() << 5;  // 上位8ビット
        raw |= Wire.read() & 0x1F;  // 下位5ビット
        return raw * 0.5;  // LSB = 0.5mA
    }
    return 0;
}
```

### ESP32内部ADCを使った推定
```cpp
// GPIO36 (VP) を使った電圧測定から推定
int adc_value = analogRead(36);
float voltage = adc_value * 3.3 / 4095.0;
// 既知の負荷抵抗から電流を計算
```