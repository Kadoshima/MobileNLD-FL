#include <M5StickCPlus2.h>
#include <Wire.h>  // I2Cライブラリを追加

// AXP192のI2Cアドレス
#define AXP192_ADDR 0x34

// AXP192レジスタ読み取り関数（13ビット放電電流）
float readDischargeCurrent() {
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x7C);  // 放電電流レジスタ
    Wire.endTransmission();
    
    Wire.requestFrom(AXP192_ADDR, 2);
    if (Wire.available() == 2) {
        uint16_t high = Wire.read();  // 上位8ビット
        uint16_t low = Wire.read();   // 下位8ビット（ただし有効は5ビット）
        uint16_t raw = (high << 5) | (low & 0x1F);  // 13ビット結合
        return raw * 0.5;  // LSB = 0.5mA、放電なので正の値として返す（消費電流）
    }
    return 0.0;
}

// 充電電流読み取り関数（同様に12ビット）
float readChargeCurrent() {
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x7A);  // 充電電流レジスタ
    Wire.endTransmission();
    
    Wire.requestFrom(AXP192_ADDR, 2);
    if (Wire.available() == 2) {
        uint16_t high = Wire.read();
        uint16_t low = Wire.read();
        uint16_t raw = (high << 4) | (low & 0x0F);  // 12ビット結合（データシート確認）
        return raw * 0.5;
    }
    return 0.0;
}

// AXP192のADCを有効化する関数
void enableAXP192CurrentADC() {
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x82);  // ADC Enable 1 レジスタ
    Wire.write(0xC0);  // バッテリー電圧/電流ADCを有効（ビット6-7オン）
    Wire.endTransmission();
}

// AXP192の電源ステータスを読み取る
uint8_t readPowerStatus() {
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x00);  // Power Status レジスタ
    Wire.endTransmission();
    
    Wire.requestFrom(AXP192_ADDR, 1);
    if (Wire.available()) {
        return Wire.read();
    }
    return 0;
}

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    
    Serial.begin(115200);
    delay(1000);
    
    // AXP192のADCを有効化
    enableAXP192CurrentADC();
    delay(100);  // ADC安定化待機
    
    Serial.println("=== M5StickC Plus2 Power Test (Direct I2C) ===");
    Serial.println("USBを外してバッテリー動作にしてください");
    Serial.println("I2C直接アクセスで電流値を読み取ります");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Power Test");
    M5.Display.println("Direct I2C");
}

void loop() {
    M5.update();
    
    // 標準APIで取得
    float vbat = M5.Power.getBatteryVoltage();
    float ibat_standard = M5.Power.getBatteryCurrent();
    int level = M5.Power.getBatteryLevel();
    bool charging = M5.Power.isCharging();
    
    // 直接I2Cで電流取得
    float ibat_discharge = readDischargeCurrent();
    float ibat_charge = readChargeCurrent();
    float ibat_net = ibat_charge - ibat_discharge;  // ネット電流（正:充電、負:放電）
    
    // 電源ステータス取得
    uint8_t power_status = readPowerStatus();
    bool usb_present = (power_status & 0x10) != 0;  // ビット4: VBUS present
    bool battery_present = (power_status & 0x20) != 0;  // ビット5: Battery present
    
    // シリアル出力
    Serial.println("\n--- Power Status ---");
    Serial.printf("Battery Voltage: %.3f V\n", vbat / 1000.0);
    Serial.printf("Standard Current API: %.2f mA\n", ibat_standard);
    Serial.println("--- Direct I2C Readings ---");
    Serial.printf("Discharge Current: %.2f mA\n", ibat_discharge);
    Serial.printf("Charge Current: %.2f mA\n", ibat_charge);
    Serial.printf("Net Current: %.2f mA\n", ibat_net);
    Serial.printf("Power Status Reg: 0x%02X\n", power_status);
    Serial.printf("USB Present: %s\n", usb_present ? "Yes" : "No");
    Serial.printf("Battery Present: %s\n", battery_present ? "Yes" : "No");
    Serial.printf("Battery Level: %d%%\n", level);
    Serial.printf("Standard Charging API: %s\n", charging ? "Yes" : "No");
    
    // 真の電流値を判定
    float actual_current = 0;
    if (ibat_discharge > 0) {
        actual_current = -ibat_discharge;  // 放電中（負の値）
        Serial.printf("=> Device is discharging at %.2f mA\n", ibat_discharge);
    } else if (ibat_charge > 0) {
        actual_current = ibat_charge;  // 充電中（正の値）
        Serial.printf("=> Device is charging at %.2f mA\n", ibat_charge);
    } else {
        Serial.println("=> No current detected");
    }
    
    // ディスプレイ表示
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("I2C Direct");
    M5.Display.println("");
    M5.Display.printf("V: %.3fV\n", vbat / 1000.0);
    M5.Display.printf("Std: %.1fmA\n", ibat_standard);
    M5.Display.println("--- I2C ---");
    M5.Display.printf("Dis: %.1fmA\n", ibat_discharge);
    M5.Display.printf("Chg: %.1fmA\n", ibat_charge);
    M5.Display.printf("USB: %s\n", usb_present ? "Yes" : "No");
    M5.Display.printf("Bat: %d%%\n", level);
    
    // ボタンAでデバッグ情報表示
    if (M5.BtnA.wasPressed()) {
        Serial.println("\n=== Debug: All AXP192 Registers ===");
        for (uint8_t reg = 0x00; reg <= 0x84; reg++) {
            Wire.beginTransmission(AXP192_ADDR);
            Wire.write(reg);
            Wire.endTransmission();
            Wire.requestFrom(AXP192_ADDR, 1);
            if (Wire.available()) {
                uint8_t val = Wire.read();
                Serial.printf("Reg 0x%02X: 0x%02X\n", reg, val);
            }
        }
    }
    
    delay(1000);
}