#!/bin/bash
python pirelli-cracker.py "$1" | grep -A2 BSSID | tail -2 | tr '\n' ' ' | \
awk '{printf("network={\n ssid=\"%s\"\n psk=\"%s\"\n}\n", $2, $5);}'
