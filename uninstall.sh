#!/bin/bash

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Stop and disable the service
echo "Stopping and disabling systemd service..."
systemctl stop digital-thermal-right-lcd.service
systemctl disable digital-thermal-right-lcd.service

# Remove the service file
SERVICE_FILE="/etc/systemd/system/digital-thermal-right-lcd.service"
if [ -f "$SERVICE_FILE" ]; then
  echo "Removing systemd service file..."
  rm "$SERVICE_FILE"
fi

# Reload systemd
systemctl daemon-reload

# Remove the udev rule
UDEV_RULE_FILE="/etc/udev/rules.d/99-digital-thermal-right-lcd.rules"
if [ -f "$UDEV_RULE_FILE" ]; then
  echo "Removing udev rule..."
  rm "$UDEV_RULE_FILE"
  udevadm control --reload-rules
  udevadm trigger
fi

echo "Uninstallation complete."