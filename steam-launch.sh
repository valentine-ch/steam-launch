#!/usr/bin/env bash

CFG_DIR="$HOME/.config/steam-launch"
ALIAS_FILE="$CFG_DIR/alias.json"
CFG_FILE="$CFG_DIR/config.cfg"
API_ENDPOINT="https://api.steampowered.com/IStoreService/GetAppList/v1/"

STEAM_COMMAND_DEFAULT="steam"
STEAMAPPS_PATH_DEFAULT="~/.steam/steam/steamapps"
USE_XDG_OPEN_DEFAULT="false"

shopt -s inherit_errexit
set -eu

use_flatpak_defaults() {
    STEAM_COMMAND_DEFAULT="\"flatpak run com.valvesoftware.Steam\""
    STEAMAPPS_PATH_DEFAULT="~/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps"
}

use_snap_defaults() {
    STEAMAPPS_PATH_DEFAULT="~/snap/steam/common/.steam/steam/steamapps"
}

create_cfg_dir() {
    echo "Initializing config directory at $CFG_DIR"
    mkdir -p "$CFG_DIR"
    echo "{}" > $ALIAS_FILE
    echo "steam_command=$STEAM_COMMAND_DEFAULT" >> $CFG_FILE
    echo "steamapps_path=$STEAMAPPS_PATH_DEFAULT" >> $CFG_FILE
    echo "use_xdg_open=$USE_XDG_OPEN_DEFAULT" >> $CFG_FILE
    echo -e "steam_args=\"\"" >> $CFG_FILE
    echo -e "redirect=\">/dev/null 2>&1 &\"" >> $CFG_FILE
    echo "api_key=null" >> $CFG_FILE
    echo "Done"
}

init_cfg() {
    if [ ! -d "$CFG_DIR" ]; then
        create_cfg_dir
    else
        echo "$CFG_DIR already exists" >&2
        exit 1
    fi
}

reset_cfg() {
    echo "Removing $CFG_DIR"
    rm -rf $CFG_DIR
    init_cfg
}

init_cfg_if_ne() {
    if [ ! -d "$CFG_DIR" ]; then
        create_cfg_dir
    fi
}

cfg_dir_exists() {
    if [ ! -d "$CFG_DIR" ]; then
        echo "Error: config directory at $CFG_DIR does not exist" >&2
        exit 1
    fi
}

launch_app() {
    source "$CFG_FILE"
    local app_id
    app_id=$(jq ".\"$1\"" "$ALIAS_FILE")
    if [ "$app_id" = "null" ]; then
        echo "Error: alias not found" >&2
        exit 1
    fi
    echo "Launching $1"
    if [ "$use_xdg_open" = true ] && pgrep -x "steam" > /dev/null; then
        eval "xdg-open steam://rungameid/$app_id $redirect"
    else
        eval "$steam_command $steam_args steam://rungameid/$app_id $redirect"
    fi 
}

invalid_arguments() {
    echo "Error: invalid arguments" >&2
    exit 1
}

validate_id() {
    if [[ ! "$1" =~ ^-?[0-9]+$ ]]; then
        invalid_arguments
    fi
}

add_alias_to_json() {
    local tmp
    tmp=$(mktemp)
    if ! jq --arg k "$1" --arg v "$2" '.[$k] = ($v | tonumber)' "$ALIAS_FILE" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$ALIAS_FILE"
    echo "Alias created successfully"
}

remove_alias_from_json() {
    local alias tmp
    alias=$(jq ".\"$1\"" "$ALIAS_FILE")
    if [ "$alias" = "null" ]; then
        echo "Error: alias not found" >&2
        exit 1
    fi
    tmp=$(mktemp)
    if ! jq "del(.\"$1\")" "$ALIAS_FILE" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$ALIAS_FILE"
    echo "Alias removed"
}

