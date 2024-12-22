#!/bin/bash

# Define Promtail version
DEFAULT_PROMTAIL_VERSION="3.3.0"
DEFAULT_PROMTAIL_BIN_FILENAME="promtail-linux-amd64"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/promtail"
SERVICE_FILE="/etc/systemd/system/promtail.service"
DEFAULT_LOKI_URL="http://localhost:3100/loki/api/v1"

LOKI_URL=$(whiptail --inputbox "Enter loki api url:" 10 60 "$DEFAULT_LOKI_URL" 3>&1 1>&2 2>&3)
PROMTAIL_BIN_FILENAME=$(whiptail --inputbox "Enter loki binary name zip without extension:" 10 60 "$DEFAULT_PROMTAIL_BIN_FILENAME" 3>&1 1>&2 2>&3)
PROMTAIL_VERSION=$(whiptail --inputbox "Enter wanted binary version following semver(3.3.0):" 10 60 "$DEFAULT_PROMTAIL_VERSION" 3>&1 1>&2 2>&3)

PROMTAIL_BIN_URL="https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/${DEFAULT_PROMTAIL_BIN_FILENAME}.zip"

# Update system and install dependencies
echo "Updating system and installing dependencies..."
apt update && apt install -y unzip

# Step 1: Download Promtail binary
echo "Downloading Promtail binary... $PROMTAIL_BIN_URL"
wget -q -O "${PROMTAIL_BIN_FILENAME}.zip" $PROMTAIL_BIN_URL

# Step 2: Unzip Promtail binary
echo "Unzipping Promtail binary..."
unzip $PROMTAIL_BIN_FILENAME || exit 1

# Step 3: Move the Promtail binary to the install directory
echo "Installing Promtail binary to $INSTALL_DIR"
mv $PROMTAIL_BIN_FILENAME $INSTALL_DIR/promtail || exit 1
chmod +x $INSTALL_DIR/promtail

# Step 4: Remove the downloaded zip file and unnecessary packages to save space
echo "Cleaning up downloaded files and unnecessary packages..."
rm -f "$PROMTAIL_BIN_FILENAME.zip"
apt-get remove --purge -y unzip
apt-get autoremove -y
apt-get clean

# Step 5: Create the configuration directory
echo "Creating configuration directory $CONFIG_DIR..."
mkdir -p $CONFIG_DIR

# Step 6: Create a sample Promtail configuration file
cat <<EOF | tee $CONFIG_DIR/promtail.yaml > /dev/null
server:
  http_listen_port: 9080
  grpc_listen_port: 0

clients:
  - url: $LOKI_URL/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
EOF

# Step 7: Create the systemd service file for Promtail
echo "Creating systemd service file for Promtail..."
cat <<EOF | tee $SERVICE_FILE > /dev/null
[Unit]
Description=Promtail - Log collection agent for Loki
After=network.target

[Service]
ExecStart=$INSTALL_DIR/promtail -config.file=$CONFIG_DIR/promtail.yaml
Restart=always
User=root
Group=root
EnvironmentFile=-/etc/default/promtail

[Install]
WantedBy=multi-user.target
EOF

# Step 8: Reload systemd, enable, and start Promtail service
echo "Reloading systemd, enabling, and starting Promtail service..."
systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

# Completion message
echo "Promtail installation complete. It is now running as a service."
echo "To change promtail details stop promtail service and modify $CONFIG_DIR/promtail.yaml"
