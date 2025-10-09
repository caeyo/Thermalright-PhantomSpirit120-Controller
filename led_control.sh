#!/bin/bash

# LED Display Control Script for Peerless Assassin 120 Digital
# This script allows easy configuration of display modes, colors, and effects

CONFIG_FILE="${DIGITAL_LCD_CONFIG:-config.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Please install jq: sudo apt-get install jq (Debian/Ubuntu) or sudo yum install jq (RHEL/CentOS)"
    exit 1
fi

# Function to display the main menu
show_main_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     LED Display Control - Main Menu                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} Change Display Mode"
    echo -e "${GREEN}2)${NC} Change LED Colors"
    echo -e "${GREEN}3)${NC} Configure Temperature Settings"
    echo -e "${GREEN}4)${NC} Configure Update Intervals"
    echo -e "${GREEN}5)${NC} Quick Presets"
    echo -e "${GREEN}6)${NC} View Current Configuration"
    echo -e "${GREEN}7)${NC} Reset to Default"
    echo -e "${GREEN}8)${NC} Exit"
    echo ""
    echo -e "${YELLOW}Config file: ${CONFIG_FILE}${NC}"
    echo ""
}

# Function to display display modes menu
show_display_modes_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Select Display Mode                                ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}Big Layout Modes (84 LEDs):${NC}"
    echo -e "${GREEN}1)${NC} peerless_standard    - Peerless Assassin 120 standard display"
    echo -e "${GREEN}2)${NC} peerless_temp        - Temperature focus mode"
    echo -e "${GREEN}3)${NC} peerless_usage       - Usage focus mode"
    echo -e "${GREEN}4)${NC} metrics              - Standard metrics display"
    echo -e "${GREEN}5)${NC} time                 - Time display with seconds"
    echo -e "${GREEN}6)${NC} time_cpu             - Time with GPU metrics"
    echo -e "${GREEN}7)${NC} time_gpu             - Time with CPU metrics"
    echo -e "${GREEN}8)${NC} alternate_time       - Alternate between time displays"
    echo -e "${GREEN}9)${NC} debug_ui             - Debug mode (all LEDs on)"
    echo ""
    echo -e "${MAGENTA}Small Layout Modes (31 LEDs):${NC}"
    echo -e "${GREEN}10)${NC} alternate_metrics    - Cycle through CPU/GPU temp/usage"
    echo -e "${GREEN}11)${NC} cpu_temp             - Show CPU temperature only"
    echo -e "${GREEN}12)${NC} gpu_temp             - Show GPU temperature only"
    echo -e "${GREEN}13)${NC} cpu_usage            - Show CPU usage only"
    echo -e "${GREEN}14)${NC} gpu_usage            - Show GPU usage only"
    echo ""
    echo -e "${GREEN}0)${NC} Back to main menu"
    echo ""
}

# Function to change display mode
change_display_mode() {
    show_display_modes_menu
    read -p "Select mode (0-14): " choice

    case $choice in
        1) mode="peerless_standard" ;;
        2) mode="peerless_temp" ;;
        3) mode="peerless_usage" ;;
        4) mode="metrics" ;;
        5) mode="time" ;;
        6) mode="time_cpu" ;;
        7) mode="time_gpu" ;;
        8) mode="alternate_time" ;;
        9) mode="debug_ui" ;;
        10) mode="alternate_metrics" ;;
        11) mode="cpu_temp" ;;
        12) mode="gpu_temp" ;;
        13) mode="cpu_usage" ;;
        14) mode="gpu_usage" ;;
        0) return ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            sleep 2
            return
            ;;
    esac

    jq --arg mode "$mode" '.display_mode = $mode' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "${GREEN}Display mode changed to: $mode${NC}"
    sleep 2
}