get_id_from_api() {
    source "$CFG_FILE"
    if [ "${api_key+x}" = "" ]; then
        echo "Error: config needs to be updated with API key" >&2
        return 1
    elif [ "$api_key" = null ]; then
        echo "Error: API key is not set" >&2
        return 1
    fi
    local last_appid=0
    local more_to_come=true
    local batch=1
    local response body status_code game
    while [ "$more_to_come" = true ]; do
        echo "Loading batch #$batch from $API_ENDPOINT" > /dev/tty
        response=$(curl -sS -w "\n%{http_code}" \
            "$API_ENDPOINT?key=$api_key&include_software=true&last_appid=$last_appid&max_results=50000")
        body=$(echo "$response" | sed '$d')
        status_code=$(echo "$response" | tail -n1)
        if [ "$status_code" -ne 200 ]; then
            echo "Error: received status code $status_code" >&2
        fi
        game=$(echo "$body" | jq ".response.apps[] | select(.name==\"$1\")")
        if [ -n "$game" ]; then
            echo "$game" | jq '.appid'
            return 0
        fi
        last_appid=$(echo "$body" | jq ".response.last_appid")
        more_to_come=$(echo "$body" | jq ".response.have_more_results")
        ((++batch))
    done
    echo "Error: no match for $1 found" >&2
    return 1
}

get_id_from_local_files() {
    source "$CFG_FILE"
    eval steamapps_path="$steamapps_path"
    local library_folders_file="$steamapps_path/libraryfolders.vdf"
    if [ ! -f $library_folders_file ]; then
        echo "Error: $library_folders_file doesn't exist" >&2
        return 1
    fi
    local library_paths app_id
    library_paths=$(grep '"path"' "$library_folders_file" |
                    sed -E 's/.*"path"[[:space:]]+"([^"]+)".*/\1/')
    while IFS= read -r library_path; do
        app_id=$(find "$library_path/steamapps" -maxdepth 1 -type f -name '*.acf' \
                -exec awk -v name="$1" -F '"' '
            FNR==1 && NR!=1 {
                if (game_name == name) {
                    print appid
                }
                appid=""; game_name=""
            }
            /"appid"/ { appid=$4 }
            /"name"/ { game_name=$4 }
            END {
                if (game_name == name) {
                    print appid
                }
            }
        ' {} +)
        if [ -n "$app_id" ]; then
            echo $app_id
            return 0
        fi
    done <<< "$library_paths"
    echo "Error: no match for $1 found" >&2
    return 1
}

get_optional_alias_name() {
    if [ -z "${2:-}" ]; then
        echo "$1"
    else
        echo "$2"
    fi
}

create_alias() {
    if [ "$#" -ne 3 ] && [ "$#" -ne 4 ]; then
        invalid_arguments
    fi
    local app_id alias_name
    case "$2" in
        "-a")
            app_id=$(get_id_from_api "$3")
            alias_name=$(get_optional_alias_name "${@:3}")
            add_alias_to_json "$alias_name" $app_id
            ;;
        "-l")
            app_id=$(get_id_from_local_files "$3")
            alias_name=$(get_optional_alias_name "${@:3}")
            add_alias_to_json "$alias_name" $app_id
            ;;
        "-m")
            if [ "$#" -ne 4 ]; then
                invalid_arguments
            fi
            validate_id "$4"
            add_alias_to_json "$3" "$4"
            ;;
        *)
            invalid_arguments
            ;;
    esac
}

list_aliases() {
    jq -r 'to_entries | .[] | "\(.key): \(.value)"' $ALIAS_FILE
}

set_background_mode() {
    case $1 in
        "true")
            sed -i 's/^redirect=.*/redirect=">\/dev\/null 2>\&1 \&"/' "$CFG_FILE"
            ;;
        "false")
            sed -i 's/^redirect=.*/redirect=""/' "$CFG_FILE"
            ;;
        *)
            invalid_arguments
            ;;
    esac
}

