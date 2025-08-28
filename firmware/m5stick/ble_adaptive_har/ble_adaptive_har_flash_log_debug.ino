#include <M5StickCPlus2.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <LittleFS.h>

// Device identification
#define DEVICE_NAME "M5HAR_01"
#define DEVICE_TYPE 0x01
#define COMPANY_ID 0x5900
#define SESSION_ID random(0xFFFF)

// HAR parameters
#define SAMPLE_RATE_HZ 50
#define SAMPLE_PERIOD_MS (1000 / SAMPLE_RATE_HZ)
#define WINDOW_SIZE 100  // 2 seconds at 50Hz
#define ACTIVITY_THRESHOLD 0.15  // Acceleration variance threshold

// Adaptive control parameters
#define EWMA_ALPHA 0.2  // Smoothing factor for uncertainty
#define THETA_Q_IN 0.25  // Threshold to enter Quiet state
#define THETA_Q_OUT 0.30  // Threshold to exit Quiet state
#define THETA_A_IN 0.60  // Threshold to enter Active state
#define THETA_A_OUT 0.55  // Threshold to exit Active state
#define RATE_LIMIT_MS 2000  // Minimum time between state changes

// BLE advertising intervals (ms)
#define ADV_INTERVAL_QUIET 2000
#define ADV_INTERVAL_UNCERTAIN 500
#define ADV_INTERVAL_ACTIVE 100

// Power measurement interval
#define POWER_LOG_INTERVAL_MS 1000

// Flash logging
#define FORMAT_LITTLEFS_IF_FAILED true
#define LOG_FILE_PATH "/power_log.csv"
#define STATUS_FILE_PATH "/status.txt"

// Circular buffer for accelerometer data
float acc_buffer_x[WINDOW_SIZE];
float acc_buffer_y[WINDOW_SIZE];
float acc_buffer_z[WINDOW_SIZE];
int buffer_index = 0;
bool buffer_full = false;

// HAR state
enum HARState {
    STATE_IDLE = 0,
    STATE_ACTIVE = 1,
    STATE_UNCERTAIN = 2
};

// Adaptive control state
enum ControlState {
    CONTROL_QUIET = 0,
    CONTROL_UNCERTAIN = 1,
    CONTROL_ACTIVE = 2
};

HARState har_state = STATE_IDLE;
ControlState control_state = CONTROL_UNCERTAIN;
float raw_uncertainty = 0.5;
float smoothed_uncertainty = 0.5;  // EWMA smoothed value
uint32_t last_state_change = 0;
uint16_t current_adv_interval = ADV_INTERVAL_UNCERTAIN;

// BLE variables
BLEAdvertising *pAdvertising;
uint8_t sequence_number = 0;
uint16_t session_id;
bool ble_initialized = false;

// Timing
uint32_t last_sample_time = 0;
uint32_t last_adv_time = 0;
uint32_t last_power_log = 0;

// Flash logging
bool filesystem_mounted = false;
uint32_t log_entry_count = 0;
uint32_t experiment_start_time = 0;

// Operation mode
enum OperationMode {
    MODE_EXPERIMENT = 0,  // Normal experiment mode (battery powered)
    MODE_DATA_DUMP = 1    // Data dump mode (USB connected)
};
OperationMode operation_mode = MODE_EXPERIMENT;

