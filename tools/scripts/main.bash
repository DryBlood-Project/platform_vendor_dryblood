#!/bin/bash

ROMPATH="$(pwd)"
if [[ "$ROMPATH" != *"DryBloodOS" ]]; then
   echo "Please go into rom directory!!!"
   return 6
fi

load_config_from_data() {
    . "$ROMPATH/data.bash"
}

save_config_from_data() {
   cat >> $ROMPATH/data.bash << EOF 
   DEVICE_CODENAME="$DEVICE_CODENAME"
   BUILD_TYPE="$BUILD_TYPE"
EOF
}