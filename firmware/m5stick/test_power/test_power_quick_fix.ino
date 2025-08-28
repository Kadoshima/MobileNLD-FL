#include <M5StickCPlus2.h>
#include <Wire.h>

#define AXP192_ADDR 0x34

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    
    Serial.begin(115200);
    delay(1000);
    
    // AXP192の電流測定を強制的に有効化
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x82);  // ADC Enable 1
    Wire.write(0xFF);  // 全ADC有効
    Wire.endTransmission();
    delay(100);
    
    // バッテリー管理を有効化
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x33);  // Battery charge control
    Wire.write(0xC0);  // Enable battery detection
    Wire.endTransmission();
    delay(100);
    
    Serial.println("=== Quick Fix Test ===");
    M5.Display.println("Quick Fix");
}

void loop() {
    M5.update();
    
    // レジスタ0x00を読む
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x00);
    Wire.endTransmission();
    Wire.requestFrom(AXP192_ADDR, 1);
    uint8_t status = Wire.available() ? Wire.read() : 0;
    
    // 放電電流を読む（簡易版）
    Wire.beginTransmission(AXP192_ADDR);
    Wire.write(0x7C);
    Wire.endTransmission();
    Wire.requestFrom(AXP192_ADDR, 2);
    float current = 0;
    if (Wire.available() >= 2) {
        uint8_t h = Wire.read();
        uint8_t l = Wire.read();
        // 正しいビット処理
        uint16_t raw = ((uint16_t)h << 5) | (l & 0x1F);
        current = raw * 0.5;
    }
    
    Serial.printf("Status: 0x%02X, Current: %.1f mA\n", status, current);
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.printf("Stat: %02X\n", status);
    M5.Display.printf("I: %.1f mA\n", current);
    M5.Display.printf("Bat: %s\n", (status & 0x20) ? "Yes" : "No");
    
    delay(1000);
}