// Debug flag
bool debug_mode = true;

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    M5.Imu.begin();
    
    Serial.begin(115200);
    delay(1000);  // Wait for serial
    
    Serial.println("\n=== BLE Adaptive HAR - Flash Power Logger (DEBUG) ===");
    
    // Display mode selection
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Mode Select");
    M5.Display.println("");
    M5.Display.println("BtnA:");
    M5.Display.println("Experiment");
    M5.Display.println("");
    M5.Display.println("Power:");
    M5.Display.println("Data Dump");
    
    Serial.println("Mode selection: BtnA=Experiment, Power=DataDump");
    
    // Wait for button selection (10 seconds timeout)
    uint32_t start_time = millis();
    bool button_pressed = false;
    
    while (millis() - start_time < 10000 && !button_pressed) {
        M5.update();
        
        // Button A: Start experiment
        if (M5.BtnA.wasPressed()) {
            operation_mode = MODE_EXPERIMENT;
            button_pressed = true;
            Serial.println("Button A pressed - Experiment mode");
        }
        
        // Power button: Data dump
        if (M5.BtnPWR.wasPressed()) {
            operation_mode = MODE_DATA_DUMP;
            button_pressed = true;
            Serial.println("Power button pressed - Data dump mode");
        }
        
        // Display countdown
        int remaining = 10 - ((millis() - start_time) / 1000);
        M5.Display.setCursor(0, 160);
        M5.Display.printf("Time: %d ", remaining);
        
        delay(10);
    }
    
    // If no selection, default to experiment mode
    if (!button_pressed) {
        operation_mode = MODE_EXPERIMENT;
        Serial.println("Timeout - defaulting to Experiment mode");
    }
    
    if (operation_mode == MODE_DATA_DUMP) {
        Serial.println("\n=== DATA DUMP MODE ===");
        Serial.println("Waiting for serial monitor...");
        delay(3000);  // Give time for serial monitor to open
        dumpDataAndClear();
        return;
    }
    
    // Normal experiment mode
    Serial.println("\n=== EXPERIMENT MODE ===");
    
    // Initialize filesystem
    Serial.print("Mounting LittleFS...");
    if (!LittleFS.begin(FORMAT_LITTLEFS_IF_FAILED)) {
        Serial.println(" FAILED!");
        M5.Display.fillScreen(RED);
        M5.Display.setCursor(0, 0);
        M5.Display.println("FS Error!");
        while(1) delay(1000);
    }
    filesystem_mounted = true;
    Serial.println(" OK");
    
    // Show filesystem info
    Serial.printf("Total space: %d bytes\n", LittleFS.totalBytes());
    Serial.printf("Used space: %d bytes\n", LittleFS.usedBytes());
    Serial.printf("Free space: %d bytes\n", LittleFS.totalBytes() - LittleFS.usedBytes());
    
    // Check existing log file
    if (LittleFS.exists(LOG_FILE_PATH)) {
        File oldLog = LittleFS.open(LOG_FILE_PATH, "r");
        if (oldLog) {
            Serial.printf("Warning: Previous log exists (%d bytes). Will append.\n", oldLog.size());
            oldLog.close();
        }
    }
    
    // Write experiment start marker
    Serial.print("Writing status file...");
    File statusFile = LittleFS.open(STATUS_FILE_PATH, "w");
    if (statusFile) {
        statusFile.printf("Experiment started: %lu\n", millis());
        statusFile.printf("Mode: EXPERIMENT\n");
        statusFile.close();
        Serial.println(" OK");
    } else {
        Serial.println(" FAILED!");
    }
    
    // Generate session ID
    session_id = SESSION_ID;
    Serial.printf("Session ID: 0x%04X\n", session_id);
    
    // Initialize buffers
    memset(acc_buffer_x, 0, sizeof(acc_buffer_x));
    memset(acc_buffer_y, 0, sizeof(acc_buffer_y));
    memset(acc_buffer_z, 0, sizeof(acc_buffer_z));
    
    // Initialize BLE
    Serial.print("Initializing BLE...");
    initBLE();
    Serial.println(" OK");
    
    // Write CSV header
    Serial.print("Creating log file with header...");
    File logFile = LittleFS.open(LOG_FILE_PATH, "w");  // Create new file
    if (logFile) {
        logFile.println("timestamp_ms,control_state,har_state,uncertainty,adv_interval_ms,voltage_V,current_mA,power_mW,battery_pct,packets_sent");
        logFile.close();
        Serial.println(" OK");
        
        // Verify file was created
        if (LittleFS.exists(LOG_FILE_PATH)) {
            File verifyFile = LittleFS.open(LOG_FILE_PATH, "r");
            if (verifyFile) {
                Serial.printf("Log file created successfully (%d bytes)\n", verifyFile.size());
                verifyFile.close();
            }
        }
    } else {
        Serial.println(" FAILED!");
    }
    
    experiment_start_time = millis();
    
    // Display ready status
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Flash Log");
    M5.Display.println("RUNNING");
    M5.Display.println("");
    M5.Display.println("Entries: 0");
    
    Serial.println("\n=== EXPERIMENT STARTED ===");
    Serial.println("Power data will be logged every 1 second");
    Serial.println("Press reset button to stop and dump data");
}