# Function to show color menu
show_color_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     LED Color Configuration                            ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} Set All LEDs to Single Color"
    echo -e "${GREEN}2)${NC} Set CPU LEDs Color"
    echo -e "${GREEN}3)${NC} Set GPU LEDs Color"
    echo -e "${GREEN}4)${NC} Set Color Gradient (Animated)"
    echo -e "${GREEN}5)${NC} Set Metric-Based Color Gradient"
    echo -e "${GREEN}6)${NC} Set Random Colors"
    echo -e "${GREEN}7)${NC} Set Time-Based Gradient"
    echo -e "${GREEN}8)${NC} Color Presets"
    echo ""
    echo -e "${GREEN}0)${NC} Back to main menu"
    echo ""
}

# Function to validate hex color
validate_hex_color() {
    if [[ $1 =~ ^[0-9A-Fa-f]{6}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get color input
get_color_input() {
    local prompt="$1"
    local color

    while true; do
        read -p "$prompt (hex format, e.g., ff0000 for red, or 'done'): " color
        color=${color#\#}

        if [ "$color" == "done" ]; then
            echo "done"
            return 0
        fi

        if validate_hex_color "$color"; then
            echo "$color"
            return 0
        else
            echo -e "${RED}Invalid hex color. Please use 6 hex digits (e.g., ff0000)${NC}"
        fi
    done
}

# Function to set all LEDs to a single color
set_all_leds_color() {
    local color=$(get_color_input "Enter color")
    if [ "$color" == "done" ]; then return; fi
    local context="$1"

    if [ -z "$context" ]; then
        read -p "Apply to (1) Metrics mode, (2) Time mode, (3) Both? " ctx_choice
        case $ctx_choice in
            1) context="metrics" ;;
            2) context="time" ;;
            3) context="both" ;;
            *) echo -e "${RED}Invalid choice${NC}"; return ;;
        esac
    fi

    local json_color_array=$(printf "\"%s\"," $(for i in $(seq 1 84); do echo $color; done) | sed 's/.$//')

    if [ "$context" = "both" ] || [ "$context" = "metrics" ]; then
        jq --argjson colors "[$json_color_array]" '.metrics.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi

    if [ "$context" = "both" ] || [ "$context" = "time" ]; then
        jq --argjson colors "[$json_color_array]" '.time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi

    echo -e "${GREEN}All LEDs set to color: #$color${NC}"
    sleep 2
}

# Function to set LED range color
set_led_range_color() {
    local start=$1
    local end=$2
    local color=$3
    local context=$4

    local current_colors=$(jq -r ".${context}.colors | @json" "$CONFIG_FILE")

    # Create new colors array with updated range
    local new_colors=$(echo "$current_colors" | jq --arg color "$color" --argjson start "$start" --argjson end "$end" '
        to_entries | map(
            if .key >= $start and .key <= $end then
                .value = $color
            else
                .
            end
        ) | map(.value)
    ')

    jq --argjson colors "$new_colors" ".${context}.colors = \$colors" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

# Function to set metric-based color gradients
set_metric_gradient() {
    echo ""
    echo "Select metric:"
    echo "1) cpu_temp"
    echo "2) cpu_usage"
    echo "3) gpu_temp"
    echo "4) gpu_usage"
    read -p "Select metric: " metric_choice

    case $metric_choice in
        1) metric="cpu_temp" ;;
        2) metric="cpu_usage" ;;
        3) metric="gpu_temp" ;;
        4) metric="gpu_usage" ;;
        *) echo -e "${RED}Invalid choice${NC}"; return ;;
    esac

    local gradient_string="$metric"
    local stop_counter=1

    while true; do
        echo ""
        echo "Configure stop $stop_counter:"
        local color=$(get_color_input "Enter color (or type 'done')")
        if [ "$color" == "done" ]; then
            break
        fi

        read -p "Enter value for this color stop: " value
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid value. Please enter a number.${NC}"
            continue
        fi

        gradient_string+=";${color}:${value}"
        stop_counter=$((stop_counter + 1))
    done

    if [ "$stop_counter" -lt 2 ]; then
        echo -e "${RED}You must define at least one color stop.${NC}"
        sleep 2
        return
    fi

    local json_array=$(for i in $(seq 1 84); do echo -n "\"${gradient_string}\","; done | sed 's/.$//')
    jq --argjson colors "[$json_array]" '.metrics.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

    echo -e "${GREEN}Metric-based gradient applied for $metric${NC}"
    sleep 2
}

