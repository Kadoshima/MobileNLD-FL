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
    M5.Display.println("Flash Diag");
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
    
    Serial.println("\n=== LittleFS Diagnostic Test ===");
    
    // Initialize filesystem
    if (!LittleFS.begin(true)) {  // Format if needed
        Serial.println("LittleFS Mount Failed");
        M5.Display.println("FS Error!");
        return;
    }
    Serial.println("LittleFS mounted successfully");
    
    // Show filesystem info
    Serial.println("\n--- Filesystem Info ---");
    Serial.printf("Total space: %d bytes\n", LittleFS.totalBytes());
    Serial.printf("Used space: %d bytes\n", LittleFS.usedBytes());
    Serial.printf("Free space: %d bytes\n", LittleFS.totalBytes() - LittleFS.usedBytes());
    
    // List ALL files (including root)
    Serial.println("\n--- All Files ---");
    listDir("/", 0);
    
    // Check for status.txt
    if (LittleFS.exists("/status.txt")) {
        Serial.println("\n--- Status File Found ---");
        File statusFile = LittleFS.open("/status.txt", "r");
        if (statusFile) {
            Serial.printf("File size: %d bytes\n", statusFile.size());
            Serial.println("Contents:");
            Serial.println("------------------------");
            while (statusFile.available()) {
                Serial.print((char)statusFile.read());
            }
            Serial.println("\n------------------------");
            statusFile.close();
        }
    } else {
        Serial.println("\nNo status.txt found");
    }
    
    // Check for power_log.csv
    if (LittleFS.exists("/power_log.csv")) {
        Serial.println("\n--- Power Log Found ---");
        File logFile = LittleFS.open("/power_log.csv", "r");
        if (logFile) {
            Serial.printf("File size: %d bytes\n", logFile.size());
            Serial.println("\n--- First 20 lines ---");
            
            int lineCount = 0;
            while (logFile.available() && lineCount < 20) {
                String line = logFile.readStringUntil('\n');
                Serial.println(line);
                lineCount++;
            }
            
            if (logFile.available()) {
                // Count remaining lines
                int totalLines = lineCount;
                while (logFile.available()) {
                    logFile.readStringUntil('\n');
                    totalLines++;
                }
                Serial.printf("\n... %d more lines ...\n", totalLines - lineCount);
                Serial.printf("Total lines: %d\n", totalLines);
            }
            
            logFile.close();
            
            M5.Display.fillScreen(BLACK);
            M5.Display.setCursor(0, 0);
            M5.Display.println("Log Found!");
            M5.Display.printf("Size: %d\n", logFile.size());
        }
    } else {
        Serial.println("\nNo power_log.csv found");
        M5.Display.println("No log");
        
        // Try to create a test file to verify write capability
        Serial.println("\n--- Write Test ---");
        File testFile = LittleFS.open("/test_write.txt", "w");
        if (testFile) {
            testFile.println("Test write successful");
            testFile.close();
            Serial.println("Created test_write.txt");
            
            // Verify it was written
            if (LittleFS.exists("/test_write.txt")) {
                Serial.println("Test file verified");
                LittleFS.remove("/test_write.txt");
                Serial.println("Test file removed");
            }
        } else {
            Serial.println("Failed to create test file!");
        }
    }
    
    Serial.println("\n=== Diagnostic Complete ===");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Complete!");
    M5.Display.println("");
    M5.Display.println("Check");
    M5.Display.println("Serial");
}

void listDir(const char * dirname, uint8_t levels) {
    Serial.printf("Listing directory: %s\n", dirname);
    
    File root = LittleFS.open(dirname);
    if (!root) {
        Serial.println("Failed to open directory");
        return;
    }
    if (!root.isDirectory()) {
        Serial.println("Not a directory");
        return;
    }
    
    File file = root.openNextFile();
    while (file) {
        if (file.isDirectory()) {
            Serial.print("  DIR : ");
            Serial.println(file.name());
            if (levels) {
                listDir(file.name(), levels - 1);
            }
        } else {
            Serial.print("  FILE: ");
            Serial.print(file.name());
            Serial.print("  SIZE: ");
            Serial.println(file.size());
        }
        file = root.openNextFile();
    }
}

void loop() {
    M5.update();
    
    // Button A: Format filesystem
    if (M5.BtnA.wasPressed()) {
        Serial.println("\n--- Formatting Filesystem ---");
        LittleFS.format();
        Serial.println("Format complete");
        
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("Formatted!");
        
        ESP.restart();
    }
    
    delay(10);
}