void dumpDataAndClear() {
    // Initialize filesystem for reading
    if (!LittleFS.begin()) {
        Serial.println("Failed to mount filesystem");
        return;
    }
    
    // Dump status file first
    Serial.println("\n=== STATUS FILE ===");
    File statusFile = LittleFS.open(STATUS_FILE_PATH, "r");
    if (statusFile) {
        while (statusFile.available()) {
            Serial.write(statusFile.read());
        }
        statusFile.close();
    } else {
        Serial.println("No status file found");
    }
    
    // Dump log file
    Serial.println("\n=== POWER LOG DATA ===");
    File logFile = LittleFS.open(LOG_FILE_PATH, "r");
    if (logFile) {
        Serial.printf("File size: %d bytes\n", logFile.size());
        Serial.println("--- START OF DATA ---");
        while (logFile.available()) {
            Serial.write(logFile.read());
        }
        logFile.close();
        Serial.println("--- END OF DATA ---");
        
        // Ask for confirmation to delete
        Serial.println("\nSend 'DELETE' to clear log files, or 'KEEP' to preserve");
        
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("Data Dump");
        M5.Display.println("Complete!");
        M5.Display.println("");
        M5.Display.println("Check");
        M5.Display.println("Serial");
    } else {
        Serial.println("No log file found");
        M5.Display.println("No data");
    }
    
    // Wait for user command
    uint32_t timeout_start = millis();
    while (millis() - timeout_start < 30000) {  // 30 second timeout
        if (Serial.available()) {
            String cmd = Serial.readStringUntil('\n');
            cmd.trim();
            if (cmd == "DELETE") {
                LittleFS.remove(LOG_FILE_PATH);
                LittleFS.remove(STATUS_FILE_PATH);
                Serial.println("Log files deleted");
                M5.Display.println("Deleted");
                break;
            } else if (cmd == "KEEP") {
                Serial.println("Log files preserved");
                M5.Display.println("Kept");
                break;
            }
        }
        delay(100);
    }
}

void initBLE() {
    BLEDevice::init(DEVICE_NAME);
    
    // Get advertising instance
    pAdvertising = BLEDevice::getAdvertising();
    
    // Set advertising type to non-connectable
    pAdvertising->setAdvertisementType(ADV_TYPE_NONCONN_IND);
    
    ble_initialized = true;
}

float calculateVariance(float* buffer, int size) {
    float mean = 0;
    for (int i = 0; i < size; i++) {
        mean += buffer[i];
    }
    mean /= size;
    
    float variance = 0;
    for (int i = 0; i < size; i++) {
        float diff = buffer[i] - mean;
        variance += diff * diff;
    }
    variance /= size;
    
    return variance;
}

