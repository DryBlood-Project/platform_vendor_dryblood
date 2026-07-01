#!/bin/bash

CRY="\033[1;33m"
CRG="\033[1;32m"
CRB="\033[1;34m"
CRC="\033[0;36m"
NC="\033[0m"

ROMPATH="$(pwd)"
if [[ "$ROMPATH" != *"DryBloodOS" ]]; then
   echo "Please go into rom directory!!!"
   return 6
fi
LOCAL_PATH="$ROMPATH/vendor/dryblood/tools/scripts"
. "$LOCAL_PATH/data.bash"

save_config_from_data() {
   cat > "$LOCAL_PATH/data.bash" << EOF 
DEVICE_CODENAME="$DEVICE_CODENAME"
BUILD_TYPE="$BUILD_TYPE"
REMOTE_UPDATE_TAG="$REMOTE_UPDATE_TAG"
EOF
}

case "$1" in
   "--build")
      . "$LOCAL_PATH/build.bash" "$2" "$3"
   ;;
   "--repo")
      . "$LOCAL_PATH/repo.bash" "$2" "$3"
   ;;
esac