# Function to change LED colors
change_led_colors() {
    show_color_menu
    read -p "Select option (0-8): " choice

    case $choice in
        1) set_all_leds_color ;;
        2)
            color=$(get_color_input "Enter CPU LEDs color")
            if [ "$color" == "done" ]; then return; fi
            set_led_range_color 0 41 "$color" "metrics"
            echo -e "${GREEN}CPU LEDs color updated${NC}"
            sleep 2
            ;;
        3)
            color=$(get_color_input "Enter GPU LEDs color")
            if [ "$color" == "done" ]; then return; fi
            set_led_range_color 42 83 "$color" "metrics"
            echo -e "${GREEN}GPU LEDs color updated${NC}"
            sleep 2
            ;;
        4)
            color1=$(get_color_input "Enter start color")
            if [ "$color1" == "done" ]; then return; fi
            color2=$(get_color_input "Enter end color")
            if [ "$color2" == "done" ]; then return; fi
            gradient="${color1}-${color2}"

            read -p "Apply to (1) Metrics, (2) Time, (3) Both? " ctx
            case $ctx in
                1) context="metrics" ;;
                2) context="time" ;;
                3) context="both" ;;
                *) echo -e "${RED}Invalid choice${NC}"; return ;;
            esac

            local json_array=$(for i in $(seq 1 84); do echo -n "\"${gradient}\","; done | sed 's/.$//')

            if [ "$context" = "both" ] || [ "$context" = "metrics" ]; then
                jq --argjson colors "[$json_array]" '.metrics.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            fi

            if [ "$context" = "both" ] || [ "$context" = "time" ]; then
                jq --argjson colors "[$json_array]" '.time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            fi

            echo -e "${GREEN}Gradient applied: $color1 → $color2${NC}"
            sleep 2
            ;;
        5) set_metric_gradient ;;
        6)
            read -p "Apply to (1) Metrics, (2) Time, (3) Both? " ctx
            case $ctx in
                1) context="metrics" ;;
                2) context="time" ;;
                3) context="both" ;;
                *) echo -e "${RED}Invalid choice${NC}"; return ;;
            esac

            local json_array=$(for i in $(seq 1 84); do echo -n "\"random\","; done | sed 's/.$//')

            if [ "$context" = "both" ] || [ "$context" = "metrics" ]; then
                jq --argjson colors "[$json_array]" '.metrics.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            fi

            if [ "$context" = "both" ] || [ "$context" = "time" ]; then
                jq --argjson colors "[$json_array]" '.time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            fi

            echo -e "${GREEN}Random colors applied${NC}"
            sleep 2
            ;;
        7)
            echo ""
            echo "Time unit options:"
            echo "1) seconds"
            echo "2) minutes"
            echo "3) hours"
            read -p "Select time unit: " time_choice

            case $time_choice in
                1) time_unit="seconds" ;;
                2) time_unit="minutes" ;;
                3) time_unit="hours" ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    sleep 2
                    return
                    ;;
            esac

            color1=$(get_color_input "Enter start color")
            if [ "$color1" == "done" ]; then return; fi

            color2=$(get_color_input "Enter end color")
            if [ "$color2" == "done" ]; then return; fi

            gradient="${color1}-${color2}-${time_unit}"
            local json_array=$(for i in $(seq 1 84); do echo -n "\"${gradient}\","; done | sed 's/.$//')

            jq --argjson colors "[$json_array]" '.time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

            echo -e "${GREEN}Time-based gradient applied (${time_unit})${NC}"
            sleep 2
            ;;
        8) color_presets ;;
        0) return ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            sleep 2
            ;;
    esac
}

