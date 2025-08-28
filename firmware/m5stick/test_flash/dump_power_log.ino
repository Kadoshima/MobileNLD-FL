#include <M5StickCPlus2.h>
#include <LittleFS.h>

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    
    Serial.begin(115200);
    delay(2000);  // シリアルモニタが開くのを待つ
    
    Serial.println("\n=== Power Log Dump Tool ===");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Dumping");
    M5.Display.println("Log...");
    
    // Initialize filesystem
    if (!LittleFS.begin()) {
        Serial.println("Failed to mount filesystem");
        M5.Display.println("FS Error!");
        return;
    }
    
    // Dump power_log.csv
    Serial.println("\n=== POWER LOG DATA ===");
    File logFile = LittleFS.open("/power_log.csv", "r");
    if (logFile) {
        Serial.printf("File size: %d bytes\n", logFile.size());
        Serial.println("--- CSV DATA START ---");
        
        // 全データを出力
        while (logFile.available()) {
            Serial.write(logFile.read());
        }
        
        logFile.close();
        Serial.println("\n--- CSV DATA END ---");
        
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("Dump OK!");
        M5.Display.println("");
        M5.Display.printf("Size: %dB\n", logFile.size());
        M5.Display.println("");
        M5.Display.println("Check");
        M5.Display.println("Serial");
        M5.Display.println("Monitor");
        
    } else {
        Serial.println("No power_log.csv found!");
        M5.Display.println("No log!");
    }
    
    // Also show status
    Serial.println("\n=== STATUS FILE ===");
    File statusFile = LittleFS.open("/status.txt", "r");
    if (statusFile) {
        while (statusFile.available()) {
            Serial.write(statusFile.read());
        }
        statusFile.close();
    }
    
    Serial.println("\n\n=== Dump Complete ===");
    Serial.println("Copy the CSV data between 'CSV DATA START' and 'CSV DATA END'");
    Serial.println("Save it as a .csv file for analysis");
}

void loop() {
    M5.update();
    
    // ボタンAでファイル削除
    if (M5.BtnA.wasPressed()) {
        Serial.println("\n=== Deleting Files ===");
        if (LittleFS.remove("/power_log.csv")) {
            Serial.println("power_log.csv deleted");
        }
        if (LittleFS.remove("/status.txt")) {
            Serial.println("status.txt deleted");
        }
        
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("Files");
        M5.Display.println("Deleted!");
        
        delay(2000);
        ESP.restart();
    }
    
    delay(10);
}