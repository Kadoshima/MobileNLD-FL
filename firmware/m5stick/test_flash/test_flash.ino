#include <M5StickCPlus2.h>
#include <LittleFS.h>

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    
    Serial.begin(115200);
    
    // Wait for Serial connection
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Flash Test");
    M5.Display.println("");
    M5.Display.println("Press Btn");
    M5.Display.println("to start");
    
    // Wait for button press
    while (!M5.BtnA.wasPressed()) {
        M5.update();
        delay(10);
    }
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Testing...");
    
    Serial.println("\n=== LittleFS Test ===");
    
    // Initialize filesystem
    if (!LittleFS.begin(true)) {  // Format if needed
        Serial.println("LittleFS Mount Failed");
        M5.Display.println("FS Error!");
        return;
    }
    Serial.println("LittleFS mounted successfully");
    
    // List files
    Serial.println("\n--- Current Files ---");
    File root = LittleFS.open("/");
    File file = root.openNextFile();
    while (file) {
        Serial.print("  ");
        Serial.print(file.name());
        Serial.print(" - ");
        Serial.print(file.size());
        Serial.println(" bytes");
        file = root.openNextFile();
    }
    
    // Check for status.txt first
    if (LittleFS.exists("/status.txt")) {
        Serial.println("\n--- Status File Found ---");
        File statusFile = LittleFS.open("/status.txt", "r");
        if (statusFile) {
            Serial.println("Status file contents:");
            while (statusFile.available()) {
                Serial.println(statusFile.readStringUntil('\n'));
            }
            statusFile.close();
        }
    }
    
    // Check for power_log.csv
    if (LittleFS.exists("/power_log.csv")) {
        Serial.println("\n--- Power Log Found ---");
        File logFile = LittleFS.open("/power_log.csv", "r");
        if (logFile) {
            Serial.println("File size: " + String(logFile.size()) + " bytes");
            Serial.println("\n--- File Contents ---");
            
            int lineCount = 0;
            while (logFile.available() && lineCount < 10) {  // First 10 lines
                String line = logFile.readStringUntil('\n');
                Serial.println(line);
                lineCount++;
            }
            
            if (logFile.available()) {
                Serial.println("... (more data available) ...");
                
                // Count total lines
                int totalLines = lineCount;
                while (logFile.available()) {
                    logFile.readStringUntil('\n');
                    totalLines++;
                }
                Serial.println("Total lines: " + String(totalLines));
            }
            
            logFile.close();
            
            M5.Display.fillScreen(BLACK);
            M5.Display.setCursor(0, 0);
            M5.Display.println("Log Found!");
            M5.Display.println("");
            M5.Display.printf("Lines: %d\n", lineCount);
            M5.Display.println("");
            M5.Display.println("Check");
            M5.Display.println("Serial");
        }
    } else {
        Serial.println("\nNo power_log.csv found");
        M5.Display.println("No log");
    }
    
    Serial.println("\n=== Test Complete ===");
}

void loop() {
    M5.update();
    
    // Button A: Delete log file
    if (M5.BtnA.wasPressed()) {
        if (LittleFS.exists("/power_log.csv")) {
            LittleFS.remove("/power_log.csv");
            Serial.println("Log file deleted");
            M5.Display.fillScreen(BLACK);
            M5.Display.setCursor(0, 0);
            M5.Display.println("Deleted!");
        }
    }
    
    delay(10);
}