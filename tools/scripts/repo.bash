REMOTE="https://github.com/GrapheneOS/platform_manifest.git"

help() {
    echo -e "${CRB}=========================================================${NC}"
    echo -e " Remote Tag: $REMOTE_UPDATE_TAG"
    echo -e "${CRB}=========================================================${NC}"
    echo ""
    echo -e "${CRY}Usage:${NC} dtool --repo ${CRG}<command>${NC} [options]"
    echo ""
    echo -e "${CRY}Commands:${NC}"
    echo -e "  ${CRG}init${NC} <number>\t\tInitialize remote repository."
    echo -e "               \t\tRequires a repository/build number."
    echo ""
    echo -e "  ${CRG}update${NC} <number>\tUpdates remote repository."
    echo -e "               \t\tRequires a target update version number."
    echo ""
    echo -e "  ${CRG}sync${NC} [fast/normal]\tSyncing files with remote repository."
    echo -e "               \t\tDefaults to 'fast' if no option is passed."
    echo ""
    echo -e "  ${CRG}reset${NC}\t\t\tHard reset any local changes made to system."
    echo -e "               \t\t${CRY}Warning:${NC} This will wipe all uncommitted local edits."
    echo ""
}

get_latest_stable_tag() {
    REMOTE_UPDATE_TAG=$(git ls-remote --tags --refs "$REMOTE" | awk -F/ '{print $3}' | grep -E '^[0-9]+$' | sort -rn | head -n1)
    save_config_from_data
}

init_remote() {
    if [ -z "$1" ]; then
        repo init -u "$REMOTE" -b "refs/tags/$REMOTE_UPDATE_TAG"
    else
        repo init -u "$REMOTE" -b "refs/tags/$1"
    fi
}

update_remote() {
    if [ -z "$1" ]; then
        repo init -b "refs/tags/$REMOTE_UPDATE_TAG"
    else
        repo init -b "refs/tags/$1"
    fi
}

sync_remote() {
    if [ "$1" == "normal" ]; then
        repo -j$(nproc --all)
    else
        repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)
    fi
}

reset_remote() {
    repo forall -c "git reset --hard HEAD && git clean -fdx"
}

get_latest_stable_tag

case "$1" in
   "init")
      init_remote "$2"
   ;;
   "update")
      update_remote "$2"
   ;;
   "sync")
      sync_remote "$2"
   ;;
   "reset")
      reset_remote
   ;;
   *)
      help
   ;;
esac