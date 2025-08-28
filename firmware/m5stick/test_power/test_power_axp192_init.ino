#include <M5StickCPlus2.h>
#include <Wire.h>

#define AXP192_ADDR 0x34

// AXP192の完全な初期化
void initAXP192ForCurrentMeasurement() {
    Serial.println("Initializing AXP192 for current measurement...");
    
    // 1. ADC有効化レジスタ1 (0x82)
    // ビット7: バッテリー電圧ADC有効
    // ビット6: バッテリー電流ADC有効
    // ビット5: ACIN電圧ADC有効
    // ビット4: ACIN電流ADC有効
    // ビット3: VBUS電圧ADC有効
    // ビット2: VBUS電流ADC有効
    // ビット1: APS電圧ADC有効
    // ビット0: TS ADC有効
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x82);
    Wire.write(0xFF);  // 全ADC有効化
    Wire.endTransmission();
    delay(10);
    
    // 2. ADC有効化レジスタ2 (0x83)
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x83);
    Wire.write(0x00);  // GPIO ADCは無効
    Wire.endTransmission();
    delay(10);
    
    // 3. ADCサンプリングレート設定 (0x84)
    // ビット7-6: ADC サンプリングレート (00=25Hz, 01=50Hz, 10=100Hz, 11=200Hz)
    // ビット5-4: TS電流出力設定
    // ビット3: TS機能選択
    // ビット2: TS出力電流設定
    // ビット1-0: TS PINモード
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x84);
    Wire.write(0xC2);  // 200Hz サンプリング
    Wire.endTransmission();
    delay(10);
    
    // 4. 電池系統管理レジスタ (0x33) - 電流測定を有効化
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x33);
    Wire.write(0xC0);  // バッテリー存在、充電許可
    Wire.endTransmission();
    delay(10);
    
    Serial.println("AXP192 initialization complete");
}

// 全電流関連レジスタを読み取る
void readAllCurrentRegisters() {
    Serial.println("\n--- Current-related Registers ---");
    
    // ADC Enable registers
    uint8_t adc_en1 = readRegister(0x82);
    uint8_t adc_en2 = readRegister(0x83);
    Serial.printf("ADC Enable 1 (0x82): 0x%02X\n", adc_en1);
    Serial.printf("ADC Enable 2 (0x83): 0x%02X\n", adc_en2);
    
    // Battery voltage (0x78-0x79)
    uint16_t vbat_raw = readRegister16(0x78);
    float vbat = vbat_raw * 1.1 / 1000.0;  // LSB = 1.1mV
    Serial.printf("Battery Voltage Raw: 0x%04X = %.3f V\n", vbat_raw, vbat);
    
    // Charge current (0x7A-0x7B)
    uint16_t ichg_raw = readRegister16(0x7A);
    float ichg = ichg_raw * 0.5;  // LSB = 0.5mA
    Serial.printf("Charge Current Raw: 0x%04X = %.2f mA\n", ichg_raw, ichg);
    
    // Discharge current (0x7C-0x7D)
    uint16_t idis_raw = readRegister16(0x7C);
    float idis = idis_raw * 0.5;  // LSB = 0.5mA
    Serial.printf("Discharge Current Raw: 0x%04X = %.2f mA\n", idis_raw, idis);
    
    // Power status
    uint8_t pwr_status = readRegister(0x00);
    Serial.printf("Power Status (0x00): 0x%02X\n", pwr_status);
    Serial.printf("  VBUS Present: %s\n", (pwr_status & 0x10) ? "Yes" : "No");
    Serial.printf("  Battery Present: %s\n", (pwr_status & 0x20) ? "Yes" : "No");
    Serial.printf("  Charging: %s\n", (pwr_status & 0x04) ? "Yes" : "No");
}

uint8_t readRegister(uint8_t reg) {
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(reg);
    Wire.endTransmission();
    Wire.requestFrom(AXP192_ADDR, 1);
    if (Wire.available()) {
        return Wire.read();
    }
    return 0;
}

uint16_t readRegister16(uint8_t reg) {
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(reg);
    Wire.endTransmission();
    Wire.requestFrom(AXP192_ADDR, 2);
    if (Wire.available() >= 2) {
        uint16_t high = Wire.read();
        uint16_t low = Wire.read();
        return (high << 8) | low;
    }
    return 0;
}

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    
    Serial.begin(115200);
    delay(2000);
    
    Serial.println("=== AXP192 Current Measurement Test ===");
    
    // AXP192を完全に初期化
    initAXP192ForCurrentMeasurement();
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("AXP192");
    M5.Display.println("Init Test");
    
    // 初期状態を読み取る
    readAllCurrentRegisters();
}

void loop() {
    M5.update();
    
    // 1秒ごとに電流値を更新
    static uint32_t last_update = 0;
    if (millis() - last_update >= 1000) {
        last_update = millis();
        
        // 電流値を読み取る
        uint16_t idis_raw = readRegister16(0x7C);
        uint16_t ichg_raw = readRegister16(0x7A);
        float idis = idis_raw * 0.5;
        float ichg = ichg_raw * 0.5;
        
        // 電源ステータス
        uint8_t pwr_status = readRegister(0x00);
        bool vbus = (pwr_status & 0x10) != 0;
        
        // シリアル出力
        Serial.printf("\n[%lu ms] ", millis());
        Serial.printf("Discharge: %.2f mA (0x%04X), ", idis, idis_raw);
        Serial.printf("Charge: %.2f mA (0x%04X), ", ichg, ichg_raw);
        Serial.printf("VBUS: %s\n", vbus ? "Yes" : "No");
        
        // ディスプレイ更新
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("Current Test");
        M5.Display.println("");
        M5.Display.printf("Dis: %.1f mA\n", idis);
        M5.Display.printf("Chg: %.1f mA\n", ichg);
        M5.Display.printf("USB: %s\n", vbus ? "Yes" : "No");
        M5.Display.println("");
        M5.Display.printf("Raw: %04X\n", idis_raw);
    }
    
    // ボタンAで全レジスタダンプ
    if (M5.BtnA.wasPressed()) {
        readAllCurrentRegisters();
    }
    
    delay(10);
}