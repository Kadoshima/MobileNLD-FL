/**
 * M5Stack Sensor Node - EdgeHAR System
 * Device 1: IMU data collection and BLE transmission
 */

#include <M5Core2.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// BLE Configuration
#define DEVICE_NAME "M5Stack_HAR_Sensor"
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_UUID_IMU "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_UUID_BATTERY "2a19"  // Standard battery level UUID

// IMU Configuration
#define SAMPLE_RATE 50  // Hz
#define WINDOW_SIZE 128  // Samples per window
#define FEATURES_PER_AXIS 2  // Mean and std dev

// Global variables
BLEServer* pServer = NULL;
BLECharacteristic* pCharIMU = NULL;
BLECharacteristic* pCharBattery = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

float accX[WINDOW_SIZE], accY[WINDOW_SIZE], accZ[WINDOW_SIZE];
float gyroX[WINDOW_SIZE], gyroY[WINDOW_SIZE], gyroZ[WINDOW_SIZE];
int sampleIndex = 0;
unsigned long lastSampleTime = 0;

// BLE callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        M5.Lcd.fillScreen(GREEN);
        M5.Lcd.setCursor(10, 10);
        M5.Lcd.print("Connected");
    }

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        M5.Lcd.fillScreen(RED);
        M5.Lcd.setCursor(10, 10);
        M5.Lcd.print("Disconnected");
    }
};

void setup() {
    // Initialize M5Stack
    M5.begin();
    M5.IMU.Init();
    
    // Setup display
    M5.Lcd.setTextSize(2);
    M5.Lcd.fillScreen(BLACK);
    M5.Lcd.setCursor(10, 10);
    M5.Lcd.println("EdgeHAR Sensor Node");
    M5.Lcd.println("Initializing...");
    
    // Initialize BLE
    initBLE();
    
    M5.Lcd.println("Ready!");
    M5.Lcd.println("Waiting for connection...");
}

void initBLE() {
    BLEDevice::init(DEVICE_NAME);
    
    // Create BLE Server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    
    // Create BLE Service
    BLEService *pService = pServer->createService(SERVICE_UUID);
    
    // Create IMU Characteristic
    pCharIMU = pService->createCharacteristic(
        CHAR_UUID_IMU,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharIMU->addDescriptor(new BLE2902());
    
    // Create Battery Characteristic
    pCharBattery = pService->createCharacteristic(
        CHAR_UUID_BATTERY,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharBattery->addDescriptor(new BLE2902());
    
    // Start service
    pService->start();
    
    // Start advertising
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(false);
    pAdvertising->setMinPreferred(0x0);
    BLEDevice::startAdvertising();
}

void loop() {
    // Handle BLE reconnection
    if (!deviceConnected && oldDeviceConnected) {
        delay(500);
        pServer->startAdvertising();
        oldDeviceConnected = deviceConnected;
    }
    
    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }
    
    // Sample IMU data at fixed rate
    unsigned long currentTime = millis();
    if (currentTime - lastSampleTime >= (1000 / SAMPLE_RATE)) {
        collectIMUData();
        lastSampleTime = currentTime;
    }
    
    // Update battery level every 10 seconds
    static unsigned long lastBatteryUpdate = 0;
    if (currentTime - lastBatteryUpdate >= 10000) {
        updateBatteryLevel();
        lastBatteryUpdate = currentTime;
    }
    
    // Update display
    updateDisplay();
    
    M5.update();
}

void collectIMUData() {
    float ax, ay, az, gx, gy, gz;
    
    // Read IMU data
    M5.IMU.getAccelData(&ax, &ay, &az);
    M5.IMU.getGyroData(&gx, &gy, &gz);
    
    // Store in buffers
    accX[sampleIndex] = ax;
    accY[sampleIndex] = ay;
    accZ[sampleIndex] = az;
    gyroX[sampleIndex] = gx;
    gyroY[sampleIndex] = gy;
    gyroZ[sampleIndex] = gz;
    
    sampleIndex++;
    
    // When window is full, compute features and send
    if (sampleIndex >= WINDOW_SIZE) {
        computeAndSendFeatures();
        sampleIndex = 0;
    }
}

void computeAndSendFeatures() {
    if (!deviceConnected) return;
    
    float features[6];  // mean_ax, mean_ay, mean_az, std_ax, std_ay, std_az
    
    // Compute mean
    features[0] = computeMean(accX, WINDOW_SIZE);
    features[1] = computeMean(accY, WINDOW_SIZE);
    features[2] = computeMean(accZ, WINDOW_SIZE);
    
    // Compute standard deviation
    features[3] = computeStdDev(accX, WINDOW_SIZE, features[0]);
    features[4] = computeStdDev(accY, WINDOW_SIZE, features[1]);
    features[5] = computeStdDev(accZ, WINDOW_SIZE, features[2]);
    
    // Pack features into byte array for BLE transmission
    uint8_t data[24];  // 6 features * 4 bytes each
    memcpy(data, features, 24);
    
    // Send via BLE
    pCharIMU->setValue(data, 24);
    pCharIMU->notify();
}

float computeMean(float* data, int size) {
    float sum = 0;
    for (int i = 0; i < size; i++) {
        sum += data[i];
    }
    return sum / size;
}

float computeStdDev(float* data, int size, float mean) {
    float sum = 0;
    for (int i = 0; i < size; i++) {
        float diff = data[i] - mean;
        sum += diff * diff;
    }
    return sqrt(sum / size);
}

void updateBatteryLevel() {
    if (!deviceConnected) return;
    
    // Get battery level (0-100%)
    int batteryLevel = M5.Power.getBatteryLevel();
    
    uint8_t level = (uint8_t)batteryLevel;
    pCharBattery->setValue(&level, 1);
    pCharBattery->notify();
}

void updateDisplay() {
    static unsigned long lastDisplayUpdate = 0;
    unsigned long currentTime = millis();
    
    if (currentTime - lastDisplayUpdate >= 1000) {  // Update every second
        M5.Lcd.fillRect(0, 60, 320, 180, BLACK);
        M5.Lcd.setCursor(10, 60);
        
        if (deviceConnected) {
            M5.Lcd.setTextColor(GREEN);
            M5.Lcd.println("Status: Connected");
        } else {
            M5.Lcd.setTextColor(RED);
            M5.Lcd.println("Status: Disconnected");
        }
        
        M5.Lcd.setTextColor(WHITE);
        M5.Lcd.print("Samples: ");
        M5.Lcd.println(sampleIndex);
        
        M5.Lcd.print("Battery: ");
        M5.Lcd.print(M5.Power.getBatteryLevel());
        M5.Lcd.println("%");
        
        // Display current acceleration
        float ax, ay, az;
        M5.IMU.getAccelData(&ax, &ay, &az);
        M5.Lcd.print("Acc: ");
        M5.Lcd.printf("%.2f, %.2f, %.2f", ax, ay, az);
        
        lastDisplayUpdate = currentTime;
    }
}