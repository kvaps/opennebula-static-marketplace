#!/bin/sh
ONE_LOCATION="${ONE_LOCATION:/var/lib/one}"
WORKING_DIR="$(dirname "$(readlink -f "$0")")"
LIB_DIR="$WORKING_DIR/lib"

if [ -n "$1" ]; then
  DIR="$1"
else
  DIR="$WORKING_DIR/appliances"
fi

if ! command -V ruby >/dev/null 2>/dev/null; then
  echo "No ruby installed, Please install ruby"
fi

if [ -f "$ONE_LOCATION/remotes/market/one/monitor" ]; then
  MONITOR_SCRIPT="$ONE_LOCATION/remotes/market/one/monitor"
else
  MONITOR_SCRIPT="$LIB_DIR/monitor"
  if [ ! -f "$MONITOR_SCRIPT" ]; then
    echo "Downloading monitor script to $MONITOR_SCRIPT"
    mkdir -p "$(dirname $MONITOR_SCRIPT)"
    curl -s https://raw.githubusercontent.com/OpenNebula/one/master/src/market_mad/remotes/one/monitor -o "$MONITOR_SCRIPT"
    sed -i -e "/^ *VERSION *=/ s/=.*/= ENV['VERSION']/g" -e "/^ *@agent *=/ s/=.*/= \"OpenNebula #{VERSION} (#{AGENT})\"/g" "$MONITOR_SCRIPT"
    chmod +x "$MONITOR_SCRIPT"
  fi
fi

echo "Writing appliances into $DIR"
mkdir -p "$DIR"

$MONITOR_SCRIPT | while read line; do
  APP="$(echo "$line" | awk -F\" '{print $2}' | base64 -d)"
  IMPORT_ID=$(echo "$APP" | sed -n 's/^IMPORT_ID="\(.*\)"$/\1/p')
  APPTEMPLATE64=$(echo "$APP" | sed -n 's/^APPTEMPLATE64="\(.*\)"$/\1/p')
  VMTEMPLATE64=$(echo "$APP" | sed -n 's/^VMTEMPLATE64="\(.*\)"$/\1/p')
  mkdir -p "$DIR/$IMPORT_ID"
  if [ -n "$APPTEMPLATE64" ]; then
    echo "$APPTEMPLATE64" | base64 -d > "$DIR/$IMPORT_ID/apptemplate.conf"
    APP=$(echo "$APP" | sed '/^APPTEMPLATE64=/d')
  fi
  if [ -n "$VMTEMPLATE64" ]; then
    echo "$VMTEMPLATE64" | base64 -d > "$DIR/$IMPORT_ID/vmtemplate.conf"
    APP=$(echo "$APP" | sed '/^VMTEMPLATE64=/d')
  fi
  echo "$APP" > "$DIR/$IMPORT_ID/app.conf"
done
