#!/bin/bash
# https://github.com/pir8radio/Time-Temperature-Service

# -- EDIT THE LAT AND LON BELOW FOR THE AREA YOU WANT TO GET A TEMPERATURE VALUE FOR (lines 8 & 9) --
# --- Paths ---
CACHE_FILE="/var/lib/asterisk/last_known_temp"
LOG_FILE="/var/lib/asterisk/temp_script.log"
LAT="41.878"    # Latitude for weather lookup
LON="-87.629"   # Longitude for weather lookup
WEATHER_URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,apparent_temperature&temperature_unit=fahrenheit"

# --- Use cached temp if less than 10 minutes old keeps api calls to weather service lower ---
if [[ -f "$CACHE_FILE" ]]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    if [[ "$CACHE_AGE" -lt 600 ]]; then
        CACHED=$(< "$CACHE_FILE")
        # echo "$(date '+%Y-%m-%d %H:%M:%S') - Using cached temp: $CACHED" >> "$LOG_FILE"
        echo "$CACHED" | tr -d '\n'
        exit 0
    fi
fi

# --- Ensure files exist without updating timestamps ---
[[ -f "$CACHE_FILE" ]] || echo "0|0" > "$CACHE_FILE"
[[ -f "$LOG_FILE" ]] || touch "$LOG_FILE"
chmod 666 "$CACHE_FILE" "$LOG_FILE"

# --- Fetch both values ---
RAW_JSON=$(curl -s "$WEATHER_URL")
RAW_TEMP=$(echo "$RAW_JSON" | jq '.current.temperature_2m')
RAW_FEELS=$(echo "$RAW_JSON" | jq '.current.apparent_temperature')

# --- Round and validate temperature ---
if [[ "$RAW_TEMP" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    TEMP=$(printf "%.0f" "$RAW_TEMP")
    if [[ "$TEMP" -lt -80 || "$TEMP" -gt 130 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Temp out-of-range. Using fallback." >> "$LOG_FILE"
        TEMP=""
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Temp non-numeric. Using fallback." >> "$LOG_FILE"
    TEMP=""
fi

# --- Round and validate apparent temperature ---
if [[ "$RAW_FEELS" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    FEELS=$(printf "%.0f" "$RAW_FEELS")
    if [[ "$FEELS" -lt -80 || "$FEELS" -gt 130 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Feels-like out-of-range. Using fallback." >> "$LOG_FILE"
        FEELS=""
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Feels-like non-numeric. Using fallback." >> "$LOG_FILE"
    FEELS=""
fi

# --- Fallbacks ---
[[ -z "$TEMP" || -z "$FEELS" ]] && {
    [[ -f "$CACHE_FILE" ]] && {
        CACHED=$(< "$CACHE_FILE")
        TEMP=${CACHED%%|*}
        FEELS=${CACHED##*|}
    }
    [[ -z "$TEMP" ]] && TEMP="0"
    [[ -z "$FEELS" ]] && FEELS="0"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Fallbacks used: Temp=$TEMP Feels=$FEELS" >> "$LOG_FILE"
}

# --- Save good reading in pipe-separated format ---
echo "${TEMP}|${FEELS}" > "$CACHE_FILE"

# --- Return to dialplan ---
echo "${TEMP}|${FEELS}" | tr -d '\n'