# Function to apply color presets
color_presets() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Color Presets                                        ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} Red"
    echo -e "${GREEN}2)${NC} Green"
    echo -e "${GREEN}3)${NC} Blue"
    echo -e "${GREEN}4)${NC} White"
    echo -e "${GREEN}5)${NC} Yellow"
    echo -e "${GREEN}6)${NC} Cyan"
    echo -e "${GREEN}7)${NC} Magenta"
    echo -e "${GREEN}8)${NC} Temperature Gradient Preset"
    echo -e "${GREEN}9)${NC} Usage Gradient Preset"
    echo ""
    echo -e "${GREEN}0)${NC} Back to color menu"
    echo ""

    read -p "Select preset (0-9): " choice

    local color
    case $choice in
        1) color="ff0000" ;;
        2) color="00ff00" ;;
        3) color="0000ff" ;;
        4) color="ffffff" ;;
        5) color="ffff00" ;;
        6) color="00ffff" ;;
        7) color="ff00ff" ;;
        8)
            # Temperature Gradient
            local temp_gradient_cpu="cpu_temp;0000ff:30;00ff00:40;ffff00:60;ff00ff:70;ff0000:80"
            local temp_gradient_gpu="gpu_temp;0000ff:30;00ff00:40;ffff00:60;ff00ff:70;ff0000:80"
            set_led_range_color 0 41 "$temp_gradient_cpu" "metrics"
            set_led_range_color 42 83 "$temp_gradient_gpu" "metrics"
            echo -e "${GREEN}Temperature gradient preset applied${NC}"
            sleep 2
            return
            ;;
        9)
            # Usage Gradient
            local usage_gradient_cpu="cpu_usage;0000ff:10;00ff00:35;ffff00:55;ff00ff:75;ff8c00:85;ff0000:100"
            local usage_gradient_gpu="gpu_usage;0000ff:10;00ff00:35;ffff00:55;ff00ff:75;ff8c00:85;ff0000:100"
            set_led_range_color 0 41 "$usage_gradient_cpu" "metrics"
            set_led_range_color 42 83 "$usage_gradient_gpu" "metrics"
            echo -e "${GREEN}Usage gradient preset applied${NC}"
            sleep 2
            return
            ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice${NC}"; sleep 2; return ;;
    esac

    local json_color_array=$(printf "\"%s\"," $(for i in $(seq 1 84); do echo $color; done) | sed 's/.$//')

    jq --argjson colors "[$json_color_array]" '.metrics.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    jq --argjson colors "[$json_color_array]" '.time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

    echo -e "${GREEN}All LEDs set to color: #$color${NC}"
    sleep 2
}

# Function to configure temperature settings
configure_temperature() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Temperature Configuration                          ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    current_cpu_unit=$(jq -r '.cpu_temperature_unit' "$CONFIG_FILE")
    current_gpu_unit=$(jq -r '.gpu_temperature_unit' "$CONFIG_FILE")

    echo -e "Current CPU unit: ${YELLOW}$current_cpu_unit${NC}"
    echo -e "Current GPU unit: ${YELLOW}$current_gpu_unit${NC}"
    echo ""

    echo "1) Change CPU temperature unit"
    echo "2) Change GPU temperature unit"
    echo "3) Set temperature ranges"
    echo "0) Back"
    echo ""

    read -p "Select option: " choice

    case $choice in
        1)
            echo "Select unit: (1) Celsius (2) Fahrenheit"
            read -p "Choice: " unit_choice
            if [ "$unit_choice" = "1" ]; then
                jq '.cpu_temperature_unit = "celsius"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                echo -e "${GREEN}CPU temperature unit set to Celsius${NC}"
            elif [ "$unit_choice" = "2" ]; then
                jq '.cpu_temperature_unit = "fahrenheit"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                echo -e "${GREEN}CPU temperature unit set to Fahrenheit${NC}"
            fi
            sleep 2
            ;;
        2)
            echo "Select unit: (1) Celsius (2) Fahrenheit"
            read -p "Choice: " unit_choice
            if [ "$unit_choice" = "1" ]; then
                jq '.gpu_temperature_unit = "celsius"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                echo -e "${GREEN}GPU temperature unit set to Celsius${NC}"
            elif [ "$unit_choice" = "2" ]; then
                jq '.gpu_temperature_unit = "fahrenheit"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                echo -e "${GREEN}GPU temperature unit set to Fahrenheit${NC}"
            fi
            sleep 2
            ;;
        3)
            read -p "CPU min temp: " cpu_min
            read -p "CPU max temp: " cpu_max
            read -p "GPU min temp: " gpu_min
            read -p "GPU max temp: " gpu_max

            jq --argjson cpu_min "$cpu_min" --argjson cpu_max "$cpu_max" \
               --argjson gpu_min "$gpu_min" --argjson gpu_max "$gpu_max" \
               '.cpu_min_temp = $cpu_min | .cpu_max_temp = $cpu_max | .gpu_min_temp = $gpu_min | .gpu_max_temp = $gpu_max' \
               "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

            echo -e "${GREEN}Temperature ranges updated${NC}"
            sleep 2
            ;;
        0) return ;;
    esac
}

