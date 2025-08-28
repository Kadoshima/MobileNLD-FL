#include <M5StickCPlus2.h>

// キャリブレーション用のオフセット
float acc_offset_x = 0;
float acc_offset_y = 0;
float acc_offset_z = 0;

// 統計値
float acc_min_x = 999, acc_max_x = -999;
float acc_min_y = 999, acc_max_y = -999;
float acc_min_z = 999, acc_max_z = -999;

bool calibrated = false;

void setup() {
    // 電源維持（Plus2用）
    pinMode(4, OUTPUT);
    digitalWrite(4, HIGH);
    
    auto cfg = M5.config();
    M5.begin(cfg);
    M5.Display.setRotation(1);
    M5.Display.setTextSize(2);
    M5.Imu.begin();
    
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("=== IMU Accuracy Test ===");
    Serial.println("Place device flat on table");
    Serial.println("Press BtnA to calibrate");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("IMU Test");
    M5.Display.println("");
    M5.Display.println("Place flat");
    M5.Display.println("BtnA: Cal");
}

void calibrateIMU() {
    Serial.println("\n=== Calibrating IMU ===");
    Serial.println("Keep device still...");
    
    M5.Display.fillScreen(BLACK);
    M5.Display.setCursor(0, 0);
    M5.Display.println("Calibrating");
    M5.Display.println("Keep still!");
    
    float sum_x = 0, sum_y = 0, sum_z = 0;
    int samples = 100;
    
    for (int i = 0; i < samples; i++) {
        float ax, ay, az;
        M5.Imu.getAccelData(&ax, &ay, &az);
        sum_x += ax;
        sum_y += ay;
        sum_z += az;
        delay(10);
    }
    
    // 平均値を計算
    acc_offset_x = sum_x / samples;
    acc_offset_y = sum_y / samples;
    acc_offset_z = sum_z / samples - 1.0;  // Z軸は1gを引く
    
    Serial.printf("Offsets: X=%.3f, Y=%.3f, Z=%.3f\n", 
                  acc_offset_x, acc_offset_y, acc_offset_z);
    
    calibrated = true;
    
    M5.Display.println("");
    M5.Display.println("Done!");
    delay(1000);
}

void loop() {
    M5.update();
    
    // キャリブレーション
    if (M5.BtnA.wasPressed()) {
        calibrateIMU();
    }
    
    // 生データ取得
    float ax_raw, ay_raw, az_raw;
    M5.Imu.getAccelData(&ax_raw, &ay_raw, &az_raw);
    
    // キャリブレーション適用
    float ax = ax_raw - acc_offset_x;
    float ay = ay_raw - acc_offset_y;
    float az = az_raw - acc_offset_z;
    
    // 統計更新
    if (ax < acc_min_x) acc_min_x = ax;
    if (ax > acc_max_x) acc_max_x = ax;
    if (ay < acc_min_y) acc_min_y = ay;
    if (ay > acc_max_y) acc_max_y = ay;
    if (az < acc_min_z) acc_min_z = az;
    if (az > acc_max_z) acc_max_z = az;
    
    // 合成加速度（重力除去なし）
    float acc_magnitude = sqrt(ax*ax + ay*ay + az*az);
    
    // mg単位への変換
    int16_t ax_mg = (int16_t)(ax * 1000);
    int16_t ay_mg = (int16_t)(ay * 1000);
    int16_t az_mg = (int16_t)(az * 1000);
    
    // 分散計算用（HARと同じアルゴリズム）
    static float variance_buffer[50];
    static int var_index = 0;
    variance_buffer[var_index] = acc_magnitude;
    var_index = (var_index + 1) % 50;
    
    // 簡易分散計算
    float mean = 0;
    for (int i = 0; i < 50; i++) {
        mean += variance_buffer[i];
    }
    mean /= 50;
    
    float variance = 0;
    for (int i = 0; i < 50; i++) {
        float diff = variance_buffer[i] - mean;
        variance += diff * diff;
    }
    variance /= 50;
    
    // シリアル出力（100ms毎）
    static uint32_t last_print = 0;
    if (millis() - last_print >= 100) {
        last_print = millis();
        
        Serial.printf("Raw: X=%.3f Y=%.3f Z=%.3f g\n", ax_raw, ay_raw, az_raw);
        if (calibrated) {
            Serial.printf("Cal: X=%.3f Y=%.3f Z=%.3f g\n", ax, ay, az);
        }
        Serial.printf("Mag: %.3f g, Var: %.6f\n", acc_magnitude, variance);
        Serial.printf("mg:  X=%d Y=%d Z=%d\n", ax_mg, ay_mg, az_mg);
        Serial.printf("Range: X[%.3f,%.3f] Y[%.3f,%.3f] Z[%.3f,%.3f]\n",
                      acc_min_x, acc_max_x, acc_min_y, acc_max_y, acc_min_z, acc_max_z);
        Serial.println("");
    }
    
    // ディスプレイ更新
    static uint32_t last_display = 0;
    if (millis() - last_display >= 200) {
        last_display = millis();
        
        M5.Display.fillScreen(BLACK);
        M5.Display.setCursor(0, 0);
        M5.Display.println("IMU Test");
        M5.Display.println("");
        
        if (calibrated) {
            M5.Display.printf("X:%+.2fg\n", ax);
            M5.Display.printf("Y:%+.2fg\n", ay);
            M5.Display.printf("Z:%+.2fg\n", az);
        } else {
            M5.Display.printf("X:%+.2fg\n", ax_raw);
            M5.Display.printf("Y:%+.2fg\n", ay_raw);
            M5.Display.printf("Z:%+.2fg\n", az_raw);
        }
        
        M5.Display.println("");
        M5.Display.printf("Mag:%.2fg\n", acc_magnitude);
        M5.Display.printf("Var:%.4f\n", variance);
        
        // 活動判定（ACTIVITY_THRESHOLD = 0.15）
        if (variance > 0.15) {
            M5.Display.println("");
            M5.Display.println("ACTIVE!");
        }
    }
    
    delay(10);
}