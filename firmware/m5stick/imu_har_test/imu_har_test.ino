#include <M5StickCPlus2.h>

// HAR parameters
#define SAMPLE_RATE_HZ 50
#define SAMPLE_PERIOD_MS (1000 / SAMPLE_RATE_HZ)
#define WINDOW_SIZE 100  // 2 seconds at 50Hz
#define ACTIVITY_THRESHOLD 0.15  // Acceleration variance threshold

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

HARState current_state = STATE_IDLE;
float uncertainty = 0.0;

void setup() {
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Imu.begin();
    
    Serial.begin(115200);
    Serial.println("IMU HAR Test Started");
    
    // Initialize buffers
    memset(acc_buffer_x, 0, sizeof(acc_buffer_x));
    memset(acc_buffer_y, 0, sizeof(acc_buffer_y));
    memset(acc_buffer_z, 0, sizeof(acc_buffer_z));
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

HARState classifyActivity() {
    if (!buffer_full) return STATE_UNCERTAIN;
    
    // Calculate variance for each axis
    float var_x = calculateVariance(acc_buffer_x, WINDOW_SIZE);
    float var_y = calculateVariance(acc_buffer_y, WINDOW_SIZE);
    float var_z = calculateVariance(acc_buffer_z, WINDOW_SIZE);
    
    // Combined variance (simple sum)
    float total_variance = var_x + var_y + var_z;
    
    // Simple threshold-based classification
    if (total_variance > ACTIVITY_THRESHOLD) {
        uncertainty = 0.2;  // Low uncertainty for clear activity
        return STATE_ACTIVE;
    } else if (total_variance < ACTIVITY_THRESHOLD * 0.3) {
        uncertainty = 0.1;  // Low uncertainty for clear idle
        return STATE_IDLE;
    } else {
        uncertainty = 0.8;  // High uncertainty in transition zone
        return STATE_UNCERTAIN;
    }
}

void loop() {
    M5.update();
    
    static uint32_t last_sample = 0;
    if (millis() - last_sample >= SAMPLE_PERIOD_MS) {
        last_sample = millis();
        
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
        HARState new_state = classifyActivity();
        
        // State change detection
        if (new_state != current_state) {
            Serial.printf("State change: %s -> %s (uncertainty: %.2f)\n",
                current_state == STATE_IDLE ? "IDLE" : 
                current_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN",
                new_state == STATE_IDLE ? "IDLE" : 
                new_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN",
                uncertainty);
            current_state = new_state;
        }
        
        // Update display
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("HAR Test");
        M5.Display.println("");
        M5.Display.print("State: ");
        M5.Display.println(
            current_state == STATE_IDLE ? "IDLE" : 
            current_state == STATE_ACTIVE ? "ACTIVE" : "UNCERTAIN"
        );
        M5.Display.printf("Uncert: %.2f\n", uncertainty);
        M5.Display.printf("Acc: %.2f\n", sqrt(acc_x*acc_x + acc_y*acc_y + acc_z*acc_z));
    }
    
    delay(1);
}