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
    256: "CTRL+z",
    257: "Shift",
    258: "CTRL",
    259: "=",
    260: "-",
    261: "4",
    262: "5",
    263: "6"
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
