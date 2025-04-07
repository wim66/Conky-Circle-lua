#!/bin/bash

# get_weather.sh v1.3
# by @wim66
# April 1 2025

# Determine script path and directories
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
WEATHER_DATA="$SCRIPT_DIR/weather_data.txt"
CACHE_DIR="$SCRIPT_DIR/cache"
ICON_DIR="$SCRIPT_DIR/weather-icons/dark/SagiSan"

# Load API configuration from settings.lua
API_KEY=$(lua -e 'require("settings"); conky_vars(); print(API_KEY)')
CITY_ID=$(lua -e 'require("settings"); conky_vars(); print(CITY_ID)')
UNITS=$(lua -e 'require("settings"); conky_vars(); print(UNITS)')
LANG=$(lua -e 'require("settings"); conky_vars(); print(LANG)')

# Fetch weather data from OpenWeatherMap API
WEATHER_RESPONSE=$(curl -s "http://api.openweathermap.org/data/2.5/weather?id=$CITY_ID&appid=$API_KEY&units=$UNITS&lang=$LANG")

# Check if API request was successful
if echo "$WEATHER_RESPONSE" | jq -e '.cod // 0' | grep -qE '4[0-9][0-9]'; then
    echo "Error: Unable to fetch weather data." >&2
    exit 1
fi

# Function to translate weather descriptions
translate_weather() {
    local desc="$1"
    case "$desc" in
        "zeer lichte bewolking")
            echo "lichte bewolking"  # Translate "very light clouds" to "light clouds"
            ;;
        # Add more translations here if needed, for example:
        # "heavy rain")
        #     echo "severe rain"  # Translate "heavy rain" to "severe rain"
        #     ;;
        *)
            echo "$desc"  # Default: return the original description unchanged
            ;;
    esac
}

# Parse JSON response
CITY=$(echo "$WEATHER_RESPONSE" | jq -r .name)
WEATHER_ICON=$(echo "$WEATHER_RESPONSE" | jq -r '.weather[0].icon')
WEATHER_DESC=$(echo "$WEATHER_RESPONSE" | jq -r '.weather[0].description')
WEATHER_DESC=$(translate_weather "$WEATHER_DESC")
TEMP=$(echo "$WEATHER_RESPONSE" | jq -r '.main.temp')
TEMP_MIN=$(echo "$WEATHER_RESPONSE" | jq -r '.main.temp_min')
TEMP_MAX=$(echo "$WEATHER_RESPONSE" | jq -r '.main.temp_max')
HUMIDITY=$(echo "$WEATHER_RESPONSE" | jq -r '.main.humidity')
WIND_SPEED=$(echo "$WEATHER_RESPONSE" | jq -r '.wind.speed')

# Remove decimal places from temperatures
TEMP=${TEMP%.*}
TEMP_MIN=${TEMP_MIN%.*}
TEMP_MAX=${TEMP_MAX%.*}

# Append temperature unit based on the UNITS setting
if [ "$UNITS" = "metric" ]; then
    TEMP="${TEMP}°C"
    TEMP_MIN="${TEMP_MIN}°C"
    TEMP_MAX="${TEMP_MAX}°C"
elif [ "$UNITS" = "imperial" ]; then
    TEMP="${TEMP}°F"
    TEMP_MIN="${TEMP_MIN}°F"
    TEMP_MAX="${TEMP_MAX}°F"
fi

# Check if the weather icon file exists before copying
ICON_PATH="${ICON_DIR}/${WEATHER_ICON}.png"
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "${CACHE_DIR}/weathericon.png"
else
    echo "Warning: Icon $ICON_PATH not found!" >&2
fi

# Write weather data to file
cat <<EOF > "$WEATHER_DATA"
CITY=$CITY
LANG=$LANG
WEATHER_DESC=$WEATHER_DESC
TEMP=$TEMP
TEMP_MIN=$TEMP_MIN
TEMP_MAX=$TEMP_MAX
HUMIDITY=$HUMIDITY
WIND_SPEED=$WIND_SPEED
EOF
