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