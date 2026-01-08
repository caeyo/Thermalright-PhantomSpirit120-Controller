import subprocess
import re
import psutil
import time
import os
import json

try:
    import pyamdgpuinfo
except Exception as e:
    print("pyamdgpuinfo cannot start : ",str(e))



class Metrics:
    def __init__(self, update_interval=0.5):
        self.metrics_functions = {
            'cpu_temp': None,
            'gpu_temp': None,
            'cpu_usage': None,
            'gpu_usage': None,
            'cpu_speed': None,
            'gpu_speed': None
        }
        self.metrics = {
            'cpu_temp': 0,
            'gpu_temp': 0,
            'cpu_usage': 0,
            'gpu_usage': 0,
            'cpu_speed': 0,
            'gpu_speed': 0,
        }
        config_path = os.environ.get('DIGITAL_LCD_CONFIG', os.path.join(os.path.dirname(os.path.dirname(__file__)), 'config.json'))
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
                self.gpu_vendor = config.get('gpu_vendor', 'nvidia')
        except Exception as e:
            print(f"Could not load config to get gpu_vendor, defaulting to nvidia: {e}")
            self.gpu_vendor = 'nvidia'

        try:
            device_count = pyamdgpuinfo.detect_gpus()
            if device_count > 0:
                self.gpu = pyamdgpuinfo.get_gpu(0)
            else:
                print(f"No AMD GPU detected.")
                self.gpu = -1
        except:
            print("pyamdgpuinfo not installed. GPU temperature will not be available.")
            self.gpu = None

        candidates =  {
            'cpu_temp': [get_cpu_temp_psutils, get_cpu_temp_linux, get_cpu_temp_raspberry_pi],
            'gpu_temp': [],
            'cpu_usage': [get_cpu_usage],
            'gpu_usage': [],
            'cpu_speed': [get_cpu_speed_psutil, get_cpu_speed_proc],
            'gpu_speed': []
        }

        if self.gpu_vendor == 'nvidia':
            candidates['gpu_temp'] = [get_gpu_temp_nvidia]
            candidates['gpu_usage'] = [get_gpu_usage_nvml, get_gpu_usage_nvidia_smi]
            candidates['gpu_speed'] = [get_gpu_speed_nvml, get_gpu_speed_nvidia_smi]
        elif self.gpu_vendor == 'amd':
            candidates['gpu_temp'] = [self.get_gpu_temp_amdgpuinfo]
            candidates['gpu_usage'] = [self.get_gpu_usage_amd]
            candidates['gpu_speed'] = [self.get_gpu_speed_amd]
        for metric, functions in candidates.items():
            for function in functions:
                try:
                    result = function()
                    if result is not None:
                        self.metrics[metric] = int(result)
                        self.metrics_functions[metric] = function
                        break
                except Exception as e:
                    continue
            if self.metrics_functions[metric] is None:
                print(f"Warning: No suitable function found for {metric}.")
        self.last_update = time.time()
        self.update_interval = update_interval # seconds

    def get_metrics(self, temp_unit):
        if time.time() - self.last_update < self.update_interval:
            metrics = self.metrics.copy()
            metrics['updated'] = False
        else:
            for metric, function in self.metrics_functions.items():
                if function is not None:
                    try:
                        result = function()
                        if result is None:
                            self.metrics[metric] = 0
                        else:
                            self.metrics[metric] = int(result)
                    except Exception as e:
                        print(f"Error getting {metric}: {e}")
            self.last_update = time.time()
            metrics = self.metrics.copy()
            metrics['updated'] = True

        for device in ["cpu", "gpu"]:
            if temp_unit[device] == "fahrenheit":
                metrics[f"{device}_temp"] = int(metrics[f"{device}_temp"] * 9 / 5 + 32)
        return metrics

    def get_gpu_usage_amd(self):
        try:
            if self.gpu is None:
                return None
            else:
                return int(self.gpu.query_load()*100)
        except :
            return None
        
    def get_gpu_temp_amdgpuinfo(self):
        try:
            return self.gpu.query_temperature()
        except Exception as e:
            print(f"Error getting AMD GPU temperature: {e}")
            return None

    def get_gpu_speed_amd(self):
        try:
            if self.gpu is None:
                return None
            else:
                # Get current GPU clock in MHz
                return int(self.gpu.query_sclk() / 1000000)  # Convert from Hz to MHz
        except Exception as e:
            print(f"Error getting AMD GPU speed: {e}")
            return None