void classifyActivity() {
    if (!buffer_full) {
        har_state = STATE_UNCERTAIN;
        raw_uncertainty = 1.0;
        return;
    }
    
    // Calculate variance for each axis
    float var_x = calculateVariance(acc_buffer_x, WINDOW_SIZE);
    float var_y = calculateVariance(acc_buffer_y, WINDOW_SIZE);
    float var_z = calculateVariance(acc_buffer_z, WINDOW_SIZE);
    
    // Combined variance
    float total_variance = var_x + var_y + var_z;
    
    // Classification with uncertainty
    if (total_variance > ACTIVITY_THRESHOLD) {
        har_state = STATE_ACTIVE;
        raw_uncertainty = 0.2;  // Low uncertainty
    } else if (total_variance < ACTIVITY_THRESHOLD * 0.3) {
        har_state = STATE_IDLE;
        raw_uncertainty = 0.1;  // Low uncertainty
    } else {
        har_state = STATE_UNCERTAIN;
        // Calculate uncertainty based on distance to thresholds
        float dist_to_active = abs(total_variance - ACTIVITY_THRESHOLD);
        float dist_to_idle = abs(total_variance - ACTIVITY_THRESHOLD * 0.3);
        float min_dist = min(dist_to_active, dist_to_idle);
        raw_uncertainty = 1.0 - (min_dist / ACTIVITY_THRESHOLD);
        raw_uncertainty = constrain(raw_uncertainty, 0.0, 1.0);
    }
}

void updateControlState() {
    // Apply EWMA to uncertainty
    smoothed_uncertainty = EWMA_ALPHA * raw_uncertainty + 
                          (1.0 - EWMA_ALPHA) * smoothed_uncertainty;
    
    // Check rate limiting
    uint32_t time_since_change = millis() - last_state_change;
    bool can_change = (time_since_change >= RATE_LIMIT_MS);
    
    ControlState new_state = control_state;
    
    // State transition logic with hysteresis
    switch (control_state) {
        case CONTROL_QUIET:
            if (smoothed_uncertainty > THETA_Q_OUT && can_change) {
                if (smoothed_uncertainty > THETA_A_IN) {
                    new_state = CONTROL_ACTIVE;
                } else {
                    new_state = CONTROL_UNCERTAIN;
                }
            }
            break;
            
        case CONTROL_UNCERTAIN:
            if (smoothed_uncertainty < THETA_Q_IN && can_change) {
                new_state = CONTROL_QUIET;
            } else if (smoothed_uncertainty > THETA_A_IN && can_change) {
                new_state = CONTROL_ACTIVE;
            }
            break;
            
        case CONTROL_ACTIVE:
            if (smoothed_uncertainty < THETA_A_OUT && can_change) {
                if (smoothed_uncertainty < THETA_Q_IN) {
                    new_state = CONTROL_QUIET;
                } else {
                    new_state = CONTROL_UNCERTAIN;
                }
            }
            break;
    }
    
    // Update state and advertising interval
    if (new_state != control_state) {
        control_state = new_state;
        last_state_change = millis();
        
        switch (control_state) {
            case CONTROL_QUIET:
                current_adv_interval = ADV_INTERVAL_QUIET;
                break;
            case CONTROL_UNCERTAIN:
                current_adv_interval = ADV_INTERVAL_UNCERTAIN;
                break;
            case CONTROL_ACTIVE:
                current_adv_interval = ADV_INTERVAL_ACTIVE;
                break;
        }
        
        if (debug_mode) {
            Serial.printf("[%lu] Control state changed to %s, interval=%dms\n",
                millis(),
                control_state == CONTROL_QUIET ? "QUIET" :
                control_state == CONTROL_ACTIVE ? "ACTIVE" : "UNCERTAIN",
                current_adv_interval);
        }
    }
}

