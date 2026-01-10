# Getting Started with MQTT and Multi-Protocol Publishing

## Quick Setup Guide

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

This will install:
- `opcua` - OPC UA server
- `paho-mqtt` - MQTT client
- `flask` - REST API framework
- `flask-cors` - CORS support
- `websocket-server` - WebSocket support

### 2. Setup MQTT Broker (Optional)

If you don't have an MQTT broker, install Mosquitto:

**Windows:**
```powershell
# Download from https://mosquitto.org/download/
# Or use Chocolatey
choco install mosquitto
```

**Linux:**
```bash
sudo apt-get update
sudo apt-get install mosquitto mosquitto-clients
sudo systemctl start mosquitto
sudo systemctl enable mosquitto
```

**macOS:**
```bash
brew install mosquitto
brew services start mosquitto
```

**Docker (Platform-independent):**
```bash
docker run -d -p 1883:1883 -p 9001:9001 --name mosquitto eclipse-mosquitto
```

### 3. Run the Server with All Publishers

```bash
python opcua_server.py -c config/config_with_mqtt.json
```

You should see:
```
==============================================================
  OPC UA Server Started
==============================================================
  Endpoint: opc.tcp://0.0.0.0:4840/freeopcua/server/
  Update Interval: 2.0s
  Tags Configured: 10
--------------------------------------------------------------
  Available Tags:
    • Temperature          (float ) - random
    • Pressure             (float ) - random
    • Flow                 (float ) - random
    • FlowRate             (float ) - sine
    • Counter              (int   ) - increment
    ...
==============================================================
  Press Ctrl+C to stop
==============================================================

INFO - MQTT publisher initialized
INFO - REST API publisher initialized
INFO - Connecting to MQTT broker at localhost:1883
INFO - Connected to MQTT broker successfully
INFO - REST API started on http://0.0.0.0:5000
```

## Testing the Publishers

### Test MQTT Publishing

Open a new terminal and subscribe to all topics:

```bash
# Subscribe to all OPC UA tag updates
mosquitto_sub -h localhost -t "industrial/opcua/#" -v
```

You should see messages like:
```
industrial/opcua/Temperature {"tag": "Temperature", "value": 22.34, "timestamp": 1736476800.123}
industrial/opcua/Pressure {"tag": "Pressure", "value": 101.2, "timestamp": 1736476800.123}
industrial/opcua/Counter {"tag": "Counter", "value": 42, "timestamp": 1736476800.124}
```

### Test REST API

```bash
# Get all tags
curl http://localhost:5000/api/tags | python -m json.tool

# Get a specific tag
curl http://localhost:5000/api/tags/Temperature | python -m json.tool

# Health check
curl http://localhost:5000/api/health
```

**PowerShell (Windows):**
```powershell
# Get all tags
Invoke-RestMethod -Uri http://localhost:5000/api/tags | ConvertTo-Json

# Get specific tag
Invoke-RestMethod -Uri http://localhost:5000/api/tags/Temperature
```

## Configuration Customization

### MQTT Settings

Edit `config/config_with_mqtt.json`:

```json
{
  "publishers": {
    "mqtt": {
      "enabled": true,
      "broker": "your-broker-address.com",  // Change this
      "port": 1883,
      "client_id": "my_opcua_server",
      "username": "your_username",           // Add if needed
      "password": "your_password",           // Add if needed
      "topic_prefix": "factory/line1",       // Customize topic
      "payload_format": "json",              // or "string"
      "qos": 1,
      "retain": false
    }
  }
}
```

### Publishing to Cloud MQTT Brokers

#### AWS IoT Core
```json
{
  "mqtt": {
    "enabled": true,
    "broker": "xxxxx.iot.us-east-1.amazonaws.com",
    "port": 8883,
    "use_tls": true,
    "ca_certs": "/path/to/AmazonRootCA1.pem",
    "client_id": "opcua_edge_device",
    "topic_prefix": "factory/opcua"
  }
}
```

#### HiveMQ Cloud
```json
{
  "mqtt": {
    "enabled": true,
    "broker": "xxxxx.s2.eu.hivemq.cloud",
    "port": 8883,
    "use_tls": true,
    "username": "your-username",
    "password": "your-password",
    "topic_prefix": "opcua/data"
  }
}
```

#### Adafruit IO
```json
{
  "mqtt": {
    "enabled": true,
    "broker": "io.adafruit.com",
    "port": 1883,
    "username": "your-username",
    "password": "your-aio-key",
    "topic_prefix": "your-username/feeds"
  }
}
```

## Running Multiple Publishers Simultaneously

All publishers are independent - you can run any combination:

```json
{
  "publishers": {
    "mqtt": {
      "enabled": true,
      // ... settings
    },
    "rest_api": {
      "enabled": true,
      // ... settings
    }
    // Future publishers can be added here
  }
}
```

## Disable Publishers

To run OPC UA server only (no MQTT/REST):

**Option 1:** Use old config format (no publishers section)
```bash
python opcua_server.py -c tags_config.json
```

**Option 2:** Disable in config
```json
{
  "publishers": {
    "mqtt": {
      "enabled": false
    },
    "rest_api": {
      "enabled": false
    }
  }
}
```

## Common Integration Patterns

### Pattern 1: OPC UA → MQTT → Node-RED
1. Run OPC UA server with MQTT enabled
2. Install Node-RED: `npm install -g node-red`
3. Add MQTT input node pointing to `industrial/opcua/#`
4. Process and visualize data in Node-RED dashboard

### Pattern 2: OPC UA → REST API → Web Dashboard
1. Run OPC UA server with REST API enabled
2. Create web app that polls `http://localhost:5000/api/tags`
3. Display real-time data in browser

### Pattern 3: Dual Protocol (OPC UA + MQTT)
1. Legacy SCADA connects via OPC UA
2. IoT devices/cloud subscribe to MQTT
3. Both get the same real-time data

## Troubleshooting

### MQTT Connection Failed
```
ERROR - Failed to connect to MQTT broker, return code 5
```
**Solution:** Check broker address, credentials, and firewall settings

### Port Already in Use (REST API)
```
OSError: [Errno 98] Address already in use
```
**Solution:** Change REST API port in config or kill process using port 5000

### MQTT Authentication Failed
```
ERROR - Failed to connect to MQTT broker, return code 4
```
**Solution:** Verify username/password are correct in config

## Next Steps

- [Add Custom Publishers](docs/CUSTOM_PUBLISHERS.md) (Coming Soon)
- [WebSocket Support](docs/WEBSOCKET.md) (Coming Soon)
- [Database Integration](docs/DATABASE.md) (Coming Soon)
- [Kafka Streaming](docs/KAFKA.md) (Coming Soon)

## Example: Complete IoT Setup

```bash
# Terminal 1: Start MQTT broker
docker run -d -p 1883:1883 eclipse-mosquitto

# Terminal 2: Start OPC UA server with publishers
python opcua_server.py -c config/config_with_mqtt.json

# Terminal 3: Monitor MQTT
mosquitto_sub -h localhost -t "industrial/opcua/#" -v

# Terminal 4: Query REST API
while true; do
  curl -s http://localhost:5000/api/tags/Temperature | python -m json.tool
  sleep 2
done
```

Now you have:
- ✅ OPC UA server running on port 4840
- ✅ MQTT publishing real-time data
- ✅ REST API for HTTP clients
- ✅ All data synchronized across protocols

Happy integrating! 🚀