update_cfg() {
    if [ "$#" -eq 2 ] && [ "$2" = "--api-key" ]; then
        read -s -p "Enter your Steam Web API key: " api_key
        echo
        if [[ ! "$api_key" =~ ^[A-Za-z0-9]+$ ]]; then
            echo "Invalid key" >&2
            return 1
        fi
        if grep -q "api_key=" "$CFG_FILE"; then
            sed -i "s|^api_key=.*|api_key=$api_key|" "$CFG_FILE"
        else
            echo "api_key=$api_key" >> "$CFG_FILE"
        fi
        echo "Key added successfully"
        return 0
    fi
    validate_args_count 3 "$@"
    local escaped
    escaped=$(printf "%s" "$3" | sed 's/[&/\]/\\&/g')
    case "$2" in
        "--steam-command")
            sed -i "s|^steam_command=.*|steam_command=\"$escaped\"|" "$CFG_FILE"
            ;;
        "--steamapps-path")
            sed -i "s|^steamapps_path=.*|steamapps_path=\"$escaped\"|" "$CFG_FILE"
            ;;
        "--steam-args")
            sed -i "s|^steam_args=.*|steam_args=\"$escaped\"|" "$CFG_FILE"
            ;;
        "--redirect")
            sed -i "s|^redirect=.*|redirect=\"$escaped\"|" "$CFG_FILE"
            ;;
        "--background")
            set_background_mode $escaped
            ;;
        "--xdg-open")
            if [ "$escaped" != "true" ] && [ "$escaped" != "false" ]; then
                invalid_arguments
            fi
            sed -i "s|^use_xdg_open=.*|use_xdg_open=$escaped|" "$CFG_FILE"
            ;;
        *)
            invalid_arguments
            ;;
    esac
    echo "Config updated successfully"
}

reconfigure() {
    sed -i "s|^steam_command=.*|steam_command=$STEAM_COMMAND_DEFAULT|" "$CFG_FILE"
    sed -i "s|^steamapps_path=.*|steamapps_path=$STEAMAPPS_PATH_DEFAULT|" "$CFG_FILE"
    sed -i "s|^use_xdg_open=.*|use_xdg_open=$USE_XDG_OPEN_DEFAULT|" "$CFG_FILE"
    echo "Config updated successfully"
}

process_init_args() {
    if [ "$#" -eq 2 ]; then
        case $2 in
            "--flatpak")
                use_flatpak_defaults
                ;;
            "--snap")
                use_snap_defaults
                ;;
            *)
                invalid_arguments
                ;;
        esac
    elif [ $# -gt 2 ]; then
        invalid_arguments
    fi
}

validate_args_count() {
    if [ "$#" -ne $(($1 + 1)) ]; then
        invalid_arguments
    fi
}

if [ -n "${STEAM_LAUNCH_TEST+x}" ]; then
    CFG_DIR="$HOME/.config/steam-launch-test"
    ALIAS_FILE="$CFG_DIR/alias.json"
    CFG_FILE="$CFG_DIR/config.cfg"
fi

if [ $# -eq 0 ]; then
    invalid_arguments
fi

case "$1" in
    "--init")
        process_init_args "$@"
        init_cfg
        ;;
    "--alias")
        init_cfg_if_ne
        create_alias "$@"
        ;;
    "--rmalias")
        validate_args_count 2 "$@"
        cfg_dir_exists
        remove_alias_from_json "$2"
        ;;
    "--list")
        validate_args_count 1 "$@"
        cfg_dir_exists
        list_aliases
        ;;
    "--cfg")
        init_cfg_if_ne
        update_cfg "$@"
        ;;
    "--reset")
        process_init_args "$@"
        reset_cfg
        ;;
    "--reconf")
        process_init_args "$@"
        reconfigure
        ;;
    *)
        validate_args_count 1 "$@"
        cfg_dir_exists
        launch_app "$1"
        ;;
esac
