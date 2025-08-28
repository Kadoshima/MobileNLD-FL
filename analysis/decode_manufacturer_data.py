#!/usr/bin/env python3
"""
Decode BLE Manufacturer Data from M5StickC Plus2
"""

def decode_manufacturer_data(hex_string):
    """Decode the 21-byte manufacturer data structure"""
    # Remove 0x prefix if present
    hex_string = hex_string.replace("0x", "")
    
    # Convert to bytes
    data = bytes.fromhex(hex_string)
    
    # Parse according to structure
    device_type = data[0]
    sequence = data[1]
    state = data[2]
    uncertainty = data[3]
    interval_ms = int.from_bytes(data[4:6], byteorder='little')
    battery_pct = data[6]
    acc_x = int.from_bytes(data[7:9], byteorder='little', signed=True)
    acc_y = int.from_bytes(data[9:11], byteorder='little', signed=True)
    acc_z = int.from_bytes(data[11:13], byteorder='little', signed=True)
    timestamp = int.from_bytes(data[13:17], byteorder='little')
    
    print(f"=== BLE Manufacturer Data Decode ===")
    print(f"Raw hex: {hex_string}")
    print(f"Device Type: 0x{device_type:02X} ({'M5StickC' if device_type == 0x01 else 'Unknown'})")
    print(f"Sequence: {sequence}")
    print(f"HAR State: {state} ({'Idle' if state == 0 else 'Active'})")
    print(f"Uncertainty: {uncertainty}/255 ({uncertainty/255*100:.1f}%)")
    print(f"Interval: {interval_ms} ms")
    print(f"Battery: {battery_pct}%")
    print(f"Accelerometer:")
    print(f"  X: {acc_x} mg ({acc_x/1000:.3f} g)")
    print(f"  Y: {acc_y} mg ({acc_y/1000:.3f} g)")
    print(f"  Z: {acc_z} mg ({acc_z/1000:.3f} g)")
    print(f"Timestamp: {timestamp} ms (uptime: {timestamp/1000:.1f} sec)")
    
    # Calculate magnitude
    import math
    mag = math.sqrt(acc_x**2 + acc_y**2 + acc_z**2)
    print(f"  Magnitude: {mag:.1f} mg ({mag/1000:.3f} g)")

if __name__ == "__main__":
    # Your captured data
    hex_data = "014E0000640064E30301004000044E0100"
    decode_manufacturer_data(hex_data)
    
    print("\n=== Data Structure Verification ===")
    print(f"Expected size: 21 bytes")
    print(f"Actual size: {len(bytes.fromhex(hex_data))} bytes")
    print(f"Structure OK: {len(bytes.fromhex(hex_data)) == 21}")