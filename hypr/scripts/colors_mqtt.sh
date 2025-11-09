#!/usr/bin/env bash

COLOR_FILE="$HOME/.config/Ax-Shell/config/hypr/colors.conf"
BROKER="192.168.1.246"
TOPIC="home/led/color"

PRIMARY_HEX=$(grep -m1 '^\$primary ' "$COLOR_FILE" | awk '{print $3}' | tr -d '\r\n')

if [[ -z "$PRIMARY_HEX" ]]; then
  echo "❌ Could not find '$primary' in $COLOR_FILE"
  exit 1
fi

# Remove '#' if present
PRIMARY_HEX="${PRIMARY_HEX/#\#/}"

# Convert hex to decimal RGB
R=$((16#${PRIMARY_HEX:0:2}))
G=$((16#${PRIMARY_HEX:2:2}))
B=$((16#${PRIMARY_HEX:4:2}))

# Adjust color balance (reduce green/blue)
G=$(printf "%.0f" "$(echo "$G * 0.8" | bc -l)")
B=$(printf "%.0f" "$(echo "$B * 0.8" | bc -l)")

# Ensure RGB values are within 0–255
R=$((R < 0 ? 0 : (R > 255 ? 255 : R)))
G=$((G < 0 ? 0 : (G > 255 ? 255 : G)))
B=$((B < 0 ? 0 : (B > 255 ? 255 : B)))

# Publish as JSON-like list
mosquitto_pub -h "$BROKER" -t "$TOPIC" -m "[$R,$G,$B]"

echo "✅ Sent adjusted color as [$R,$G,$B] to MQTT topic '$TOPIC'"
