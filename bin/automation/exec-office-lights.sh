#!/bin/bash
VAL=1
if [[ $# -eq 1 ]]; then
  VAL=$1
fi
tplink-smarthome-api setPowerState 192.168.86.32 $VAL
tplink-smarthome-api setPowerState 192.168.86.27 $VAL
