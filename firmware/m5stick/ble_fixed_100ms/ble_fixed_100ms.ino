#include <M5StickCPlus2.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEAdvertising.h>

// Configuration
#define DEVICE_NAME     "M5HAR_01"
#define COMPANY_ID      0x5900  // 研究用仮ID
#define ADV_INTERVAL_MS 100     // 固定100ms

// Global variables
BLEAdvertising *pAdvertising;
uint32_t packet_count = 0;
uint8_t sequence_num = 0;

// Manufacturer data structure (23 bytes total)
struct __attribute__((packed)) ManufacturerData {
    uint16_t company_id;    // 0x5900
    uint8_t  device_type;   // 0x01 = M5StickC
    uint8_t  sequence;      // Packet sequence number
    uint8_t  state;         // HAR state (0=Idle, 1=Active)
    uint8_t  uncertainty;   // Uncertainty metric (0-255)
    uint16_t interval_ms;   // Current advertising interval
    uint8_t  battery_pct;   // Battery percentage
    int16_t  acc_x;         // Accelerometer X (mg)
    int16_t  acc_y;         // Accelerometer Y (mg)
    int16_t  acc_z;         // Accelerometer Z (mg)
    uint32_t timestamp;     // Device uptime (ms)
};

void setup() {
    // Initialize M5StickC Plus2
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.fillScreen(BLACK);
    M5.Display.setTextColor(WHITE);
    M5.Display.setTextSize(2);
    
    // Display startup info
    M5.Display.setCursor(0, 0);
    M5.Display.println("BLE Test");
    M5.Display.println("Fixed 100ms");
    
    // Initialize IMU
    M5.Imu.begin();
    
    // Initialize BLE
    Serial.begin(115200);
    Serial.println("Starting BLE Advertising...");
    
    BLEDevice::init(DEVICE_NAME);
    
    // Create BLE Server (required for advertising)
    BLEServer *pServer = BLEDevice::createServer();
    
    // Get advertising instance
    pAdvertising = BLEDevice::getAdvertising();
    
    // Configure advertising
    pAdvertising->setMinInterval(ADV_INTERVAL_MS * 0.625); // Convert to 0.625ms units
    pAdvertising->setMaxInterval(ADV_INTERVAL_MS * 0.625);
    
    // Start advertising
    updateAdvertisingData();
    pAdvertising->start();
    
    Serial.println("BLE Advertising started!");
}

void updateAdvertisingData() {
    // Read IMU data
    float acc_x, acc_y, acc_z;
    M5.Imu.getAccelData(&acc_x, &acc_y, &acc_z);
    
    // Read battery level
    uint8_t battery_pct = M5.Power.getBatteryLevel();
    
    // Create manufacturer data
    ManufacturerData mfg_data;
    mfg_data.company_id = COMPANY_ID;
    mfg_data.device_type = 0x01;
    mfg_data.sequence = sequence_num++;
    mfg_data.state = 0;  // Will be updated with HAR
    mfg_data.uncertainty = 0;  // Will be calculated
    mfg_data.interval_ms = ADV_INTERVAL_MS;
    mfg_data.battery_pct = battery_pct;
    mfg_data.acc_x = (int16_t)(acc_x * 1000);  // Convert to mg
    mfg_data.acc_y = (int16_t)(acc_y * 1000);
    mfg_data.acc_z = (int16_t)(acc_z * 1000);
    mfg_data.timestamp = millis();
    
    // Set manufacturer data
    BLEAdvertisementData adv_data;
    String manufacturerData((char*)&mfg_data, sizeof(mfg_data));
    adv_data.setManufacturerData(manufacturerData);
    adv_data.setFlags(0x06); // BR/EDR not supported, General discoverable
    
    pAdvertising->setAdvertisementData(adv_data);
}

void loop() {
    M5.update();
    
    // Update advertising data every interval
    static uint32_t last_update = 0;
    if (millis() - last_update >= ADV_INTERVAL_MS) {
        last_update = millis();
        
        // Stop, update, restart (required for data change)
        pAdvertising->stop();
        updateAdvertisingData();
        pAdvertising->start();
        
        packet_count++;
        
        // Update display
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("BLE Active");
        M5.Display.printf("Pkts: %lu\n", packet_count);
        M5.Display.printf("Seq: %d\n", sequence_num);
        M5.Display.printf("Batt: %d%%\n", M5.Power.getBatteryLevel());
        
        // Log to serial
        if (packet_count % 10 == 0) {
            Serial.printf("Packets sent: %lu\n", packet_count);
        }
    }
    
    // Button A: Reset counter
    if (M5.BtnA.wasPressed()) {
        packet_count = 0;
        sequence_num = 0;
        Serial.println("Counters reset");
    }
    
    // Prevent WDT reset
    delay(1);
}