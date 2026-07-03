#!/bin/bash

ROMPATH="$(pwd)"
if [[ "$ROMPATH" != *"DryBloodOS" ]]; then
   echo "Please go into rom directory!!!"
   return 6
fi
LOCAL_PATH="$ROMPATH/vendor/dryblood/tools/scripts/dtool"
. "$LOCAL_PATH/data.bash"
. "$LOCAL_PATH/colors.bash"

save_config_to_data() {
   cat > "$LOCAL_PATH/data.bash" << EOF 
DEVICE_CODENAME="$DEVICE_CODENAME"
BUILD_TYPE="$BUILD_TYPE"
REMOTE_LOCAL_TAG="$REMOTE_LOCAL_TAG"
REMOTE_LATEST_TAG="$REMOTE_LATEST_TAG"
EOF
}

case "$1" in
   "--build")
      . "$LOCAL_PATH/build.bash" "$2" "$3"
   ;;
   "--repo")
      . "$LOCAL_PATH/repo.bash" "$2" "$3"
   ;;
   "--device")
      . "$LOCAL_PATH/device.bash" "$2" "$3"
   ;;
esac