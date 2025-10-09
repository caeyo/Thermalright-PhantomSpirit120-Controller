#!/bin/bash

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install it."
    echo "On Debian/Ubuntu: sudo apt-get install jq"
    echo "On Arch Linux: sudo pacman -S jq"
    echo "On Fedora: sudo dnf install jq"
    exit 1
fi

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Create udev rule
UDEV_RULE_FILE="/etc/udev/rules.d/99-digital-thermal-right-lcd.rules"
if [ ! -f "$UDEV_RULE_FILE" ]; then
  echo "Creating udev rule at $UDEV_RULE_FILE"
  echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0416", ATTRS{idProduct}=="8001", MODE="0666"' > "$UDEV_RULE_FILE"
  udevadm control --reload-rules
  udevadm trigger
  echo "udev rule created."
else
  echo "udev rule already exists."
fi

# Create systemd service
SERVICE_FILE="/etc/systemd/system/digital-thermal-right-lcd.service"
echo "Creating systemd service at $SERVICE_FILE"

# Get the user who ran sudo
SUDO_USER=${SUDO_USER:-$USER}

cat > "$SERVICE_FILE" << EOL
[Unit]
Description=Digital Thermal Right LCD Controller
After=network.target

[Service]
ExecStart=${SCRIPT_DIR}/.venv/bin/python ${SCRIPT_DIR}/src/controller.py
WorkingDirectory=${SCRIPT_DIR}
Restart=always
User=${SUDO_USER}

[Install]
WantedBy=multi-user.target
EOL

echo "Systemd service file created."

# Reload systemd, enable and start the service
echo "Reloading systemd, enabling and starting the service."
systemctl daemon-reload
systemctl enable digital-thermal-right-lcd.service
systemctl start digital-thermal-right-lcd.service

# Make scripts executable
chmod +x "${SCRIPT_DIR}/install.sh"
chmod +x "${SCRIPT_DIR}/uninstall.sh"
chmod +x "${SCRIPT_DIR}/led_control.sh"

echo "Installation complete."