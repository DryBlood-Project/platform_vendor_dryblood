#!/bin/bash

help() {
   echo -e "${CRB}=========================================================${NC}"
   echo -e " Target Device: ${CRY}$DEVICE_CODENAME${NC}"
   echo -e "${CRB}=========================================================${NC}"
   echo ""
   echo -e "${CRY}Usage:${NC} dtool --build ${CRG}[command]${NC} [options]"
   echo ""
   echo -e "${CRY}Commands:${NC}"
   echo -e "  ${CRG}pull${NC}\t\t\t\t\tPull device trees."
   echo ""
   echo -e "  ${CRG}normal${NC} [clean]\t\t\tFull clean build (Recommended for production)."
   echo -e "               \t\t\t\tWipes the ${CRC}out${NC} directory if 'clean' is passed."
   echo ""
   echo -e "  ${CRG}fast${NC} [clean]\t\t\t\tFast build (Developers only)."
   echo -e "               \t\t\t\tWipes the ${CRC}out${NC} directory if 'clean' is passed."
   echo ""
   echo -e "  ${CRG}make-signing-keys${NC}\t\t\tGenerate signing keys in system or home directory."
   echo ""
   echo -e "  ${CRG}make-signed-ota${NC} [number]\t\tCreate a signed OTA package."
   echo -e "               \t\t\t\tTarget build: ${CRY}${BUILD_NUMBER}${NC} (or pass custom argument)."
   echo ""
   echo -e "  ${CRG}install${NC} [number]\t\t\tSideload OTA to a connected device."
   echo -e "               \t\t\t\tTarget build: ${CRY}${BUILD_NUMBER}${NC} (or pass custom argument)."
   echo ""
   echo -e "  ${CRG}change-device${NC} [codename]\t\tChanges device for build system."
   echo -e "               \t\t\t\tGet prompted or pass a custom argument."
   echo ""
   echo -e "  ${CRG}change-build-origin${NC} [(UN)OFFICIAL]\tChanges build origin."
   echo -e "               \t\t\t\tGet prompted or pass a custom argument."
   echo ""
   echo -e "  ${CRG}change-build-type${NC} [user(debug)|eng]\tChanges build type."
   echo -e "               \t\t\t\tGet prompted or pass a custom argument."
   echo ""
}

source_envsetup() {
   if [ -z "$BUILD_NUMBER" ]; then
      . "$LOCAL_PATH/repo.bash" check-for-update
      if ! source "$ROMPATH/build/envsetup.sh"; then
         echo "Failed to include \"envsetup.sh\""
         echo "Are you sure you are in ROM source directory?"
         unset BUILD_NUMBER
         return 1
      fi
   fi
   return 0
}

lunch_target_device() {
   if ! lunch "$DEVICE_CODENAME-cur-$BUILD_TYPE"; then
      echo "Failed to lunch $DEVICE_CODENAME"
      unset BUILD_NUMBER
      return 1
   fi
}

pull_device_trees() {
   if ! "$ROMPATH/vendor/adevtool/bin/run" &> /dev/null; then
      if ! yarn &> /dev/null; then
         echo -e " ${CRY}WARNING${NC} yarn or yarnpkg is not installed on this device"
         return 9
      fi
      yarn --cwd vendor/adevtool/ install || return 8
   fi
   if ! zip &> /dev/null; then
      echo -e " ${CRY}WARNING${NC} zip is not installed on this device"
      return 10
   fi
   echo -e " ${CRY}WARNING${NC} if you will get chrt error execute: \"${CR_L_GREEN}sudo setcap cap_sys_nice+ep $(which chrt)${NC}\""
   "$ROMPATH/vendor/adevtool/bin/run" generate-all -d "$DEVICE_CODENAME"
}

build() {
   if [ "$1" == "clean" ]; then
      rm -rf "./out"
   fi
   m vendorbootimage vendorkernelbootimage target-files-package -j"$(nproc --all)"
}

developer_build() {
   if [ "$1" == "clean" ]; then
      rm -rf "$ROMPATH/out"
   fi
   m -j"$(nproc --all)"
}

make_ota_tools() {
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
   chmod 600 id_ed25519
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

change-device() {
   local new_codename="$1"
   if [ -z "$new_codename" ]; then
      read -rp "Enter device codename (e.g. frankel): " new_codename
   fi
   DEVICE_CODENAME="$new_codename"
   save_config_to_data
}

change-build-origin() {
   local new_origin="$1"
   if [ -z "$new_origin" ]; then
      read -rp "Enter build origin [OFFICIAL|UNOFFICIAL]: " new_origin
   fi
   BUILD_ORIGIN_TYPE="$new_origin"
   save_config_to_data
   echo -e "${CRR}Remmember to edit \"packages/apps/Updater/res/values/config.xml\"${NC}"
}

change-build-type() {
   local new_type="$1"
   if [ -z "$new_type" ]; then
      read -rp "Enter build type [user(debug)|eng]: " new_type
   fi
   BUILD_TYPE="$new_type"
   save_config_to_data
}

if [ -z "$BUILD_TYPE" ]; then
   BUILD_TYPE="user"
   save_config_to_data
fi

if [ -z "$DEVICE_CODENAME" ]; then
   change-device
fi

source_envsetup || return 5

if [ "$BUILD_ORIGIN_TYPE" == "OFFICIAL" ]; then
   export OFFICIAL_BUILD=true
   echo -e "${CRB}You are building OFFICIAL${NC}"
fi

case "$1" in
   "pull")
      pull_device_trees
   ;;
   "normal")
      lunch_target_device
      build "$2"
   ;;
   "fast")
      lunch_target_device
      developer_build "$2"
   ;;
   "make-signing-keys")
      make_signing_keys
   ;;
   "make-signed-ota")
      lunch_target_device
      make_ota_tools
      sign_ota "$2"
   ;;
   "install")
      install_ota "$2"
   ;;
   "change-device")
      change-device "$2"
   ;;
   "change-build-origin")
      change-build-origin "$2"
   ;;
   "change-build-type")
      change-build-type "$2"
   ;;
   *)
      help
   ;;
esac