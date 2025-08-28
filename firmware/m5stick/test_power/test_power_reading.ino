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
    
    // AXP192の生データも確認
    uint16_t vbat_raw = M5.Power.Axp192.readRegister12(0x78);  // Battery voltage
    uint16_t ibat_raw_charge = M5.Power.Axp192.readRegister12(0x7A);  // Charge current
    uint16_t ibat_raw_discharge = M5.Power.Axp192.readRegister13(0x7C);  // Discharge current
    
    // シリアルに出力
    Serial.println("\n--- Power Status ---");
    Serial.printf("Battery Voltage: %.3f V (raw: 0x%04X)\n", vbat/1000.0, vbat_raw);
    Serial.printf("Battery Current: %.2f mA\n", ibat);
    Serial.printf("  Charge Current (raw): 0x%04X = %.2f mA\n", 
                  ibat_raw_charge, ibat_raw_charge * 0.5);
    Serial.printf("  Discharge Current (raw): 0x%04X = %.2f mA\n", 
                  ibat_raw_discharge, ibat_raw_discharge * 0.5);
    Serial.printf("Battery Level: %d%%\n", level);
    Serial.printf("USB Connected: %s\n", usb ? "Yes" : "No");
    Serial.printf("Power Mode: %s\n", usb ? "USB Power" : "Battery Power");
    
    // ディスプレイに表示
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Power Test");
    M5.Display.println("");
    M5.Display.printf("V: %.3fV\n", vbat/1000.0);
    M5.Display.printf("I: %.1fmA\n", ibat);
    M5.Display.printf("Bat: %d%%\n", level);
    M5.Display.printf("USB: %s\n", usb ? "Yes" : "No");
    M5.Display.println("");
    
    // 放電電流の生データ表示
    if (ibat_raw_discharge > 0) {
        float discharge_ma = ibat_raw_discharge * 0.5;
        M5.Display.printf("Dis: %.1fmA\n", discharge_ma);
    } else {
        M5.Display.println("Dis: 0mA");
    }
    
    // 1秒待機
    delay(1000);
}