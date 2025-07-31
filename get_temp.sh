#!/bin/bash
# https://github.com/pir8radio/Time-Temperature-Service

# -- EDIT THE LAT AND LON BELOW FOR THE AREA YOU WANT TO GET A TEMPERATURE VALUE FOR (lines 8 & 9) --
# --- Paths ---
CACHE_FILE="/var/lib/asterisk/last_known_temp"
LOG_FILE="/var/lib/asterisk/temp_script.log"
LAT="41.878"    # Latitude for weather lookup
LON="-87.629"   # Longitude for weather lookup
WEATHER_URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m&temperature_unit=fahrenheit"

# --- Use cached temp if less than 10 minutes old keeps api calls to weather service lower ---
if [[ -f "$CACHE_FILE" ]]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    if [[ "$CACHE_AGE" -lt 600 ]]; then
        TEMP=$(< "$CACHE_FILE")
        # echo "$(date '+%Y-%m-%d %H:%M:%S') - Using cached temp: $TEMP" >> "$LOG_FILE"
        echo "$TEMP" | tr -d '\n'
        exit 0
    fi
fi

# --- Ensure files exist without updating timestamps ---
[[ -f "$CACHE_FILE" ]] || echo "0" > "$CACHE_FILE"
[[ -f "$LOG_FILE" ]] || touch "$LOG_FILE"
chmod 666 "$CACHE_FILE" "$LOG_FILE"

# --- Fetch current temperature in Fahrenheit ---
RAW_TEMP=$(curl -s "$WEATHER_URL" | jq '.current.temperature_2m')

# --- Log raw result ---
# echo "$(date '+%Y-%m-%d %H:%M:%S') - Raw temp: $RAW_TEMP" >> "$LOG_FILE"

# --- Validate: numeric and within expected range ---
if [[ "$RAW_TEMP" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    # Round to nearest integer, preserving sign
    TEMP=$(printf "%.0f" "$RAW_TEMP")
    if [[ "$TEMP" -ge -80 && "$TEMP" -le 130 ]]; then
        # echo "$(date '+%Y-%m-%d %H:%M:%S') - Using valid rounded API temp: $TEMP" >> "$LOG_FILE"
        :
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Out-of-range value. Using fallback." >> "$LOG_FILE"
        TEMP=""
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Non-numeric result. Using fallback." >> "$LOG_FILE"
    TEMP=""
fi

# --- Fallbacks ---
if [[ -z "$TEMP" ]]; then
    [[ -f "$CACHE_FILE" ]] && TEMP=$(< "$CACHE_FILE")
    [[ -z "$TEMP" ]] && TEMP="0"    # falls back to 0 if no temp can be found from service or cache file, useful for troubleshooting
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Fallback temp used: $TEMP" >> "$LOG_FILE"
fi

# --- Save good reading ---
echo "$TEMP" > "$CACHE_FILE"

# --- Return to dialplan ---
# Remove all non-numeric characters except minus sign
echo "$TEMP" | tr -d '\n'