def get_cpu_temp_psutils():
    try:
        if hasattr(psutil, 'sensors_temperatures'):
            temps = psutil.sensors_temperatures()
            if temps:
                # Check common temperature sources
                for key in ['coretemp', 'cpu_thermal', 'k10temp', 'acpitz']:
                    if key in temps and temps[key]:
                        return temps[key][0].current
    except Exception:
        return None
def get_cpu_temp_linux():
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            return float(f.read().strip()) / 1000.0
    except Exception:
        return None
def get_cpu_temp_raspberry_pi():
    try:
        output = subprocess.check_output(['vcgencmd', 'measure_temp']).decode()
        return float(re.search(r'temp=(\d+\.\d+)', output).group(1))
    except Exception:
        return None

def get_gpu_temp_nvidia():
    # Try NVIDIA GPU first
    try:
        # Try using pynvml library
        try:
            from pynvml import nvmlInit, nvmlDeviceGetCount, nvmlDeviceGetHandleByIndex, \
                            nvmlDeviceGetTemperature, NVML_TEMPERATURE_GPU, nvmlShutdown
            
            nvmlInit()
            device_count = nvmlDeviceGetCount()
            
            if device_count > 0:
                handle = nvmlDeviceGetHandleByIndex(0)
                temp = nvmlDeviceGetTemperature(handle, NVML_TEMPERATURE_GPU)
                nvmlShutdown()
                return temp
            
            nvmlShutdown()
        except:
            # Try using nvidia-smi command
            output = subprocess.check_output(['nvidia-smi', '--query-gpu=temperature.gpu', '--format=csv,noheader']).decode()
            return float(output.strip().split('\n')[0])
    except:
        return None

def get_cpu_usage():
    """Get CPU usage percentage."""
    try:
        return psutil.cpu_percent(interval=None)
    except:
        print("Warning: Could not retrieve CPU usage.")
        return None

def get_gpu_usage_nvidia_smi():
    try: 
        output = subprocess.check_output(
            ['nvidia-smi', '--query-gpu=utilization.gpu',
                '--format=csv,noheader']
        ).decode().strip()
        return int(output.split()[0])
    except Exception:
        return None
    
def get_gpu_usage_nvml():
    try:
        # NVIDIA GPUs using pynvml
        from pynvml import (nvmlInit, nvmlShutdown,
                        nvmlDeviceGetHandleByIndex,
                        nvmlDeviceGetUtilizationRates)
        nvmlInit()
        try:
            handle = nvmlDeviceGetHandleByIndex(0)
            utilization = nvmlDeviceGetUtilizationRates(handle)
            return int(utilization.gpu)
        finally:
            nvmlShutdown()
    except:
        return None

def get_cpu_speed_psutil():
    """Get CPU frequency using psutil."""
    try:
        freq = psutil.cpu_freq()
        if freq is not None and freq.current is not None:
            return int(freq.current)
        return None
    except Exception:
        return None

def get_cpu_speed_proc():
    """Get CPU frequency from /proc/cpuinfo."""
    try:
        with open('/proc/cpuinfo', 'r') as f:
            for line in f:
                if 'cpu MHz' in line.lower():
                    match = re.search(r'(\d+\.?\d*)', line)
                    if match:
                        return int(float(match.group(1)))
        return None
    except Exception:
        return None

def get_gpu_speed_nvml():
    """Get GPU clock speed using pynvml."""
    try:
        from pynvml import (nvmlInit, nvmlShutdown,
                        nvmlDeviceGetHandleByIndex,
                        nvmlDeviceGetClockInfo, NVML_CLOCK_GRAPHICS)
        nvmlInit()
        try:
            handle = nvmlDeviceGetHandleByIndex(0)
            clock = nvmlDeviceGetClockInfo(handle, NVML_CLOCK_GRAPHICS)
            return int(clock)
        finally:
            nvmlShutdown()
    except:
        return None

def get_gpu_speed_nvidia_smi():
    """Get GPU clock speed using nvidia-smi."""
    try:
        output = subprocess.check_output(
            ['nvidia-smi', '--query-gpu=clocks.current.graphics',
                '--format=csv,noheader']
        ).decode().strip()
        # Output is in MHz, extract number
        match = re.search(r'(\d+)', output)
        if match:
            return int(match.group(1))
        return None
    except Exception:
        return None

