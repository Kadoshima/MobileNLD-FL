import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => BleLoggerProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Logger',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BleLoggerScreen(),
    );
  }
}

class BleLoggerProvider extends ChangeNotifier {
  bool isScanning = false;
  bool isLogging = false;
  String targetDeviceName = "M5HAR_01";
  int packetCount = 0;
  String? currentLogFile;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  File? _csvFile;
  IOSink? _csvSink;
  
  final List<Map<String, dynamic>> recentPackets = [];
  static const int maxRecentPackets = 10;
  static const int companyId = 0x5900;

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.storage,
      ].request();
    }
  }

  Future<void> startScanning() async {
    if (isScanning) return;

    await requestPermissions();
    
    // Check if Bluetooth is available and on
    if (await FlutterBluePlus.isSupported == false) {
      throw Exception("Bluetooth not supported");
    }

    // Start scanning
    isScanning = true;
    notifyListeners();

    // Set up scan
    await FlutterBluePlus.startScan(
      timeout: null, // Continuous scan
      removeIfGone: null,
      androidUsesFineLocation: true,
    );

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.platformName == targetDeviceName) {
          _processScanResult(result);
        }
      }
    });
  }

  void _processScanResult(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;
    
    if (manufacturerData.containsKey(companyId)) {
      final data = manufacturerData[companyId]!;
      final timestamp = DateTime.now();
      
      // Decode manufacturer data
      final decodedData = _decodeManufacturerData(Uint8List.fromList(data));
      
      // Add to recent packets
      recentPackets.insert(0, {
        'timestamp': timestamp,
        'rssi': result.rssi,
        'data': decodedData,
        'raw': data,
      });
      
      if (recentPackets.length > maxRecentPackets) {
        recentPackets.removeLast();
      }
      
      packetCount++;
      
      // Write to CSV if logging
      if (isLogging && _csvSink != null) {
        _writePacketToCsv(timestamp, result.rssi, Uint8List.fromList(data), decodedData);
      }
      
      notifyListeners();
    }
  }

  Map<String, dynamic> _decodeManufacturerData(Uint8List data) {
    if (data.length < 17) return {};
    
    final buffer = ByteData.sublistView(data);
    int offset = 0;
    
    return {
      'deviceType': buffer.getUint8(offset++),
      'sequence': buffer.getUint8(offset++),
      'state': buffer.getUint8(offset++),
      'uncertainty': buffer.getUint8(offset++),
      'interval': buffer.getUint16(offset, Endian.little),
      'battery': buffer.getUint8(offset + 2),
      'accX': buffer.getInt16(offset + 3, Endian.little),
      'accY': buffer.getInt16(offset + 5, Endian.little),
      'accZ': buffer.getInt16(offset + 7, Endian.little),
      'timestamp': buffer.getUint32(offset + 9, Endian.little),
    };
  }

  Future<void> startLogging() async {
    if (isLogging) return;
    
    // Create log file
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/ble_logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${logDir.path}/ble_log_$timestamp.csv';
    _csvFile = File(filePath);
    _csvSink = _csvFile!.openWrite();
    
    // Write header
    final header = [
      'timestamp_phone_unix_ms',
      'timestamp_phone_iso8601',
      'rssi',
      'sequence',
      'state',
      'uncertainty',
      'interval_ms',
      'battery_pct',
      'acc_x_mg',
      'acc_y_mg',
      'acc_z_mg',
      'device_timestamp_ms',
      'raw_hex'
    ];
    
    _csvSink!.writeln(const ListToCsvConverter().convert([header]));
    
    currentLogFile = filePath;
    isLogging = true;
    notifyListeners();
  }

  void _writePacketToCsv(DateTime timestamp, int rssi, Uint8List raw, Map<String, dynamic> decoded) {
    final row = [
      timestamp.millisecondsSinceEpoch,
      timestamp.toUtc().toIso8601String(),
      rssi,
      decoded['sequence'] ?? '',
      decoded['state'] ?? '',
      decoded['uncertainty'] ?? '',
      decoded['interval'] ?? '',
      decoded['battery'] ?? '',
      decoded['accX'] ?? '',
      decoded['accY'] ?? '',
      decoded['accZ'] ?? '',
      decoded['timestamp'] ?? '',
      raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    ];
    
    _csvSink!.writeln(const ListToCsvConverter().convert([row]));
  }

  Future<void> stopLogging() async {
    if (!isLogging) return;
    
    await _csvSink?.flush();
    await _csvSink?.close();
    
    isLogging = false;
    notifyListeners();
  }

  Future<void> shareLogFile() async {
    if (currentLogFile == null) return;
    
    final file = File(currentLogFile!);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(currentLogFile!)], 
        text: 'BLE Log: ${currentLogFile!.split('/').last}');
    }
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    
    isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopScanning();
    stopLogging();
    _adapterStateSubscription?.cancel();
    super.dispose();
  }
}

class BleLoggerScreen extends StatelessWidget {
  const BleLoggerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BleLoggerProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Logger'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Scanning: ${provider.isScanning ? "Active" : "Stopped"}'),
                    Text('Logging: ${provider.isLogging ? "Active" : "Stopped"}'),
                    Text('Packets: ${provider.packetCount}'),
                    if (provider.currentLogFile != null)
                      Text('Log: ${provider.currentLogFile!.split('/').last}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: provider.isScanning
                        ? null
                        : () async {
                            try {
                              await provider.startScanning();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                    child: const Text('Start Scan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !provider.isScanning
                        ? null
                        : () => provider.stopScanning(),
                    child: const Text('Stop Scan'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (!provider.isScanning || provider.isLogging)
                        ? null
                        : () => provider.startLogging(),
                    child: const Text('Start Log'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !provider.isLogging
                        ? null
                        : () => provider.stopLogging(),
                    child: const Text('Stop Log'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Share button
            if (provider.currentLogFile != null && !provider.isLogging)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => provider.shareLogFile(),
                  icon: const Icon(Icons.share),
                  label: const Text('Share CSV File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Recent Packets
            Text(
              'Recent Packets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: provider.recentPackets.length,
                itemBuilder: (context, index) {
                  final packet = provider.recentPackets[index];
                  final data = packet['data'] as Map<String, dynamic>;
                  final timestamp = packet['timestamp'] as DateTime;
                  
                  return Card(
                    child: ListTile(
                      title: Text(
                        'Seq: ${data['sequence']} | RSSI: ${packet['rssi']} dBm',
                      ),
                      subtitle: Text(
                        'Acc: (${data['accX']}, ${data['accY']}, ${data['accZ']}) mg\n'
                        'Battery: ${data['battery']}% | Interval: ${data['interval']}ms\n'
                        '${DateFormat('HH:mm:ss.SSS').format(timestamp)}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}