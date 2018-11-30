#!/bin/sh
LIB_DIR="$(dirname "$(readlink -f "$0")")/lib"

if [ -n "$1" ]; then
  DIR="$1"
else
  DIR="./appliances"
fi

if ! command -V ruby >/dev/null 2>/dev/null; then
  echo "No ruby installed, Please install ruby"
fi

MONITOR_SCRIPT="$LIB_DIR/monitor"
MONITOR_VERSION="release-5.6.2"
if [ ! -f "$MONITOR_SCRIPT" ]; then
  echo "Downloading appmarket monitor script"
  mkdir -p "$(dirname $MONITOR_SCRIPT)"
  curl -s "https://raw.githubusercontent.com/OpenNebula/one/$MONITOR_VERSION/src/market_mad/remotes/one/monitor" -o "$MONITOR_SCRIPT"
  echo "Applying changes"
  sed -i \
      -e "/^ *VERSION *=/ s/=.*/= ENV['VERSION']/g" \
      -e "/^ *@agent *=/ s/=.*/= \"OpenNebula #{VERSION} (#{AGENT})\"/g" \
      -e "/^ *source *=/ s/=.*/= app[\"files\"][0][\"url\"]/g" \
      "$MONITOR_SCRIPT"
  chmod +x "$MONITOR_SCRIPT"
fi

echo "Processing appliances"
mkdir -p "$DIR"

$MONITOR_SCRIPT | while read line; do
  APP="$(echo "$line" | awk -F\" '{print $2}' | base64 -d)"
  IMPORT_ID=$(echo "$APP" | sed -n 's/^IMPORT_ID="\(.*\)"$/\1/p')
  APPTEMPLATE64=$(echo "$APP" | sed -n 's/^APPTEMPLATE64="\(.*\)"$/\1/p')
  VMTEMPLATE64=$(echo "$APP" | sed -n 's/^VMTEMPLATE64="\(.*\)"$/\1/p')
  echo "$DIR/$IMPORT_ID"
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
