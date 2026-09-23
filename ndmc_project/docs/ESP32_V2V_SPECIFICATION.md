# ESP32 Vehicle-to-Vehicle (V2V) Communication Specification

## Overview

This document specifies the ESP-NOW based V2V proximity detection system for TERASIGHT fog-safe haulage. The system enables conflict warning at blind curves **without GPS**, using only RSSI-based proximity and closing rate detection.

## Key Design Principles

1. **NO GPS DEPENDENCY** - Works purely on relative proximity
2. **RSSI-based ranging** - Crude but sufficient for collision avoidance
3. **Closing rate detection** - More reliable than absolute distance
4. **Blind curve safety** - Primary use case

## ESP-NOW Packet Format

### Broadcast Packet (4Hz, 250ms interval)

Each rover broadcasts the following packet via ESP-NOW:

```c
typedef struct {
  char vid[8];        // Vehicle ID (e.g., "DMP-01")
  float heading;      // Compass heading in degrees (0-360)
  float speed;        // Speed in km/h
  uint8_t alert;      // Alert state: 0=OK, 1=CAUTION, 2=HAZARD
  uint16_t seq;       // Sequence number (increments each packet)
  uint32_t ts;        // Timestamp in milliseconds
} __attribute__((packed)) V2VPacket;
```

**Total packet size**: 22 bytes (fits easily in ESP-NOW 250-byte limit)

### Broadcast Configuration

```c
// ESP-NOW setup
esp_now_init();
esp_now_register_recv_cb(onReceiveV2V);

// Broadcast to all peers (use broadcast MAC)
uint8_t broadcastAddress[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
esp_now_peer_info_t peerInfo;
memcpy(peerInfo.peer_addr, broadcastAddress, 6);
peerInfo.channel = 0;  // Current channel
peerInfo.encrypt = false;
esp_now_add_peer(&peerInfo);

// Broadcast timer (4Hz = 250ms)
#define V2V_BROADCAST_INTERVAL_MS 250
```

### Receive Callback - CRITICAL: Capture RSSI

```c
void onReceiveV2V(const uint8_t *mac, const uint8_t *data, int len) {
  // Parse packet
  V2VPacket *packet = (V2VPacket *)data;

  // CRITICAL: Get RSSI from ESP-NOW
  // ESP-NOW exposes RSSI in esp_now_recv_info_t
  wifi_promiscuous_pkt_t *promiscuous_pkt = (wifi_promiscuous_pkt_t *)data;
  int rssi = promiscuous_pkt->rx_ctrl.rssi;

  // Alternative method if above doesn't work:
  // Use esp_wifi_get_rssi() or capture from RX callback context

  // Forward to phone via serial/BLE with RSSI included
  forwardPeerPacketToPhone(packet, rssi);
}
```

**IMPORTANT**: The RSSI value is ESSENTIAL for proximity detection. Ensure it is captured correctly from the ESP-NOW receive callback.

### RSSI Capture Methods

**Method 1: esp_now_recv_info_t (ESP-IDF 4.0+)**
```c
void onReceiveV2V(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  int rssi = info->rx_ctrl->rssi;  // Direct RSSI access
  // ... rest of handler
}
```

**Method 2: Promiscuous mode capture**
```c
// Enable promiscuous mode to access RX metadata
esp_wifi_set_promiscuous(true);
esp_wifi_set_promiscuous_rx_cb(promiscuousRxCallback);

void promiscuousRxCallback(void *buf, wifi_promiscuous_pkt_type_t type) {
  wifi_promiscuous_pkt_t *pkt = (wifi_promiscuous_pkt_t *)buf;
  int rssi = pkt->rx_ctrl.rssi;
  // Store RSSI for correlation with ESP-NOW packet
}
```

## Forwarding to Phone

Include peer packets in the existing telemetry JSON:

```json
{
  "vid": "DMP-01",
  "ts": 1234567890,
  // ... existing telemetry fields ...

  "peers": [
    {
      "vid": "DMP-02",
      "heading": 180.5,
      "speed": 25.3,
      "alert": 0,
      "seq": 1234,
      "ts": 1234567888,
      "rssi": -45
    },
    {
      "vid": "DMP-03",
      "heading": 90.0,
      "speed": 15.0,
      "alert": 1,
      "seq": 5678,
      "ts": 1234567887,
      "rssi": -62
    }
  ]
}
```

### Telemetry Update Rate

- **ESP-NOW V2V broadcast**: 4Hz (250ms)
- **Telemetry to phone**: 20Hz (50ms) - include latest peer data
- **Peer packet freshness**: Only include peers heard in last 1 second

## Testing Procedure

### Basic Connectivity Test
1. Flash two rovers with V2V firmware
2. Power on both, verify broadcast packets in serial monitor
3. Verify RSSI values are being captured (should be -30 to -90 dBm)
4. Move rovers apart, verify RSSI decreases

### RSSI Calibration
1. Place rovers at known distances: 1m, 3m, 5m, 10m
2. Record RSSI values (average of 50 samples)
3. Verify log-distance model fit
4. Expected values at 2.4GHz, indoor:
   - 1m: -30 to -40 dBm
   - 3m: -45 to -55 dBm
   - 10m: -60 to -70 dBm

### Blind Curve Test
1. Place two rovers on opposite sides of physical barrier (wall/building)
2. Drive rovers toward each other
3. Verify V2V packets received even without line of sight
4. Verify conflict warning triggers before visual contact

## Power Considerations

- ESP-NOW is low power (< 100mA during TX)
- 4Hz broadcast rate balances:
  - **Update rate**: Fast enough for collision avoidance
  - **Power consumption**: Low enough for battery operation
  - **Network congestion**: Avoids flooding with many vehicles

## Security Notes

- **NO ENCRYPTION**: For prototype/demo
- **Production upgrade**: Use ESP-NOW encryption with pre-shared keys
- **Spoofing protection**: Add HMAC to packets (future)

## Firmware Checklist

- [ ] ESP-NOW initialization
- [ ] Broadcast MAC configuration (FF:FF:FF:FF:FF:FF)
- [ ] 4Hz broadcast timer
- [ ] RSSI capture in receive callback
- [ ] Packet parsing and validation
- [ ] Peer data forwarding to phone
- [ ] Serial/BLE telemetry integration
- [ ] RSSI value range checking (-100 to -20 dBm)

## Known Limitations

1. **RSSI variance**: ±10 dBm variation is normal
2. **Multipath fading**: RSSI fluctuates in complex environments
3. **Range**: ESP-NOW reliable to ~100m outdoors, ~30m indoors
4. **Latency**: 250ms broadcast + network delay = ~300ms total
5. **No authentication**: Trust all received packets (prototype only)

## Future Enhancements

1. **GPS integration**: Add GPS coordinates to packet when available
2. **Encryption**: Enable ESP-NOW encryption
3. **Multi-hop**: Relay packets for extended range
4. **Adaptive rate**: Increase broadcast rate when vehicles are close

## Questions for Firmware Team

1. Confirm RSSI capture method works on your ESP32 variant
2. Verify ESP-NOW range in your test environment
3. Test broadcast reliability with 5+ vehicles (network congestion)
4. Measure actual power consumption at 4Hz broadcast rate

---

**Document Version**: 1.0
**Last Updated**: 2026-09-14
**Contact**: Integration team (Flutter/Dart side)
