#!/bin/bash

help() {
   local CRY="\033[1;33m"
   local CRG="\033[1;32m"
   local CRB="\033[1;34m"
   local CRC="\033[0;36m"
   local NC="\033[0m"

   echo -e "${CRB}=========================================================${NC}"
   echo -e " Target Device: ${CRY}$DEVICE_CODENAME${NC}"
   echo -e "${CRB}=========================================================${NC}"
   echo ""
   echo -e "${CRY}Usage:${NC} dtool --build ${CRG}[command]${NC} [options]"
   echo ""
   echo -e "${CRY}Commands:${NC}"
   
   echo -e "  ${CRG}pull${NC}\t\t\tPull device trees."
   echo ""
   echo -e "  ${CRG}build${NC} [clean]\t\tFull clean build (Recommended for production)."
   echo -e "               \t\tWipes the ${CRC}out/${NC} directory if 'clean' is passed."
   echo ""
   echo -e "  ${CRG}dev-build${NC} [clean]\tFast build (Developers only)."
   echo -e "               \t\tWipes the ${CRC}out/${NC} directory if 'clean' is passed."
   echo ""
   echo -e "  ${CRG}make-signing-keys${NC}\tGenerate signing keys in system or home directory."
   echo ""
   echo -e "  ${CRG}make-signed-ota${NC} [num]\tCreate a signed OTA package."
   echo -e "               \t\tTarget build: ${CRY}${BUILD_NUMBER}${NC} (or pass custom arg)."
   echo ""
   echo -e "  ${CRG}install${NC} [num]\t\tSideload OTA to a connected device."
   echo -e "               \t\tTarget build: ${CRY}${BUILD_NUMBER}${NC} (or pass custom arg)."
   echo ""
}

source_envsetup() {
   if [ -z "$BUILD_NUMBER" ]; then 
      if ! source ./build/envsetup.sh; then
         echo "Failed to include \"envsetup.sh\""
         echo "Are you sure you are in ROM source directory?"
         return 1
      fi
   fi
   return 0
}

lunch_device() {
   lunch "$DEVICE_CODENAME-cur-$BUILD_TYPE" || return 1
   return 0
}

pull_device_trees() {
   if ! "$ROMPATH/vendor/adevtool/bin/run" &> /dev/null; then
      yarn --cwd vendor/adevtool/ install || return 8
   fi
   "$ROMPATH/vendor/adevtool/bin/run" generate-all -d "$DEVICE_CODENAME"
}

build() {
   lunch_device || return 4
   if [ "$1" == "clean" ]; then
      rm -rf "./out"
   fi
   m vendorbootimage vendorkernelbootimage target-files-package -j"$(nproc --all)"
}

developer_build() {
   lunch_device || return 4
   if [ "$1" == "clean" ]; then
      rm -rf "$ROMPATH/out"
   fi
   m -j"$(nproc --all)"
}

make_ota_tools() {
   lunch_device || return 4
   m otatools-package -j"$(nproc --all)"
   "$ROMPATH/script/finalize.sh"
}

check_if_keys_are_created() {
   if [ -d "$ROMPATH/keys/$DEVICE_CODENAME" ]; then
      return 0
   elif [ -d "$HOME/dryblood_device_keys/$DEVICE_CODENAME" ]; then
      [ -d "$ROMPATH/keys" ] || mkdir -p "$ROMPATH/keys"
      ln -sf "$HOME/dryblood_device_keys/$DEVICE_CODENAME" "$ROMPATH/keys" 
      return 0
   fi
   return 1
}

generate_keys() {
   local CN="GrapheneOS"
   local DIRNAME="$1"
   local DIRPATH
   if [ -z "$DIRNAME" ]; then
      DIRPATH="$(pwd)/dryblood_device_keys/$DEVICE_CODENAME"
   else 
      DIRPATH="$DIRNAME/dryblood_device_keys/$DEVICE_CODENAME"
   fi
   if [ ! -d "$DIRPATH" ]; then
      mkdir -p "$DIRPATH"
   fi
   cd "$DIRPATH" || return 1
   "$ROMPATH/development/tools/make_key" releasekey "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" platform "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" shared "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" media "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" networkstack "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" bluetooth "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" sdk_sandbox "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" gmscompat_lib "/CN=$CN/"
   "$ROMPATH/development/tools/make_key" nfc "/CN=$CN/"
   openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -out avb.pem
   "$ROMPATH/external/avb/avbtool.py" extract_public_key --key avb.pem --output avb_pkmd.bin
   cd "$ROMPATH" || return 1
   return 0
}

make_signing_keys() {
   check_if_keys_are_created && return 0
   local choice
   read -rp "Do you want to create keys in safe way at your home directory\nand then link them in to system source to avoid lossing them?[Y/n]:" choice
   case "$choice" in
      y|Y) 
         generate_keys "$HOME" || return 7
      ;;
      *)
         generate_keys "$(pwd)" || return 7
      ;;
   esac
   return 0
}

sign_ota() {
   make_signing_keys || return 1
   BUILD_NUMBER_TO_SIGN="$BUILD_NUMBER"
   if [ -n "$1" ]; then
      BUILD_NUMBER_TO_SIGN="$1"
   fi
   "$ROMPATH/script/generate-release.sh" "$DEVICE_CODENAME" "$BUILD_NUMBER_TO_SIGN"
   return 0
}

install_ota() {
   BUILD_NUMBER_TO_INSTALL="$BUILD_NUMBER"
   [ -z "$1" ] || BUILD_NUMBER_TO_INSTALL="$1"
   OTA_PATH="$ROMPATH/releases/$BUILD_NUMBER_TO_INSTALL/release-$DEVICE_CODENAME-$BUILD_NUMBER_TO_INSTALL"
   OTA_FILENAME="$DEVICE_CODENAME-ota_update-$BUILD_NUMBER_TO_INSTALL.zip"
   if [ ! -f "$OTA_PATH/$OTA_FILENAME" ]; then
      echo "No OTA was found, please first build and sign your package"
   fi
   adb sideload "$OTA_PATH/$OTA_FILENAME"
}

if [ -z "$BUILD_TYPE" ]; then
   export BUILD_TYPE="user"
   save_config_from_data
fi

if [ -z "$DEVICE_CODENAME" ]; then
   read -rp "Enter device codename (e.g. frankel): " DEVICE_CODENAME
   export DEVICE_CODENAME
   save_config_from_data
fi

if [ "$1" == "help" ] || [ -z "$1" ]; then
   help
   return 0
fi

source_envsetup || return 5

if [ "$1" == "pull" ]; then
   pull_device_trees
elif [ "$1" == "build" ]; then
   build "$2"
elif [ "$1" == "dev-build" ]; then
   developer_build "$2"
elif [ "$1" == "make-signing-keys" ]; then
   make_signing_keys
elif [ "$1" == "make-signed-ota" ]; then
   make_ota_tools
   sign_ota "$2"
elif [ "$1" == "install" ]; then
   install_ota "$2"
fi
