import numpy as np
from metrics import Metrics
from config import leds_indexes, NUMBER_OF_LEDS, display_modes
from utils import interpolate_color, get_random_color
import hid
import time
import datetime 
import json
import os
import sys


digit_to_segments = {
    0: ['a', 'b', 'c', 'd', 'e', 'f'],
    1: ['b', 'c'],
    2: ['a', 'b', 'g', 'e', 'd'],
    3: ['a', 'b', 'g', 'c', 'd'],
    4: ['f', 'g', 'b', 'c'],
    5: ['a', 'f', 'g', 'c', 'd'],
    6: ['a', 'f', 'g', 'e', 'c', 'd'],
    7: ['a', 'b', 'c'],
    8: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
    9: ['a', 'b', 'g', 'f', 'c', 'd'],
}

digit_mask = np.array(
    [
        [1, 1, 1, 1, 1, 1, 1],  # 0
        [1, 1, 1, 1, 1, 1, 1],  # 1
        [1, 1, 1, 1, 1, 1, 1],  # 2
        [1, 1, 1, 1, 1, 1, 1],  # 3
        [1, 1, 1, 1, 1, 1, 1],  # 4
        [1, 1, 1, 1, 1, 1, 1],  # 5
        [1, 1, 1, 1, 1, 1, 1],  # 6
        [1, 1, 1, 1, 1, 1, 1],  # 7
        [1, 1, 1, 1, 1, 1, 1],  # 8
        [1, 1, 1, 1, 1, 1, 1],  # 9
        [1, 1, 1, 1, 1, 1, 1],  # nothing
    ]
)

letter_mask = {
    'H': [1, 0, 1, 1, 1, 0, 1],
}



def _number_to_array(number):
    if number>=10:
        return _number_to_array(int(number/10))+[number%10]
    else:
        return [number]

def get_number_array(temp, array_length=3, fill_value=-1):
    if temp<0:
        return [fill_value]*array_length
    else:
        narray = _number_to_array(temp)
        if (len(narray)!=array_length):
            if(len(narray)<array_length):
                narray = np.concatenate([[fill_value]*(array_length-len(narray)),narray])
            else:
                narray = narray[1:]
        return narray

