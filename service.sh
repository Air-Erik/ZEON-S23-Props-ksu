#!/system/bin/sh
MODDIR="${0%/*}"
echo "[ZB] service.sh start $(date)" >> "$MODDIR/props.log"
settings put global device_name "Galaxy S23 Ultra"
settings put secure bluetooth_name "Galaxy S23 Ultra"
