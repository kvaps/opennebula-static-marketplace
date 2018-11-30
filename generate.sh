#!/bin/sh
if [ -n "$1" ]; then
  DIR="$1"
else
  DIR="$(dirname "$(readlink -f "$0")")"
fi

find "$DIR" -name app.conf -exec dirname {} \; | while read APP_DIR; do
  APP="$APP_DIR/app.conf"
  APP_TEMPLATE="$APP_DIR/apptemplate.conf"
  VM_TEMPLATE="$APP_DIR/vmtemplate.conf"
  echo -n 'APP="'
  echo "$(
    cat "$APP"
    if [ -f "$APP_TEMPLATE" ]; then
      echo "APPTEMPLATE64=\"$(cat "$APP_TEMPLATE" | base64 -w0)\""
    fi
    if [ -f "$VM_TEMPLATE" ]; then
      echo "VMTEMPLATE64=\"$(cat "$VM_TEMPLATE" | base64 -w0)\""
    fi
  )" | base64 -w0
  echo '"'

done