# Function to configure update intervals
configure_intervals() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Update Interval Configuration                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    current_update=$(jq -r '.update_interval' "$CONFIG_FILE")
    current_metrics=$(jq -r '.metrics_update_interval' "$CONFIG_FILE")
    current_cycle=$(jq -r '.cycle_duration' "$CONFIG_FILE")

    echo -e "Current update interval: ${YELLOW}${current_update}s${NC}"
    echo -e "Current metrics update interval: ${YELLOW}${current_metrics}s${NC}"
    echo -e "Current cycle duration: ${YELLOW}${current_cycle}s${NC}"
    echo ""

    read -p "New update interval (seconds): " update_interval
    read -p "New metrics update interval (seconds): " metrics_interval
    read -p "New cycle duration (seconds): " cycle_duration

    jq --argjson update "$update_interval" --argjson metrics "$metrics_interval" --argjson cycle "$cycle_duration" \
       '.update_interval = $update | .metrics_update_interval = $metrics | .cycle_duration = $cycle' \
       "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

    echo -e "${GREEN}Update intervals configured${NC}"
    sleep 2
}

# Function to apply quick presets
quick_presets() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYYAN}║     Quick Presets                                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} Gaming Mode (peerless_standard, temp-based colors)"
    echo -e "${GREEN}2)${NC} RGB Rainbow (animated gradient)"
    echo -e "${GREEN}3)${NC} Stealth Mode (all black/dim)"
    echo -e "${GREEN}4)${NC} Cool Blue Theme"
    echo -e "${GREEN}5)${NC} Fire Theme (red-orange gradient)"
    echo -e "${GREEN}6)${NC} Matrix Theme (green)"
    echo -e "${GREEN}7)${NC} Temperature Gradient Preset"
    echo -e "${GREEN}8)${NC} Usage Gradient Preset"
    echo -e "${GREEN}9)${NC} Quadrant Metric Colors"
    echo -e "${GREEN}10)${NC} Wave L-to-R"
    echo -e "${GREEN}11)${NC} Wave R-to-L"
    echo ""
    echo -e "${GREEN}0)${NC} Back to main menu"
    echo ""

    read -p "Select preset (0-11): " choice

    case $choice in
        1)
            jq '.display_mode = "peerless_standard"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            # Set CPU temp-based colors for CPU section, GPU temp-based for GPU section
            set_led_range_color 0 41 "00ff00-ff0000-cpu_temp" "metrics"
            set_led_range_color 42 83 "0000ff-ff0000-gpu_temp" "metrics"
            echo -e "${GREEN}Gaming Mode preset applied${NC}"
            ;;
        2)
            local gradient="ff0000-ffff00-00ff00-00ffff-0000ff-ff00ff-ff0000"
            local json_array=$(for i in $(seq 1 84); do echo -n "\"${gradient}\","; done | sed 's/.$//')
            jq --argjson colors "[$json_array]" '.metrics.colors = $colors | .time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}RGB Rainbow preset applied${NC}"
            ;;
        3)
            set_all_leds_color "metrics" <<< "000000"
            set_all_leds_color "time" <<< "000000"
            echo -e "${GREEN}Stealth Mode preset applied${NC}"
            ;;
        4)
            set_all_leds_color "metrics" <<< "0080ff"
            set_all_leds_color "time" <<< "00d9ff"
            echo -e "${GREEN}Cool Blue Theme preset applied${NC}"
            ;;
        5)
            local gradient="ff0000-ff8800"
            local json_array=$(for i in $(seq 1 84); do echo -n "\"${gradient}\","; done | sed 's/.$//')
            jq --argjson colors "[$json_array]" '.metrics.colors = $colors | .time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}Fire Theme preset applied${NC}"
            ;;
        6)
            set_all_leds_color "metrics" <<< "00ff00"
            set_all_leds_color "time" <<< "00ff00"
            echo -e "${GREEN}Matrix Theme preset applied${NC}"
            ;;
        7)
            # Temperature Gradient
            local temp_gradient_cpu="cpu_temp;0000ff:30;00ff00:40;ffff00:60;ff00ff:70;ff0000:80"
            local temp_gradient_gpu="gpu_temp;0000ff:30;00ff00:40;ffff00:60;ff00ff:70;ff0000:80"
            set_led_range_color 0 41 "$temp_gradient_cpu" "metrics"
            set_led_range_color 42 83 "$temp_gradient_gpu" "metrics"
            echo -e "${GREEN}Temperature gradient preset applied${NC}"
            ;;
        8)
            # Usage Gradient
            local usage_gradient_cpu="cpu_usage;0000ff:10;00ff00:35;ffff00:55;ff00ff:75;ff8c00:85;ff0000:100"
            local usage_gradient_gpu="gpu_usage;0000ff:10;00ff00:35;ffff00:55;ff00ff:75;ff8c00:85;ff0000:100"
            set_led_range_color 0 41 "$usage_gradient_cpu" "metrics"
            set_led_range_color 42 83 "$usage_gradient_gpu" "metrics"
            echo -e "${GREEN}Usage gradient preset applied${NC}"
            ;;
        9)
            # Quadrant Metric Colors - Fixed to include LED and unit indicators
            local temp_gradient_str="cpu_temp;0000ff:25;00ff00:45;ffff00:60;ff8c00:75;ff0000:100"
            local usage_gradient_str="cpu_usage;0000ff:25;00ff00:45;ffff00:60;ff8c00:75;ff0000:100"
            local gpu_temp_gradient="gpu_temp;0000ff:25;00ff00:45;ffff00:60;ff8c00:75;ff0000:100"
            local gpu_usage_gradient="gpu_usage;0000ff:25;00ff00:45;ffff00:60;ff8c00:75;ff0000:100"

            # CPU LED (0-1)
            set_led_range_color 0 1 "$temp_gradient_str" "metrics"

            # CPU Temp digits (2-22)
            set_led_range_color 2 22 "$temp_gradient_str" "metrics"

            # CPU Celsius indicator (23)
            set_led_range_color 23 23 "$temp_gradient_str" "metrics"

            # CPU Fahrenheit indicator (24) - skip

            # CPU Usage 1 indicator (25-26)
            set_led_range_color 25 26 "$usage_gradient_str" "metrics"

            # CPU Usage digits (27-40)
            set_led_range_color 27 40 "$usage_gradient_str" "metrics"

            # CPU Percent (41)
            set_led_range_color 41 41 "$usage_gradient_str" "metrics"

            # GPU Percent (42)
            set_led_range_color 42 42 "$gpu_usage_gradient" "metrics"

            # GPU Usage digits (43-56)
            set_led_range_color 43 56 "$gpu_usage_gradient" "metrics"

            # GPU Usage 1 indicator (57-58)
            set_led_range_color 57 58 "$gpu_usage_gradient" "metrics"

            # GPU Celsius indicator (59)
            set_led_range_color 59 59 "$gpu_temp_gradient" "metrics"

            # GPU Fahrenheit indicator (60) - skip

            # GPU Temp digits (61-81)
            set_led_range_color 61 81 "$gpu_temp_gradient" "metrics"

            # GPU LED (82-83)
            set_led_range_color 82 83 "$gpu_temp_gradient" "metrics"

            echo -e "${GREEN}Quadrant Metric Colors preset applied${NC}"
            ;;
        10)
            local gradient="wave_ltr;ff0000-ffff00-00ff00-00ffff-0000ff-ff00ff-ff0000"
            local json_array=$(for i in $(seq 1 84); do echo -n "\"${gradient}\","; done | sed 's/.$//')
            jq --argjson colors "[$json_array]" '.metrics.colors = $colors | .time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}Wave L-to-R preset applied${NC}"
            ;;
        11)
            local gradient="wave_rtl;ff0000-ffff00-00ff00-00ffff-0000ff-ff00ff-ff0000"
            local json_array=$(for i in $(seq 1 84); do echo -n "\"${gradient}\","; done | sed 's/.$//')
            jq --argjson colors "[$json_array]" '.metrics.colors = $colors | .time.colors = $colors' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}Wave R-to-L preset applied${NC}"
            ;;
        0) return ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
    sleep 2
}

