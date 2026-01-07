#!/bin/bash
#
# Management script for OPC UA Server
#

SERVICE_NAME="opcua-server"
CONTAINER_NAME="${CONTAINER_NAME:-opcua-server}"
MODE="${MODE:-systemd}"  # systemd or lxc

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Detect mode
if lxc info "$CONTAINER_NAME" &> /dev/null; then
    MODE="lxc"
fi

case "$1" in
    start)
        if [ "$MODE" = "lxc" ]; then
            echo "Starting LXC container..."
            lxc start "$CONTAINER_NAME"
            lxc exec "$CONTAINER_NAME" -- systemctl start "$SERVICE_NAME"
        else
            echo "Starting service..."
            sudo systemctl start "$SERVICE_NAME"
        fi
        echo -e "${GREEN}Service started${NC}"
        ;;
    
    stop)
        if [ "$MODE" = "lxc" ]; then
            echo "Stopping service in container..."
            lxc exec "$CONTAINER_NAME" -- systemctl stop "$SERVICE_NAME"
        else
            echo "Stopping service..."
            sudo systemctl stop "$SERVICE_NAME"
        fi
        echo -e "${GREEN}Service stopped${NC}"
        ;;
    
    restart)
        if [ "$MODE" = "lxc" ]; then
            echo "Restarting service in container..."
            lxc exec "$CONTAINER_NAME" -- systemctl restart "$SERVICE_NAME"
        else
            echo "Restarting service..."
            sudo systemctl restart "$SERVICE_NAME"
        fi
        echo -e "${GREEN}Service restarted${NC}"
        ;;
    
    status)
        if [ "$MODE" = "lxc" ]; then
            echo "Container status:"
            lxc list "$CONTAINER_NAME"
            echo ""
            echo "Service status:"
            lxc exec "$CONTAINER_NAME" -- systemctl status "$SERVICE_NAME"
        else
            sudo systemctl status "$SERVICE_NAME"
        fi
        ;;
    
    logs)
        if [ "$MODE" = "lxc" ]; then
            lxc exec "$CONTAINER_NAME" -- journalctl -u "$SERVICE_NAME" -f
        else
            sudo journalctl -u "$SERVICE_NAME" -f
        fi
        ;;
    
    shell)
        if [ "$MODE" = "lxc" ]; then
            lxc exec "$CONTAINER_NAME" -- bash
        else
            echo -e "${RED}Not running in LXC mode${NC}"
            exit 1
        fi
        ;;
    
    test)
        echo "Testing OPC UA connection..."
        python3 << 'PYEOF'
from opcua import Client
import sys

try:
    client = Client("opc.tcp://localhost:4840/freeopcua/server/")
    client.connect()
    print("✓ Connected successfully!")
    
    # Browse root
    root = client.get_root_node()
    print(f"✓ Root node: {root}")
    
    # Get Objects
    objects = client.get_objects_node()
    print(f"✓ Objects node: {objects}")
    
    # List children
    children = objects.get_children()
    print(f"✓ Found {len(children)} child nodes")
    
    client.disconnect()
    print("✓ Test completed successfully!")
    sys.exit(0)
except Exception as e:
    print(f"✗ Error:  {e}")
    sys.exit(1)
PYEOF
        ;;
    
    *)
        echo "OPC UA Server Management Script"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|shell|test}"
        echo ""
        echo "  start   - Start the OPC UA server"
        echo "  stop    - Stop the OPC UA server"
        echo "  restart - Restart the OPC UA server"
        echo "  status  - Show server status"
        echo "  logs    - Show server logs (follow mode)"
        echo "  shell   - Access container shell (LXC mode only)"
        echo "  test    - Test OPC UA connection"
        echo ""
        echo "Current mode: $MODE"
        exit 1
        ;;
esac