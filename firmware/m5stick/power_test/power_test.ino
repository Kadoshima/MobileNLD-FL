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