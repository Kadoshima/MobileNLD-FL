# Technical Implementation Guide

## 🏗 Architecture Deep Dive

### System Overview
```
┌─────────────────────────────────────────┐
│           nRF52840 MCU                   │
│  ┌─────────────────────────────────┐    │
│  │  Main Loop (10Hz)                │    │
│  │  ├─ Read IMU (50Hz via DMA)      │    │
│  │  ├─ Window Buffer (2s @ 50Hz)    │    │
│  │  ├─ Feature Extraction           │    │
│  │  ├─ TFLite Inference            │    │
│  │  ├─ Uncertainty Calculation      │    │
│  │  ├─ State Machine Update         │    │
│  │  └─ BLE Advertise (adaptive)     │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
                    ↓ BLE
┌─────────────────────────────────────────┐
│          Android Phone                   │
│  ┌─────────────────────────────────┐    │
│  │  BLE Scanner Service             │    │
│  │  ├─ Continuous Scanning          │    │
│  │  ├─ Packet Parser               │    │
│  │  ├─ Timestamp Logger            │    │
│  │  └─ CSV Writer                  │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## 📡 BLE Advertising Format

### Packet Structure (31 bytes)
```c
typedef struct {
    uint8_t  length;           // 0x1E (30 bytes follow)
    uint8_t  type;            // 0xFF (Manufacturer Specific)
    uint16_t company_id;      // 0xFFFF (test)
    uint8_t  version;         // Protocol version (0x01)
    uint16_t session_id;      // Random session identifier
    uint8_t  activity_state;  // 0=Idle, 1=Active
    uint8_t  uncertainty_q8;  // Uncertainty [0-255] (Q8 format)
    uint8_t  battery_pct;     // Battery [0-100]%
    uint8_t  sequence;        // Packet sequence [0-255]
    uint16_t tick_lsb;        // Timestamp LSB (ms)
    uint8_t  flags;           // Status flags
    uint8_t  reserved[15];    // Future use / padding
} __attribute__((packed)) ble_adv_data_t;
```

### Advertising Parameters
```c
// Adaptive intervals based on state
#define ADV_INTERVAL_QUIET     1600  // 1000ms (1600*0.625)
#define ADV_INTERVAL_UNCERTAIN 320   // 200ms
#define ADV_INTERVAL_ACTIVE    160   // 100ms

// Fixed parameters
#define ADV_TIMEOUT_DISABLED   0
#define ADV_MAX_EVENTS        0      // No limit
#define TX_POWER_DBM          0      // 0 dBm default
```

## 🧠 HAR Model Architecture

### Model Specification
```python
# TensorFlow model (before quantization)
model = Sequential([
    Input(shape=(100, 6)),  # 2s window @ 50Hz, 6 axes
    
    # Feature extraction
    Conv1D(16, 5, activation='relu'),
    MaxPooling1D(2),
    
    # Classification
    Conv1D(32, 3, activation='relu'),
    GlobalAveragePooling1D(),
    Dense(16, activation='relu'),
    Dropout(0.3),
    
    # Output with uncertainty
    Dense(2, activation='softmax')  # [Idle, Active]
])

# Post-training quantization
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset
converter.target_spec.supported_types = [tf.int8]
```

### Inference Pipeline
```c
// Feature extraction from raw IMU
void extract_features(float raw_data[100][6], int8_t features[600]) {
    // Normalize to [-128, 127] for INT8
    for (int i = 0; i < 600; i++) {
        float normalized = (raw_data[i/6][i%6] - mean[i%6]) / std[i%6];
        features[i] = (int8_t)(normalized * 127.0f);
    }
}

// Run inference
void run_inference(int8_t features[], float output[2]) {
    TfLiteStatus status = interpreter->Invoke();
    // Output is quantized, dequantize to [0,1]
    int8_t* raw_output = interpreter->output(0)->data.int8;
    for (int i = 0; i < 2; i++) {
        output[i] = (raw_output[i] + 128) / 255.0f;
    }
}
```

## 🎯 Uncertainty Calculation

### Entropy-Based Uncertainty
```c
float calculate_uncertainty(float probs[], int n_classes) {
    float entropy = 0.0f;
    for (int i = 0; i < n_classes; i++) {
        if (probs[i] > 0.0001f) {
            entropy -= probs[i] * log2f(probs[i]);
        }
    }
    // Normalize to [0,1]
    return entropy / log2f(n_classes);
}
```

### Temporal Volatility
```c
typedef struct {
    float history[VOLATILITY_WINDOW];
    int index;
    float ewma;
} volatility_tracker_t;