void updateBLEAdvertising() {
    if (!ble_initialized) return;
    
    // Check if it's time to advertise
    if (millis() - last_adv_time < current_adv_interval) return;
    last_adv_time = millis();
    
    // Stop current advertising
    pAdvertising->stop();
    
    // Clear previous data
    BLEAdvertisementData adv_data;
    adv_data.setFlags(0x06);  // BR/EDR Not Supported, General Discoverable
    adv_data.setCompleteServices(BLEUUID((uint16_t)0x1809));  // Health Thermometer dummy
    
    // Prepare manufacturer data
    uint8_t mfg_data[17];
    uint16_t offset = 0;
    
    // Device type and sequence
    mfg_data[offset++] = DEVICE_TYPE;
    mfg_data[offset++] = sequence_number++;
    
    // HAR state and uncertainty
    mfg_data[offset++] = (uint8_t)har_state;
    mfg_data[offset++] = (uint8_t)(smoothed_uncertainty * 255);
    
    // Current advertising interval
    mfg_data[offset++] = current_adv_interval & 0xFF;
    mfg_data[offset++] = (current_adv_interval >> 8) & 0xFF;
    
    // Battery level
    mfg_data[offset++] = M5.Power.getBatteryLevel();
    
    // Accelerometer data (converting to int16)
    float acc_x, acc_y, acc_z;
    M5.Imu.getAccelData(&acc_x, &acc_y, &acc_z);
    
    int16_t acc_x_mg = (int16_t)(acc_x * 1000);
    int16_t acc_y_mg = (int16_t)(acc_y * 1000);
    int16_t acc_z_mg = (int16_t)(acc_z * 1000);
    
    mfg_data[offset++] = acc_x_mg & 0xFF;
    mfg_data[offset++] = (acc_x_mg >> 8) & 0xFF;
    mfg_data[offset++] = acc_y_mg & 0xFF;
    mfg_data[offset++] = (acc_y_mg >> 8) & 0xFF;
    mfg_data[offset++] = acc_z_mg & 0xFF;
    mfg_data[offset++] = (acc_z_mg >> 8) & 0xFF;
    
    // Timestamp (lower 32 bits of millis)
    uint32_t timestamp = millis();
    mfg_data[offset++] = timestamp & 0xFF;
    mfg_data[offset++] = (timestamp >> 8) & 0xFF;
    mfg_data[offset++] = (timestamp >> 16) & 0xFF;
    mfg_data[offset++] = (timestamp >> 24) & 0xFF;
    
    // Add manufacturer data to advertisement
    // Create manufacturer data string
    String mfg_string = "";
    
    // Add company ID (little endian)
    mfg_string += (char)(COMPANY_ID & 0xFF);
    mfg_string += (char)((COMPANY_ID >> 8) & 0xFF);
    
    // Add the rest of the data
    for (int i = 0; i < offset; i++) {
        mfg_string += (char)mfg_data[i];
    }
    
    adv_data.setManufacturerData(mfg_string);
    
    pAdvertising->setAdvertisementData(adv_data);
    pAdvertising->start();
}

void logPowerToFlash() {
    // Log power data at regular intervals
    if (millis() - last_power_log < POWER_LOG_INTERVAL_MS) return;
    last_power_log = millis();
    
    // Get power readings
    float vbat = M5.Power.getBatteryVoltage() / 1000.0;  // Convert to V
    float ibat = M5.Power.getBatteryCurrent();  // mA
    float power = vbat * abs(ibat);  // mW
    int battery_level = M5.Power.getBatteryLevel();  // %
    
    // Open file for append
    File logFile = LittleFS.open(LOG_FILE_PATH, "a");
    if (!logFile) {
        if (debug_mode && log_entry_count % 10 == 0) {
            Serial.println("ERROR: Failed to open log file for writing!");
        }
        return;
    }
    
    // Write data
    logFile.printf("%lu,%d,%d,%.3f,%d,%.3f,%.2f,%.2f,%d,%d\n",
        millis(),
        control_state,
        har_state,
        smoothed_uncertainty,
        current_adv_interval,
        vbat,
        ibat,
        power,
        battery_level,
        sequence_number
    );
    
    logFile.close();
    log_entry_count++;
    
    // Debug output every 10 entries
    if (debug_mode && log_entry_count % 10 == 0) {
        Serial.printf("[%lu] Logged entry #%lu - HAR:%d, Ctrl:%d, Int:%dms, I:%.1fmA, Bat:%d%%\n",
            millis(), log_entry_count, har_state, control_state, 
            current_adv_interval, ibat, battery_level);
    }
    
    // Update status file periodically
    if (log_entry_count % 60 == 0) {  // Every minute
        File statusFile = LittleFS.open(STATUS_FILE_PATH, "w");
        if (statusFile) {
            statusFile.printf("Entries: %lu\nRuntime: %lu min\nBattery: %d%%\n", 
                log_entry_count, 
                (millis() - experiment_start_time) / 60000,
                battery_level);
            statusFile.close();
        }
    }
}

