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
    
    // ディスプレイに表示
    if (!high_load_mode || millis() % 1000 < 500) {  // 高負荷時は点滅
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("Load Test");
        M5.Display.println("");
        M5.Display.printf("V: %.3fV\n", vbat/1000.0);
        M5.Display.printf("I: %.1fmA\n", ibat);
        M5.Display.printf("Est:%.1fmA\n", estimated_current);
        M5.Display.printf("Bat: %d%%\n", level);
        M5.Display.printf("CHG: %s\n", charging ? "Yes" : "No");
        M5.Display.println("");
        M5.Display.printf("Mode: %s\n", high_load_mode ? "HIGH" : "LOW");
        M5.Display.println("");
        M5.Display.println("BtnA:Toggle");
    }
    
    // 高負荷モードでない場合は少し待機
    if (!high_load_mode) {
        delay(100);
    }
}