# Function to view current configuration
view_config() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Current Configuration                              ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${YELLOW}Display Mode:${NC} $(jq -r '.display_mode' "$CONFIG_FILE")"
    echo -e "${YELLOW}Layout Mode:${NC} $(jq -r '.layout_mode' "$CONFIG_FILE")"
    echo -e "${YELLOW}CPU Temperature Unit:${NC} $(jq -r '.cpu_temperature_unit' "$CONFIG_FILE")"
    echo -e "${YELLOW}GPU Temperature Unit:${NC} $(jq -r '.gpu_temperature_unit' "$CONFIG_FILE")"
    echo -e "${YELLOW}Update Interval:${NC} $(jq -r '.update_interval' "$CONFIG_FILE")s"
    echo -e "${YELLOW}Metrics Update Interval:${NC} $(jq -r '.metrics_update_interval' "$CONFIG_FILE")s"
    echo -e "${YELLOW}Cycle Duration:${NC} $(jq -r '.cycle_duration' "$CONFIG_FILE")s"
    echo ""
    echo -e "${YELLOW}Temperature Ranges:${NC}"
    echo -e "  CPU: $(jq -r '.cpu_min_temp' "$CONFIG_FILE")°C - $(jq -r '.cpu_max_temp' "$CONFIG_FILE")°C"
    echo -e "  GPU: $(jq -r '.gpu_min_temp' "$CONFIG_FILE")°C - $(jq -r '.gpu_max_temp' "$CONFIG_FILE")°C"
    echo ""

    read -p "Press Enter to continue..."
}

# Function to reset to default configuration
reset_config() {
    read -p "Are you sure you want to reset to default configuration? (y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        # Backup current config
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"

        # Note: This would need the default_config from config.py
        # For now, we'll just confirm the action
        echo -e "${GREEN}Configuration backed up to ${CONFIG_FILE}.backup${NC}"
        echo -e "${YELLOW}Please run the Python script to generate default config or restore manually${NC}"
        sleep 3
    fi
}

# Main loop
main() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
        exit 1
    fi

    while true; do
        show_main_menu
        read -p "Select option (1-8): " choice

        case $choice in
            1) change_display_mode ;;
            2) change_led_colors ;;
            3) configure_temperature ;;
            4) configure_intervals ;;
            5) quick_presets ;;
            6) view_config ;;
            7) reset_config ;;
            8)
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main function
main
