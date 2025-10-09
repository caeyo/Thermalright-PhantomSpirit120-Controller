# Digital Thermal Right LCD Controller

This project allows you to control the Thermalright USB LCD screen on Linux.
It provides a Python controller to display system metrics (CPU/GPU temp/usage) and a shell script to configure the display.

## Features

- Display CPU/GPU temperature and usage.
- Multiple display modes.
- Configurable colors and gradients.
- Animated rainbow and wave patterns.
- Configuration via a shell script menu.
- GUI for live display preview and color configuration.

## Prerequisites

- Python 3
- `hidapi` library for your distribution.
  - On Arch Linux: `sudo pacman -S hidapi`
  - On Debian/Ubuntu: `sudo apt-get install libhidapi-dev`
- Python dependencies can be installed via `pip`.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/digital_thermal_right_lcd.git
    cd digital_thermal_right_lcd
    ```

2.  **Install Python dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

3.  **Run the installation script:**
    This script will set up the `udev` rule to allow running without `sudo` and create a `systemd` service to run the display controller on startup.
    ```bash
    sudo ./install.sh
    ```

## Usage

### Configuration

To configure the display, run the `led_control.sh` script:
```bash
./led_control.sh
```
This will open a menu where you can change display modes, colors, and other settings.

### GUI

A graphical interface is available for live preview and color customization.
To run the GUI:
```bash
python src/led_display_ui.py
```

## Uninstallation

To uninstall the service and udev rule, run the `uninstall.sh` script:
```bash
sudo ./uninstall.sh
```