void updateDisplay() {
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    
    if (operation_mode == MODE_DATA_DUMP) {
        M5.Display.println("Data Dump");
        M5.Display.println("Mode");
        return;
    }
    
    M5.Display.println("Flash Log");
    M5.Display.println("");
    
    // HAR state
    M5.Display.print("HAR: ");
    M5.Display.println(
        har_state == STATE_IDLE ? "IDLE" : 
        har_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN"
    );
    
    // Control state
    M5.Display.print("Ctrl: ");
    M5.Display.println(
        control_state == CONTROL_QUIET ? "QUIET" :
        control_state == CONTROL_ACTIVE ? "ACTIVE" : "UNCERT"
    );
    
    // Advertising interval
    M5.Display.printf("Int: %dms\n", current_adv_interval);
    
    // Log status
    M5.Display.printf("Log: %lu\n", log_entry_count);
    
    // Battery and runtime
    M5.Display.printf("Bat: %d%%\n", M5.Power.getBatteryLevel());
    M5.Display.printf("Run: %lumin\n", (millis() - experiment_start_time) / 60000);
}

void loop() {
    // Data dump mode - just wait
    if (operation_mode == MODE_DATA_DUMP) {
        delay(100);
        return;
    }
    
    M5.update();
    
    // Sample IMU at fixed rate
    if (millis() - last_sample_time >= SAMPLE_PERIOD_MS) {
        last_sample_time = millis();
        
        // Read IMU
        float acc_x, acc_y, acc_z;
        M5.Imu.getAccelData(&acc_x, &acc_y, &acc_z);
        
        // Store in circular buffer
        acc_buffer_x[buffer_index] = acc_x;
        acc_buffer_y[buffer_index] = acc_y;
        acc_buffer_z[buffer_index] = acc_z;
        
        buffer_index = (buffer_index + 1) % WINDOW_SIZE;
        if (buffer_index == 0) buffer_full = true;
        
        // Classify activity
        classifyActivity();
        
        // Update adaptive control
        updateControlState();
    }
    
    // Update BLE advertising
    updateBLEAdvertising();
    
    // Log power data to flash
    logPowerToFlash();
    
    // Update display every 500ms
    static uint32_t last_display_update = 0;
    if (millis() - last_display_update >= 500) {
        last_display_update = millis();
        updateDisplay();
    }
    
    // Manual save test with button
    if (M5.BtnA.wasPressed()) {
        Serial.println("\n[BUTTON] Manual save test");
        File testFile = LittleFS.open("/test_manual.txt", "w");
        if (testFile) {
            testFile.printf("Manual test at %lu ms\n", millis());
            testFile.close();
            Serial.println("Manual test file written");
        } else {
            Serial.println("ERROR: Could not write manual test file");
        }
    }
    
    // Check battery critically low
    if (M5.Power.getBatteryLevel() < 10) {
        // Final status update
        Serial.println("\n[WARNING] Low battery - saving final status");
        File statusFile = LittleFS.open(STATUS_FILE_PATH, "w");
        if (statusFile) {
            statusFile.printf("Low battery shutdown\nEntries: %lu\nRuntime: %lu min\n", 
                log_entry_count, 
                (millis() - experiment_start_time) / 60000);
            statusFile.close();
        }
        
        M5.Display.fillScreen(RED);
        M5.Display.println("Low Bat!");
        delay(5000);
        M5.Power.powerOff();
    }
    
    delay(1);
}