#include <M5StickCPlus2.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>

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

// Stability detection parameters
#define STABILITY_WINDOW_SEC 10  // 10 seconds window
#define STABILITY_THRESHOLD 0.8  // 80% stable = stable state

// BLE advertising intervals (ms)
#define ADV_INTERVAL_QUIET 2000
#define ADV_INTERVAL_UNCERTAIN 500
#define ADV_INTERVAL_ACTIVE 100

// Power measurement interval
#define POWER_LOG_INTERVAL_MS 1000

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
HARState prev_har_state = STATE_IDLE;
ControlState control_state = CONTROL_UNCERTAIN;
float raw_uncertainty = 0.5;
float smoothed_uncertainty = 0.5;  // EWMA smoothed value
uint32_t last_state_change = 0;
uint16_t current_adv_interval = ADV_INTERVAL_UNCERTAIN;

// Stability detection variables
int transition_count = 0;
uint32_t stability_window_start = 0;
float stability_score = 1.0;  // 1.0 = stable, 0.0 = unstable
float composite_context_score = 0.5;  // CCS

// BLE variables
BLEAdvertising *pAdvertising;
uint8_t sequence_number = 0;
uint16_t session_id;
bool ble_initialized = false;

// Timing
uint32_t last_sample_time = 0;
uint32_t last_adv_time = 0;
uint32_t last_power_log = 0;

// Power measurement
bool csv_header_printed = false;

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    M5.Imu.begin();
    
    Serial.begin(115200);
    Serial.println("BLE Adaptive HAR with Stability Detection");
    
    // Generate session ID
    session_id = SESSION_ID;
    Serial.printf("Session ID: 0x%04X\n", session_id);
    
    // Initialize buffers
    memset(acc_buffer_x, 0, sizeof(acc_buffer_x));
    memset(acc_buffer_y, 0, sizeof(acc_buffer_y));
    memset(acc_buffer_z, 0, sizeof(acc_buffer_z));
    
    // Initialize stability window
    stability_window_start = millis();
    
    // Initialize BLE
    initBLE();
}

void initBLE() {
    BLEDevice::init(DEVICE_NAME);
    
    // Get advertising instance
    pAdvertising = BLEDevice::getAdvertising();
    
    // Set advertising type to non-connectable
    pAdvertising->setAdvertisementType(ADV_TYPE_NONCONN_IND);
    
    ble_initialized = true;
    Serial.println("BLE initialized");
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
    
    // Store previous state for transition detection
    prev_har_state = har_state;
    
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

void updateStabilityScore() {
    // Check if we need to reset the window
    uint32_t current_time = millis();
    if (current_time - stability_window_start > STABILITY_WINDOW_SEC * 1000) {
        // Reset window
        transition_count = 0;
        stability_window_start = current_time;
    }
    
    // Count transitions
    if (har_state != prev_har_state) {
        transition_count++;
    }
    
    // Calculate stability score (0.0 = many transitions, 1.0 = no transitions)
    float max_transitions = STABILITY_WINDOW_SEC * 2;  // Max 2 transitions per second
    stability_score = 1.0 - (transition_count / max_transitions);
    stability_score = constrain(stability_score, 0.0, 1.0);
}

void updateControlState() {
    // Apply EWMA to uncertainty
    smoothed_uncertainty = EWMA_ALPHA * raw_uncertainty + 
                          (1.0 - EWMA_ALPHA) * smoothed_uncertainty;
    
    // Update stability score
    updateStabilityScore();
    
    // Calculate Composite Context Score (CCS)
    // High CCS = unstable/uncertain (need frequent updates)
    // Low CCS = stable/certain (can reduce updates)
    composite_context_score = 0.6 * smoothed_uncertainty + 0.4 * (1.0 - stability_score);
    
    // Check rate limiting
    uint32_t time_since_change = millis() - last_state_change;
    bool can_change = (time_since_change >= RATE_LIMIT_MS);
    
    ControlState new_state = control_state;
    
    // New state machine logic based on HAR state and stability
    if (har_state == STATE_ACTIVE) {
        if (stability_score > STABILITY_THRESHOLD && smoothed_uncertainty < 0.3) {
            // Stable ACTIVE: reduce to medium interval
            new_state = CONTROL_UNCERTAIN;  // 500ms
        } else {
            // Unstable ACTIVE: keep high frequency
            new_state = CONTROL_ACTIVE;  // 100ms
        }
    } else if (har_state == STATE_IDLE) {
        if (smoothed_uncertainty < THETA_Q_IN) {
            // Stable IDLE: maximum power saving
            new_state = CONTROL_QUIET;  // 2000ms
        } else {
            // Uncertain IDLE: medium frequency
            new_state = CONTROL_UNCERTAIN;  // 500ms
        }
    } else {  // STATE_UNCERTAIN
        // Always use medium frequency for uncertain states
        new_state = CONTROL_UNCERTAIN;  // 500ms
    }
    
    // Update state and advertising interval if changed and allowed
    if (new_state != control_state && can_change) {
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
        
        Serial.printf("Control state changed to %s, interval=%dms (HAR=%s, Stability=%.2f, CCS=%.2f)\n",
            control_state == CONTROL_QUIET ? "QUIET" :
            control_state == CONTROL_ACTIVE ? "ACTIVE" : "UNCERTAIN",
            current_adv_interval,
            har_state == STATE_IDLE ? "IDLE" :
            har_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN",
            stability_score,
            composite_context_score);
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

void logPowerData() {
    // Log power data at regular intervals
    if (millis() - last_power_log < POWER_LOG_INTERVAL_MS) return;
    last_power_log = millis();
    
    // Get power readings
    float vbat = M5.Power.getBatteryVoltage() / 1000.0;  // Convert to V
    float ibat = M5.Power.getBatteryCurrent();  // mA
    float power = vbat * abs(ibat);  // mW
    int battery_level = M5.Power.getBatteryLevel();  // %
    
    // Print CSV header once
    if (!csv_header_printed) {
        Serial.println("timestamp_ms,control_state,har_state,uncertainty,stability_score,ccs,adv_interval_ms,voltage_V,current_mA,power_mW,battery_pct,packets_sent,transitions");
        csv_header_printed = true;
    }
    
    // Log data
    Serial.printf("%lu,%d,%d,%.3f,%.3f,%.3f,%d,%.3f,%.2f,%.2f,%d,%d,%d\n",
        millis(),
        control_state,
        har_state,
        smoothed_uncertainty,
        stability_score,
        composite_context_score,
        current_adv_interval,
        vbat,
        ibat,
        power,
        battery_level,
        sequence_number,
        transition_count
    );
}

void updateDisplay() {
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Adaptive HAR");
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
    
    // Stability
    M5.Display.printf("Stab: %.2f\n", stability_score);
    
    // CCS
    M5.Display.printf("CCS: %.2f\n", composite_context_score);
    
    // Advertising interval
    M5.Display.printf("Int: %dms\n", current_adv_interval);
    
    // Power info
    M5.Display.printf("I: %.1fmA\n", M5.Power.getBatteryCurrent());
}

void loop() {
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
    
    // Log power data
    logPowerData();
    
    // Update display every 100ms
    static uint32_t last_display_update = 0;
    if (millis() - last_display_update >= 100) {
        last_display_update = millis();
        updateDisplay();
    }
    
    delay(1);
}