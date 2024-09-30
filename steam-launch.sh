#!/bin/bash

CFG_DIR="$HOME/.config/steam-launch"
ALIAS_FILE="$CFG_DIR/alias.json"
CFG_FILE="$CFG_DIR/config.cfg"
API_ENDPOINT="https://api.steampowered.com/ISteamApps/GetAppList/v2/"

set -e

create_cfg_dir() {
    echo "Initializing config directory at $CFG_DIR"
    mkdir -p "$CFG_DIR"
    touch $ALIAS_FILE
    echo "{}" > $ALIAS_FILE
    touch $CFG_FILE
    echo -e "steam_command=steam" >> $CFG_FILE
    echo -e "steamapps_path=~/.steam/steam/steamapps" >> $CFG_FILE
    echo -e "steam_args=\"\"" >> $CFG_FILE
    echo -e "redirect=\">/dev/null 2>&1 &\"" >> $CFG_FILE
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
    app_id=$(jq ".\"$1\"" "$ALIAS_FILE")
    if [ "$app_id" = "null" ]; then
        echo "Error: alias not found" >&2
        exit 1
    fi
    echo "Launching $1"
    eval "$steam_command $steam_args steam://rungameid/$app_id $redirect"
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
    tmp=$(mktemp)
    jq --arg key "$1" --arg value "$2" '.[$key] = ($value | tonumber)' \
        "$ALIAS_FILE" > "$tmp" && mv "$tmp" "$ALIAS_FILE"
    rm -f "$tmp"
    echo "Alias created successfully"
}

remove_alias_from_json() {
    alias=$(jq ".\"$1\"" "$ALIAS_FILE")
    if [ "$alias" = "null" ]; then
        echo "Error: alias not found" >&2
        exit 1
    fi
    tmp=$(mktemp)
    jq "del(.\"$1\")" "$ALIAS_FILE" > "$tmp" && mv "$tmp" "$ALIAS_FILE"
    rm -f "$tmp"
    echo "Alias removed"
}

get_id_from_api() {
    echo "Sending request to $API_ENDPOINT" > /dev/tty
    response=$(curl -s "$API_ENDPOINT")
    if [ -z "$response" ]; then
        echo "Error: request failed" >&2
        return 1
    fi
    echo "Parsing response" > /dev/tty
    game=$(echo "$response" | jq ".applist.apps[] | select(.name==\"$1\")")
    if [ -z "$game" ]; then
        echo "Error: no match for $1 found" >&2
        return 1
    fi
    appid=$(echo "$game" | jq '.appid')
    echo "$appid"
}

get_id_from_local_files() {
    source "$CFG_FILE"
    eval steamapps_path="$steamapps_path"
    app_id=$(find "$steamapps_path" -maxdepth 1 -type f -name '*.acf' \
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
    if [ -z "$app_id" ]; then
        echo "Error: no match for $1 found" >&2
        return 1
    fi
    echo $app_id
}

get_optional_alias_name() {
    if [ -z "$2" ]; then
        echo "$1"
    else
        echo "$2"
    fi
}

create_alias() {
    if [ "$#" -ne 3 ] && [ "$#" -ne 4 ]; then
        invalid_arguments
    fi

    case "$2" in
        "-a")
            app_id=$(get_id_from_api "$3")
            alias_name=$(get_optional_alias_name "$3" "$4")
            add_alias_to_json "$alias_name" $app_id
            ;;
        "-l")
            app_id=$(get_id_from_local_files "$3")
            alias_name=$(get_optional_alias_name "$3" "$4")
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
    case "$2" in
        "-steam")
            sed -i "s|^steam_command=.*|steam_command=\"$3\"|" "$CFG_FILE"
            ;;
        "-path")
            sed -i "s|^steamapps_path=.*|steamapps_path=\"$3\"|" "$CFG_FILE"
            ;;
        "-args")
            sed -i "s|^steam_args=.*|steam_args=\"$3\"|" "$CFG_FILE"
            ;;
        "-bg")
            set_background_mode $3
            ;;
        *)
            invalid_arguments
            ;;
    esac

    echo "Config updated successfully"
}

validate_args_count() {
    if [ "$#" -ne $(($1 + 1)) ]; then
        invalid_arguments
    fi
}

if [ $# -eq 0 ]; then
    invalid_arguments
fi

case "$1" in
    "--init")
        validate_args_count 1 "$@"
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
        validate_args_count 3 "$@"
        init_cfg_if_ne
        update_cfg "$@"
        ;;
    *)
        cfg_dir_exists
        launch_app "$1"
        ;;
esac