float update_volatility(volatility_tracker_t* tracker, float uncertainty) {
    // Add to circular buffer
    tracker->history[tracker->index] = uncertainty;
    tracker->index = (tracker->index + 1) % VOLATILITY_WINDOW;
    
    // Calculate variance
    float mean = 0, variance = 0;
    for (int i = 0; i < VOLATILITY_WINDOW; i++) {
        mean += tracker->history[i];
    }
    mean /= VOLATILITY_WINDOW;
    
    for (int i = 0; i < VOLATILITY_WINDOW; i++) {
        float diff = tracker->history[i] - mean;
        variance += diff * diff;
    }
    
    // EWMA smoothing
    float volatility = sqrtf(variance / VOLATILITY_WINDOW);
    tracker->ewma = 0.7f * tracker->ewma + 0.3f * volatility;
    return tracker->ewma;
}
```

### Composite Context Score
```c
float calculate_context_score(float uncertainty, float volatility) {
    // Weighted combination
    const float ALPHA = 0.7f;  // Weight for uncertainty
    const float BETA = 0.3f;   // Weight for volatility
    
    return ALPHA * uncertainty + BETA * volatility;
}
```

## 🔄 State Machine

### State Definitions
```c
typedef enum {
    STATE_QUIET,      // Low activity, long intervals
    STATE_UNCERTAIN,  // Transition, medium intervals
    STATE_ACTIVE      // High activity, short intervals
} system_state_t;

typedef struct {
    system_state_t current;
    system_state_t previous;
    float context_score;
    uint32_t state_duration_ms;
    uint32_t total_transitions;
} state_machine_t;
```

### State Transition Logic
```c
void update_state_machine(state_machine_t* sm, float context_score) {
    sm->context_score = context_score;
    sm->state_duration_ms += LOOP_PERIOD_MS;
    
    system_state_t next_state = sm->current;
    
    // Hysteresis thresholds
    const float THRESH_LOW = 0.3f;
    const float THRESH_HIGH = 0.7f;
    const float HYSTERESIS = 0.1f;
    
    switch (sm->current) {
        case STATE_QUIET:
            if (context_score > THRESH_LOW + HYSTERESIS) {
                next_state = STATE_UNCERTAIN;
            }
            break;
            
        case STATE_UNCERTAIN:
            if (context_score < THRESH_LOW - HYSTERESIS) {
                next_state = STATE_QUIET;
            } else if (context_score > THRESH_HIGH + HYSTERESIS) {
                next_state = STATE_ACTIVE;
            }
            break;
            
        case STATE_ACTIVE:
            if (context_score < THRESH_HIGH - HYSTERESIS) {
                next_state = STATE_UNCERTAIN;
            }
            break;
    }
    
    // State change
    if (next_state != sm->current) {
        sm->previous = sm->current;
        sm->current = next_state;
        sm->state_duration_ms = 0;
        sm->total_transitions++;
        
        // Update BLE advertising interval
        update_ble_interval(next_state);
    }
}
```

## ⚡ Power Optimization

### MCU Power Modes
```c
// Configure low-power modes
void configure_power_optimization() {
    // Enable DC-DC converter
    NRF_POWER->DCDCEN = 1;
    
    // Configure system OFF mode for unused peripherals
    nrf_gpio_cfg_sense_set(BUTTON_PIN, NRF_GPIO_PIN_SENSE_LOW);
    
    // Set up low-frequency clock
    NRF_CLOCK->LFCLKSRC = CLOCK_LFCLKSRC_SRC_Xtal;
    
    // Configure RAM retention (keep only needed sections)
    NRF_POWER->RAM[0].POWERSET = 0x0003;  // Keep 32KB
}

// Main loop with sleep
void main_loop() {
    while (1) {
        // Process HAR
        if (new_imu_data_ready()) {
            process_har_pipeline();
        }
        
        // Enter low-power mode until next event
        __WFE();  // Wait for event (IMU interrupt or timer)
        __SEV();  // Clear event
        __WFE();  // Wait again
    }
}
```

### Peripheral Management
```c
// Dynamic peripheral control
void manage_peripherals(system_state_t state) {
    switch (state) {
        case STATE_QUIET:
            // Reduce IMU sampling rate
            imu_set_odr(IMU_ODR_25HZ);
            // Increase UART latency
            nrf_uarte_baudrate_set(NRF_UARTE0, NRF_UARTE_BAUDRATE_9600);
            break;
            
        case STATE_ACTIVE:
            // Full IMU rate
            imu_set_odr(IMU_ODR_50HZ);
            // Normal UART
            nrf_uarte_baudrate_set(NRF_UARTE0, NRF_UARTE_BAUDRATE_115200);
            break;
    }
}
```

## 📱 Android Implementation

### BLE Scanner Service
```kotlin
class BLEAdaptiveScanner : Service() {
    private val scanner = BluetoothAdapter.getDefaultAdapter().bluetoothLeScanner
    private val csvWriter = CSVPacketLogger()
    
