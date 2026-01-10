#!/usr/bin/env python3
"""
Test script to verify MQTT and REST API publishing functionality
Run this after starting the OPC UA server with publishers enabled
"""

import time
import json
import requests
import paho.mqtt.client as mqtt
from threading import Event

# Test configuration
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC = "industrial/opcua/#"
REST_API_URL = "http://localhost:5000/api"

# Global flags for test results
mqtt_received = Event()
rest_api_working = Event()
mqtt_messages = []


def on_connect(client, userdata, flags, rc):
    """MQTT connection callback"""
    if rc == 0:
        print("✅ Connected to MQTT broker")
        client.subscribe(MQTT_TOPIC)
        print(f"✅ Subscribed to {MQTT_TOPIC}")
    else:
        print(f"❌ Failed to connect to MQTT broker (rc={rc})")


def on_message(client, userdata, msg):
    """MQTT message callback"""
    global mqtt_messages
    try:
        topic = msg.topic
        payload = json.loads(msg.payload.decode())
        mqtt_messages.append({
            "topic": topic,
            "payload": payload
        })
        print(f"📨 MQTT: {topic} → {payload}")
        mqtt_received.set()
    except Exception as e:
        print(f"❌ Error parsing MQTT message: {e}")


def test_mqtt():
    """Test MQTT publishing"""
    print("\n" + "="*60)
    print("Testing MQTT Publisher")
    print("="*60)
    
    client = mqtt.Client(client_id="test_subscriber")
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
        
        # Wait for messages
        print("⏳ Waiting for MQTT messages (10 seconds)...")
        mqtt_received.wait(timeout=10)
        
        if mqtt_messages:
            print(f"\n✅ MQTT Test PASSED - Received {len(mqtt_messages)} messages")
            print(f"   Sample: {mqtt_messages[0]['topic']}")
            return True
        else:
            print("\n❌ MQTT Test FAILED - No messages received")
            return False
            
    except Exception as e:
        print(f"❌ MQTT Test FAILED - {e}")
        return False
    finally:
        client.loop_stop()
        client.disconnect()


def test_rest_api():
    """Test REST API"""
    print("\n" + "="*60)
    print("Testing REST API Publisher")
    print("="*60)
    
    try:
        # Test health endpoint
        print(f"⏳ Testing {REST_API_URL}/health...")
        response = requests.get(f"{REST_API_URL}/health", timeout=5)
        
        if response.status_code == 200:
            print(f"✅ Health check: {response.json()}")
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
        
        # Test get all tags
        print(f"\n⏳ Testing {REST_API_URL}/tags...")
        response = requests.get(f"{REST_API_URL}/tags", timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            tag_count = data.get('count', 0)
            print(f"✅ Retrieved {tag_count} tags")
            
            # Display sample tags
            tags = data.get('tags', {})
            for i, (tag_name, tag_data) in enumerate(list(tags.items())[:3]):
                print(f"   • {tag_name}: {tag_data['value']} (ts: {tag_data['timestamp']})")
            
            if tag_count > 0:
                # Test get specific tag
                first_tag = list(tags.keys())[0]
                print(f"\n⏳ Testing specific tag: {REST_API_URL}/tags/{first_tag}...")
                response = requests.get(f"{REST_API_URL}/tags/{first_tag}", timeout=5)
                
                if response.status_code == 200:
                    tag_data = response.json()
                    print(f"✅ {first_tag}: {tag_data}")
                    print(f"\n✅ REST API Test PASSED")
                    return True
                else:
                    print(f"❌ Failed to get specific tag: {response.status_code}")
                    return False
            else:
                print("⚠️  No tags available to test")
                return False
        else:
            print(f"❌ Failed to get tags: {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"❌ REST API Test FAILED - Cannot connect to {REST_API_URL}")
        print("   Make sure the server is running with REST API enabled")
        return False
    except Exception as e:
        print(f"❌ REST API Test FAILED - {e}")
        return False


def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("OPC UA Server Publisher Test Suite")
    print("="*60)
    print("\nPrerequisites:")
    print("1. OPC UA server must be running")
    print("2. Run with: python opcua_server.py -c config/config_with_mqtt.json")
    print("3. MQTT broker must be running on localhost:1883")
    print("\nStarting tests in 3 seconds...")
    time.sleep(3)
    
    results = {}
    
    # Test REST API
    results['REST API'] = test_rest_api()
    time.sleep(1)
    
    # Test MQTT
    results['MQTT'] = test_mqtt()
    
    # Summary
    print("\n" + "="*60)
    print("Test Results Summary")
    print("="*60)
    for test_name, passed in results.items():
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{test_name:20s}: {status}")
    
    print("="*60)
    
    # Exit code
    all_passed = all(results.values())
    if all_passed:
        print("\n🎉 All tests passed! Your OPC UA server with publishers is working correctly.")
        return 0
    else:
        print("\n⚠️  Some tests failed. Check the output above for details.")
        return 1


if __name__ == "__main__":
    exit(main())
