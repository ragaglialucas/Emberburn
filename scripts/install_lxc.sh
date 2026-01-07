#!/bin/bash
#
# Installation script for OPC UA Server in LXC container
#

set -e

CONTAINER_NAME="${CONTAINER_NAME:-opcua-server}"
INSTALL_DIR="/opt/opcua-server"

echo "========================================="
echo "  OPC UA Server LXC Installation"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if LXC is installed
if ! command -v lxc &> /dev/null; then
    echo -e "${YELLOW}LXC not found.  Installing...${NC}"
    sudo apt update
    sudo apt install -y lxd lxd-client
    sudo lxd init --auto
    sudo usermod -a -G lxd $USER
    echo -e "${GREEN}LXD installed.  Please log out and back in, then run this script again.${NC}"
    exit 0
fi

# Check if container exists
if lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo -e "${YELLOW}Container $CONTAINER_NAME already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lxc stop "$CONTAINER_NAME" || true
        lxc delete "$CONTAINER_NAME"
    else
        echo "Using existing container"
    fi
fi

# Create container if it doesn't exist
if ! lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo -e "${GREEN}Creating LXC container:  $CONTAINER_NAME${NC}"
    lxc launch ubuntu:22.04 "$CONTAINER_NAME"
    sleep 10
fi

# Update container
echo "Updating container..."
lxc exec "$CONTAINER_NAME" -- apt update
lxc exec "$CONTAINER_NAME" -- apt upgrade -y

# Install dependencies
echo "Installing dependencies..."
lxc exec "$CONTAINER_NAME" -- apt install -y python3 python3-pip

# Create installation directory
lxc exec "$CONTAINER_NAME" -- mkdir -p "$INSTALL_DIR"

# Copy files to container
echo "Copying application files..."
lxc file push opcua_server.py "$CONTAINER_NAME$INSTALL_DIR/"
lxc file push tags_config.json "$CONTAINER_NAME$INSTALL_DIR/"
lxc file push requirements.txt "$CONTAINER_NAME$INSTALL_DIR/"

# Make executable
lxc exec "$CONTAINER_NAME" -- chmod +x "$INSTALL_DIR/opcua_server.py"

# Install Python dependencies
echo "Installing Python dependencies..."
lxc exec "$CONTAINER_NAME" -- pip3 install -r "$INSTALL_DIR/requirements.txt"

# Install systemd service
if [ -f "systemd/opcua-server. service" ]; then
    echo "Installing systemd service..."
    lxc file push systemd/opcua-server.service "$CONTAINER_NAME/etc/systemd/system/"
    lxc exec "$CONTAINER_NAME" -- systemctl daemon-reload
    lxc exec "$CONTAINER_NAME" -- systemctl enable opcua-server.service
    lxc exec "$CONTAINER_NAME" -- systemctl start opcua-server.service
fi

# Configure port forwarding
echo "Configuring port forwarding..."
lxc config device add "$CONTAINER_NAME" opcua-port proxy \
    listen=tcp: 0.0.0.0:4840 \
    connect=tcp:127.0.0.1:4840 || echo "Port already configured"

# Get container IP
CONTAINER_IP=$(lxc list "$CONTAINER_NAME" -c 4 | grep eth0 | awk '{print $2}')

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Container: $CONTAINER_NAME"
echo "Container IP: $CONTAINER_IP"
echo "OPC UA Endpoint: opc.tcp://$CONTAINER_IP:4840/freeopcua/server/"
echo "Host Port: 4840"
echo ""
echo "To check status:"
echo "  lxc exec $CONTAINER_NAME -- systemctl status opcua-server"
echo ""
echo "To view logs:"
echo "  lxc exec $CONTAINER_NAME -- journalctl -u opcua-server -f"
echo ""
echo "To access container shell:"
echo "  lxc exec $CONTAINER_NAME -- bash"
echo ""