    private val scanSettings = ScanSettings.Builder()
        .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
        .setReportDelay(0)  // Immediate callback
        .build()
    
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val packet = parseAdvertisement(result.scanRecord.bytes)
            val timestamp = SystemClock.elapsedRealtimeNanos()
            
            // Log to CSV
            csvWriter.logPacket(
                timestamp = timestamp,
                rssi = result.rssi,
                packet = packet
            )
            
            // Update UI
            broadcastUpdate(packet)
        }
    }
    
    private fun parseAdvertisement(bytes: ByteArray): AdaptivePacket {
        // Parse according to format specification
        return AdaptivePacket(
            sessionId = bytes.getShort(4),
            state = bytes[6],
            uncertainty = bytes[7].toUByte().toFloat() / 255f,
            battery = bytes[8],
            sequence = bytes[9],
            tickLsb = bytes.getShort(10)
        )
    }
}
```

## 📊 Analysis Scripts

### Power Analysis
```python
def analyze_power_consumption(ppk2_csv, packet_log_csv):
    # Load power measurements
    power_df = pd.read_csv(ppk2_csv)
    power_df['timestamp_ms'] = power_df['timestamp'] * 1000
    
    # Load packet log
    packets_df = pd.read_csv(packet_log_csv)
    
    # Align timestamps
    packets_df['state'] = packets_df['activity_state'].map({
        0: 'QUIET', 1: 'UNCERTAIN', 2: 'ACTIVE'
    })
    
    # Calculate average current per state
    results = {}
    for state in ['QUIET', 'UNCERTAIN', 'ACTIVE']:
        state_packets = packets_df[packets_df['state'] == state]
        
        # Find corresponding power windows
        state_power = []
        for _, packet in state_packets.iterrows():
            window = power_df[
                (power_df['timestamp_ms'] >= packet['timestamp_ms'] - 100) &
                (power_df['timestamp_ms'] <= packet['timestamp_ms'] + 100)
            ]
            state_power.append(window['current_mA'].mean())
        
        results[state] = {
            'mean_current_mA': np.mean(state_power),
            'std_current_mA': np.std(state_power),
            'samples': len(state_power)
        }
    
    return results
```

### Latency Analysis
```python
def analyze_latency(packet_log_csv):
    df = pd.read_csv(packet_log_csv)
    
    # Calculate inter-packet intervals
    df['interval_ms'] = df['timestamp_ms'].diff()
    
    # Group by state
    latency_stats = df.groupby('activity_state')['interval_ms'].agg([
        ('p50', lambda x: x.quantile(0.50)),
        ('p95', lambda x: x.quantile(0.95)),
        ('p99', lambda x: x.quantile(0.99)),
        ('mean', 'mean'),
        ('std', 'std')
    ])
    
    return latency_stats
```

## 🔧 Debugging & Tuning

### UART Debug Commands
```c
// Interactive tuning via UART
void process_uart_command(char* cmd) {
    if (strcmp(cmd, "status") == 0) {
        printf("State: %s, Score: %.2f, Interval: %dms\n",
               state_names[current_state],
               context_score,
               current_interval_ms);
               
    } else if (strncmp(cmd, "thresh", 6) == 0) {
        float low, high;
        sscanf(cmd, "thresh %f %f", &low, &high);
        update_thresholds(low, high);
        
    } else if (strcmp(cmd, "dump") == 0) {
        dump_statistics();
    }
}
```

### Performance Profiling
```c
// Timing measurements
typedef struct {
    uint32_t imu_read_us;
    uint32_t inference_us;
    uint32_t ble_update_us;
    uint32_t total_loop_us;
} profiling_stats_t;

void profile_performance() {
    uint32_t start = get_microseconds();
    
    // Measure each component
    uint32_t t1 = get_microseconds();
    read_imu_data();
    stats.imu_read_us = get_microseconds() - t1;
    
    uint32_t t2 = get_microseconds();
    run_inference();
    stats.inference_us = get_microseconds() - t2;
    
    // Log if exceeding budget
    stats.total_loop_us = get_microseconds() - start;
    if (stats.total_loop_us > 100000) {  // 100ms budget
        LOG_WARN("Loop time exceeded: %d us", stats.total_loop_us);
    }
}
```

---
*Complete technical reference for implementation*  
*Last Updated: 2024-12-17*