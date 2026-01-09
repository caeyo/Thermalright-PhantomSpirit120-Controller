leds_indexes = {
    "all": list(range(0, 92)),
    "usage_percent_led": 0,
    "usage_1s_digit": list(range(1, 8)),
    "usage_10s_digit": list(range(8, 15)),
    "usage_100s_led": 15,
    "speed_mhz_led": 16,
    "speed_1s_digit": list(range(17, 24)),
    "speed_10s_digit": list(range(24, 31)),
    "speed_100s_digit": list(range(31, 38)),
    "speed_1000s_digit": list(range(38, 45)),
    "temp_cpu_led": 51,
    "temp_gpu_led": 59,
    "temp_100s_digit": [45, 46, 47, 48, 49, 50, 52],
    "temp_10s_digit": [53, 54, 55, 56, 57, 58, 60],
    "temp_1s_digit": list(range(61, 68)),
    "temp_fahrenheit": 68,
    "temp_celsius": 69,
}

display_modes = [
    "cpu",
    "gpu",
    "alternating",
    "debug_ui",
]

NUMBER_OF_LEDS = 92

default_config = {
    "display_mode": "alternating",
    "color_mode": "usage",
    "gpu_vendor": "nvidia",
    "metrics": {
        "colors": ["ffe000"] * NUMBER_OF_LEDS
    },
    "time": {
        "colors": ["ffe000"] * NUMBER_OF_LEDS
    },
    "usage": {
        "colors": [
            "usage;00eeff:30;00ff00:50;ffe000:70;ff8000:90;ff0000:100"
        ] * NUMBER_OF_LEDS
    },
    "update_interval": 0.1,
    "metrics_update_interval": 1.0,
    "cycle_duration": 5.0,
    "gpu_min_temp": 30.0,
    "gpu_max_temp": 90.0,
    "cpu_min_temp": 30.0,
    "cpu_max_temp": 80.0,
    "cpu_min_speed": 0.0,
    "cpu_max_speed": 5000.0,
    "gpu_min_speed": 0.0,
    "gpu_max_speed": 2500.0,
    "product_id": "0x8001",
    "vendor_id": "0x0416",
    "cpu_temperature_unit": "celsius",
    "gpu_temperature_unit": "celsius"
}