class Controller:
    def __init__(self, config_path=None):
        self.temp_unit = {"cpu": "celsius", "gpu": "celsius"}
        self.metrics = Metrics()
        self.VENDOR_ID = 0x0416   
        self.PRODUCT_ID = 0x8001 
        self.dev = self.get_device()
        self.HEADER = 'dadbdcdd000000000000000000000000fc0000ff'
        self.leds = np.array([0] * NUMBER_OF_LEDS)
        self.leds_indexes = leds_indexes
        # Configurable config path
        if config_path is None:
            self.config_path = os.environ.get('DIGITAL_LCD_CONFIG', os.path.join(os.path.dirname(os.path.dirname(__file__)), 'config.json'))
        else:
            self.config_path = config_path
        self.cpt = 0  # For alternate_time cycling
        self.cycle_duration = 50
        self.display_mode = None
        self.metrics_updates = 0
        self.alternating_cycle_duration = 5
        self.showing_cpu = True  # Track which mode we're showing in alternating mode
        self.colors = np.array(["ffe000"] * NUMBER_OF_LEDS)  # Will be set in update()
        self.layout = self.load_layout()
        self.update()

    def load_config(self):
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
            return None

    def load_layout(self):
        try:
            layout_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'layout.json')
            with open(layout_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading layout: {e}")
            return None

    def get_device(self):
        try:
            return hid.Device(self.VENDOR_ID, self.PRODUCT_ID)
        except Exception as e:
            print(f"Error initializing HID device: {e}")
            return None

    def set_leds(self, key, value):
        try:
            led_index = self.leds_indexes[key]
            if isinstance(led_index, list):
                if isinstance(value, (list, np.ndarray)):
                    for i, idx in enumerate(led_index):
                        if i < len(value):
                            self.leds[idx] = value[i]
                else:
                    for idx in led_index:
                        self.leds[idx] = value
            else:
                self.leds[led_index] = value
        except KeyError:
            print(f"Warning: Key {key} not found in leds_indexes.")
        except Exception as e:
            print(f"Warning: Error setting LEDs for {key}: {e}")

    def send_packets(self):
        message = "".join([self.colors[i] if self.leds[i] != 0 else "000000" for i in range(NUMBER_OF_LEDS)])
        packet0 = bytes.fromhex(self.HEADER+message[:128-len(self.HEADER)])
        self.dev.write(packet0)
        packets = message[88:]
        for i in range(0,4):
            packet = bytes.fromhex('00'+packets[i*128:(i+1)*128])
            self.dev.write(packet)


    def draw_number(self, number, num_digits, digits_mapping):
        """Draw a number using the digit mapping from layout.json"""
        number_str = f"{number:0{num_digits}d}"
        for i, digit_char in enumerate(number_str):
            if i < len(digits_mapping):
                digit = int(digit_char)
                segments_to_light = digit_to_segments[digit]
                digit_map = digits_mapping[i]['map']
                for segment_name in segments_to_light:
                    segment_index = digit_map[segment_name]
                    self.leds[segment_index] = 1

    def draw_usage_phantom_spirit(self, usage):
        """Draw usage % with special handling for 100s digit LED"""
        if usage < 0 or usage > 199:
            return
        
        # Draw % LED
        self.leds[self.layout['usage_percent_led']] = 1
        
        # Draw 1s and 10s digits (skip leading zeros)
        usage_2digit = usage % 100
        
        # Always draw 1s digit
        if len(self.layout['usage_1s_digit']) > 0:
            self.draw_number(usage_2digit % 10, 1, self.layout['usage_1s_digit'])
        
        # Only draw 10s digit if usage >= 10 (skip leading zero)
        if usage_2digit >= 10 and len(self.layout['usage_10s_digit']) > 0:
            self.draw_number(usage_2digit // 10, 1, self.layout['usage_10s_digit'])
        
        # Light 100s LED if usage >= 100
        if usage >= 100:
            self.leds[self.layout['usage_100s_led']] = 1

    def draw_speed_phantom_spirit(self, speed):
        """Draw 4-digit speed in MHz, skipping leading zeros"""
        if speed < 0 or speed > 9999:
            return
        
        # Draw MHz LED
        self.leds[self.layout['speed_mhz_led']] = 1
        
        # Draw speed digits, skipping leading zeros
        # Always draw at least the 1s digit (even if 0)
        if len(self.layout['speed_digits']) >= 4:
            # Draw 1s digit (always)
            self.draw_number(speed % 10, 1, [self.layout['speed_digits'][0]])
            
            # Draw 10s digit if speed >= 10
            if speed >= 10:
                self.draw_number((speed // 10) % 10, 1, [self.layout['speed_digits'][1]])
            
            # Draw 100s digit if speed >= 100
            if speed >= 100:
                self.draw_number((speed // 100) % 10, 1, [self.layout['speed_digits'][2]])
            
            # Draw 1000s digit if speed >= 1000
            if speed >= 1000:
                self.draw_number(speed // 1000, 1, [self.layout['speed_digits'][3]])

    def draw_temp_phantom_spirit(self, temp, device='cpu', unit='celsius'):
        """Draw 3-digit temperature with CPU/GPU LED and unit, skipping leading zeros"""
        if temp < 0 or temp > 999:
            return
        
        # Draw CPU or GPU LED
        if device == 'cpu':
            self.leds[self.layout['temp_cpu_led']] = 1
        else:
            self.leds[self.layout['temp_gpu_led']] = 1
        
        # Draw temperature digits, skipping leading zeros
        # Always draw 1s digit (even if 0)
        if len(self.layout['temp_1s_digit']) > 0:
            self.draw_number(temp % 10, 1, self.layout['temp_1s_digit'])
        
        # Only draw 10s digit if temp >= 10 (skip leading zero)
        if temp >= 10 and len(self.layout['temp_10s_digit']) > 0:
            self.draw_number((temp // 10) % 10, 1, self.layout['temp_10s_digit'])
        
        # Only draw 100s digit if temp >= 100 (skip leading zero)
        if temp >= 100 and len(self.layout['temp_100s_digit']) > 0:
            self.draw_number(temp // 100, 1, self.layout['temp_100s_digit'])
        
        # Draw unit LED
        if unit == 'celsius':
            self.leds[self.layout['temp_celsius']] = 1
        else:
            self.leds[self.layout['temp_fahrenheit']] = 1


    def display_cpu_mode(self):
        """Display CPU temp, frequency, and usage"""
        if not self.layout:
            print("Warning: layout.json not loaded. Cannot display CPU mode.")
            return

        cpu_unit = self.config.get('cpu_temperature_unit', 'celsius')
        gpu_unit = self.config.get('gpu_temperature_unit', 'celsius')
        temp_unit = {'cpu': cpu_unit, 'gpu': gpu_unit}

        metrics = self.metrics.get_metrics(temp_unit=temp_unit)
        self.colors = self.get_config_colors(self.config, key="metrics", metrics=metrics)

        cpu_usage = metrics.get("cpu_usage", 0)
        cpu_speed = metrics.get("cpu_speed", 0)
        cpu_temp = metrics.get("cpu_temp", 0)

        # Draw usage %
        self.draw_usage_phantom_spirit(cpu_usage)
        
        # Draw speed (frequency)
        self.draw_speed_phantom_spirit(cpu_speed)
        
        # Draw temperature (CPU)
        self.draw_temp_phantom_spirit(cpu_temp, device='cpu', unit=cpu_unit)

    def display_gpu_mode(self):
        """Display GPU temp, frequency, and usage"""
        if not self.layout:
            print("Warning: layout.json not loaded. Cannot display GPU mode.")
            return

        cpu_unit = self.config.get('cpu_temperature_unit', 'celsius')
        gpu_unit = self.config.get('gpu_temperature_unit', 'celsius')
        temp_unit = {'cpu': cpu_unit, 'gpu': gpu_unit}

        metrics = self.metrics.get_metrics(temp_unit=temp_unit)
        self.colors = self.get_config_colors(self.config, key="metrics", metrics=metrics)

        gpu_usage = metrics.get("gpu_usage", 0)
        gpu_speed = metrics.get("gpu_speed", 0)
        gpu_temp = metrics.get("gpu_temp", 0)

        # Draw usage %
        self.draw_usage_phantom_spirit(gpu_usage)
        
        # Draw speed (frequency)
        self.draw_speed_phantom_spirit(gpu_speed)
        
        # Draw temperature (GPU)
        self.draw_temp_phantom_spirit(gpu_temp, device='gpu', unit=gpu_unit)

    def display_alternating(self, metrics_updated):
        """Alternate between CPU and GPU modes based on number of metrics updates"""
        if not self.layout:
            print("Warning: layout.json not loaded. Cannot display alternating mode.")
            return

        cpu_unit = self.config.get('cpu_temperature_unit', 'celsius')
        gpu_unit = self.config.get('gpu_temperature_unit', 'celsius')
        temp_unit = {'cpu': cpu_unit, 'gpu': gpu_unit}

        if metrics_updated:
            self.metrics_updates += 1
            if self.metrics_updates >= self.alternating_cycle_duration:
                self.metrics_updates = 0
                self.showing_cpu = not self.showing_cpu
        # Get metrics
        metrics = self.metrics.get_metrics(temp_unit=temp_unit)
        
        # Get colors based on current metrics
        self.colors = self.get_config_colors(self.config, key="metrics", metrics=metrics)
        
        # Display the appropriate mode based on showing_cpu flag
        if self.showing_cpu:
            # Display CPU mode
            cpu_usage = metrics.get("cpu_usage", 0)
            cpu_speed = metrics.get("cpu_speed", 0)
            cpu_temp = metrics.get("cpu_temp", 0)
            self.draw_usage_phantom_spirit(cpu_usage)
            self.draw_speed_phantom_spirit(cpu_speed)
            self.draw_temp_phantom_spirit(cpu_temp, device='cpu', unit=cpu_unit)
        else:
            # Display GPU mode
            gpu_usage = metrics.get("gpu_usage", 0)
            gpu_speed = metrics.get("gpu_speed", 0)
            gpu_temp = metrics.get("gpu_temp", 0)
            self.draw_usage_phantom_spirit(gpu_usage)
            self.draw_speed_phantom_spirit(gpu_speed)
            self.draw_temp_phantom_spirit(gpu_temp, device='gpu', unit=gpu_unit)

    def get_config_colors(self, config, key="metrics", metrics=None):
        conf_colors = config.get(key, {}).get('colors', ["ffe000"] * NUMBER_OF_LEDS)
        if len(conf_colors) != NUMBER_OF_LEDS:
            print(f"Warning: config {key} colors length mismatch, using default colors.")
            colors = ["ff0000"] * NUMBER_OF_LEDS
        else:
            if metrics is None:
                metrics = self.metrics.get_metrics(self.temp_unit)
            colors = []
            for i, color in enumerate(conf_colors):
                if color.lower() == "random":
                    colors.append(get_random_color())
                elif color.startswith("wave_"):
                    wave_type, gradient = color.split(";", 1)
                    colors_list = gradient.split('-')
                    num_colors = len(colors_list)
                    
                    if num_colors >= 2:
                        if colors_list[0] != colors_list[-1]:
                            colors_list.append(colors_list[0])
                        
                        num_segments = len(colors_list) - 1
                        total_duration = self.cycle_duration
                        
                        if wave_type == "wave_ltr":
                            phase_shift = (i / NUMBER_OF_LEDS) * total_duration
                        else: # wave_rtl
                            phase_shift = ((NUMBER_OF_LEDS - i) / NUMBER_OF_LEDS) * total_duration
                        
                        time_in_cycle = (self.cpt + phase_shift) % total_duration
                        
                        if num_segments > 0:
                            segment_duration = total_duration / num_segments
                            segment_index = min(int(time_in_cycle / segment_duration), num_segments - 1)
                            
                            start_color = colors_list[segment_index]
                            end_color = colors_list[segment_index + 1]
                            
                            time_in_segment = time_in_cycle - (segment_index * segment_duration)
                            if segment_duration > 0:
                                factor = time_in_segment / segment_duration
                            else:
                                factor = 0
                            colors.append(interpolate_color(start_color, end_color, factor))
                        else:
                            colors.append(colors_list[0])
                    else:
                        colors.append(colors_list[0])
                elif ";" in color:  # New multi-stop gradient format
                    parts = color.split(';')
                    metric = parts[0]
                    stops = []
                    for stop in parts[1:]:
                        stop_parts = stop.split(':')
                        stops.append({'color': stop_parts[0], 'value': int(stop_parts[1])})
                    
                    stops.sort(key=lambda x: x['value'])
                    
                    if metric not in metrics:
                        print(f"Warning: {metric} not found in metrics, using first color.")
                        colors.append(stops[0]['color'])
                        continue

                    metric_value = metrics[metric]

                    if metric_value <= stops[0]['value']:
                        colors.append(stops[0]['color'])
                        continue
                    
                    if metric_value >= stops[-1]['value']:
                        colors.append(stops[-1]['color'])
                        continue

                    for j in range(len(stops) - 1):
                        if stops[j]['value'] <= metric_value < stops[j+1]['value']:
                            start_stop = stops[j]
                            end_stop = stops[j+1]
                            factor = (metric_value - start_stop['value']) / (end_stop['value'] - start_stop['value'])
                            colors.append(interpolate_color(start_stop['color'], end_stop['color'], factor))
                            break
                elif "-" in color:
                    split_color = color.split("-")
                    if len(split_color) == 3:
                        start_color, end_color, metric = split_color
                        current_time = datetime.datetime.now()
                        if metric == "seconds":
                            factor = current_time.second / 59
                        elif metric == "minutes":
                            factor = current_time.minute / 59
                        elif metric == "hours":
                            factor = current_time.hour / 23
                        else:
                            if metric not in metrics:
                                print(f"Warning: {metric} not found in metrics, using start color.")
                                factor = 0
                            elif self.metrics_min_value[metric] == self.metrics_max_value[metric]:
                                print(f"Warning: {metric} min and max values are the same, using start color.")
                                factor = 0
                            else:
                                metric_value = metrics[metric]
                                min_val = self.metrics_min_value[metric]
                                max_val = self.metrics_max_value[metric]
                                factor = (metric_value - min_val) / (max_val - min_val)
                                factor = max(0, min(1, factor)) # Clamp factor between 0 and 1
                        colors.append(interpolate_color(start_color, end_color, factor))
                    else:
                        colors_list = split_color
                        num_colors = len(colors_list)
                        
                        if num_colors >= 2:
                            # Add first color to the end to make a loop
                            if colors_list[0] != colors_list[-1]:
                                colors_list.append(colors_list[0])
                            
                            num_segments = len(colors_list) - 1
                            total_duration = self.cycle_duration # number of steps
                            time_in_cycle = self.cpt % total_duration
                            
                            if num_segments > 0:
                                segment_duration = total_duration / num_segments
                                segment_index = min(int(time_in_cycle / segment_duration), num_segments - 1)
                                
                                start_color = colors_list[segment_index]
                                end_color = colors_list[segment_index + 1]
                                
                                time_in_segment = time_in_cycle - (segment_index * segment_duration)
                                if segment_duration > 0:
                                    factor = time_in_segment / segment_duration
                                else:
                                    factor = 0
                                colors.append(interpolate_color(start_color, end_color, factor))
                            else:
                                colors.append(colors_list[0])
                        else:
                            colors.append(colors_list[0])
                else:
                    colors.append(color)
        return np.array(colors)
    
    def update(self):
        self.leds = np.array([0] * NUMBER_OF_LEDS)
        self.config = self.load_config()
        updated = False
        if self.config:
            VENDOR_ID = int(self.config.get('vendor_id', "0x0416"),16)
            PRODUCT_ID = int(self.config.get('product_id', "0x8001"),16)
            self.metrics_max_value = {
                "cpu_temp": self.config.get('cpu_max_temp', 90),
                "gpu_temp": self.config.get('gpu_max_temp', 90),
                "cpu_usage": self.config.get('cpu_max_usage', 100),
                "gpu_usage": self.config.get('gpu_max_usage', 100),
                "cpu_speed": self.config.get('cpu_max_speed', 5000),
                "gpu_speed": self.config.get('gpu_max_speed', 2500),
            }
            self.metrics_min_value = {
                "cpu_temp": self.config.get('cpu_min_temp', 30),
                "gpu_temp": self.config.get('gpu_min_temp', 30),
                "cpu_usage": self.config.get('cpu_min_usage', 0),
                "gpu_usage": self.config.get('gpu_min_usage', 0),
                "cpu_speed": self.config.get('cpu_min_speed', 0),
                "gpu_speed": self.config.get('gpu_min_speed', 0),
            }
            self.display_mode = self.config.get('display_mode', 'cpu')
                
            self.temp_unit = {device: self.config.get(f"{device}_temperature_unit", "celsius") for device in ["cpu", "gpu"]}
            metrics = self.metrics.get_metrics(temp_unit=self.temp_unit)
            updated = metrics['updated']
            self.metrics_colors = self.get_config_colors(self.config, key="metrics", metrics=metrics)
            self.time_colors = self.get_config_colors(self.config, key="time", metrics=metrics)
            self.update_interval = self.config.get('update_interval', 0.1)
            self.cycle_duration = int(self.config.get('cycle_duration', 5)/self.update_interval)
            self.metrics.update_interval = self.config.get('metrics_update_interval', 0.5)
            self.leds_indexes = leds_indexes
            if self.display_mode not in display_modes:
                print(f"Warning: Display mode {self.display_mode} not compatible, switching to cpu.")
                self.display_mode = "cpu"
        else:
            VENDOR_ID = 0x0416
            PRODUCT_ID = 0x8001
            self.metrics_max_value = {
                "cpu_temp": 90,
                "gpu_temp": 90,
                "cpu_usage": 100,
                "gpu_usage": 100,
                "cpu_speed": 5000,
                "gpu_speed": 2500,
            }
            self.metrics_min_value = {
                "cpu_temp": 30,
                "gpu_temp": 30,
                "cpu_usage": 0,
                "gpu_usage": 0,
                "cpu_speed": 0,
                "gpu_speed": 0,
            }
            self.display_mode = 'cpu'
            self.time_colors = np.array(["ffe000"] * NUMBER_OF_LEDS)
            self.metrics_colors = np.array(["ff0000"] * NUMBER_OF_LEDS)
            self.update_interval = 0.1
            self.cycle_duration = int(5/self.update_interval)
            self.metrics.update_interval = 0.5
            self.leds_indexes = leds_indexes
        

        if VENDOR_ID != self.VENDOR_ID or PRODUCT_ID != self.PRODUCT_ID:
            print(f"Warning: Config VENDOR_ID or PRODUCT_ID changed, reinitializing device.")
            self.VENDOR_ID = VENDOR_ID
            self.PRODUCT_ID = PRODUCT_ID
            self.dev = self.get_device()

        return updated

    def display(self):
        while True:
            self.config = self.load_config()
            metrics_updated = self.update()
            if self.dev is None:
                print("No device found, with VENDOR_ID: {}, PRODUCT_ID: {}".format(self.VENDOR_ID, self.PRODUCT_ID))
                time.sleep(5)
            else:
                if self.display_mode == "cpu":
                    self.display_cpu_mode()
                elif self.display_mode == "gpu":
                    self.display_gpu_mode()
                elif self.display_mode == "alternating":
                    self.display_alternating(metrics_updated)
                elif self.display_mode == "debug_ui":
                    self.colors = self.metrics_colors
                    self.leds[:] = 1
                else:
                    print(f"Unknown display mode: {self.display_mode}")
                
                self.send_packets()
            time.sleep(self.update_interval)


def main(config_path):
    controller = Controller(config_path=config_path)
    controller.display()

if __name__ == '__main__':
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
        print(f"Using config path: {config_path}")
    else:
        print("No config path provided, using default.")
        config_path = None
    main(config_path)