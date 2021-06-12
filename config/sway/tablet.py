#!/usr/bin/python
 
import evdev
import psutil
import os
import subprocess
 
vendor = 9580
product = 109
version = 273
name = "Pad"
 
bindings = {
    256: "CTRL+Shift+H",
    259: "CTRL+-",
    260: "CTRL+Shift+=",
    257: "B",
    258: "Tab",
    261: "E",
    262: "CTRL+Z",
    263: "CTRL+Shift+Z"
        }
 
path = ""
 
ydotoold_found = False
for proc in psutil.process_iter():
    try:
        if "ydotoold" in proc.name():
            ydotoold_found = True
            break
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass
if not ydotoold_found:
    print("launching ydotoold")
    subprocess.Popen("ydotoold", close_fds = True)
    print("launched")
 
devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
 
for device in devices:
    if name in device.name \
            and device.info.vendor == vendor \
            and device.info.product == product \
            and device.info.version == version:
                path = device.path
                print(path)
                break
 
device = evdev.InputDevice(path)
for event in device.read_loop():
    if event.type == evdev.ecodes.EV_KEY:
        print(event.code, event.value)
        if (event.code in bindings.keys()):
            press = "--down" if event.value == 1 else "--up"
            subprocess.run(["ydotool", "key", press, bindings[event.code]])
