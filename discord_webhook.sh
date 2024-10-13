#!/usr/bin/env bash

# This script is used to send a message to a Discord channel using a webhook
# It can send a simple message or a file
# The script can be used in a script to send a message when a condition is met
# The script can be used in a cron job to send a message at a specific time

main() {
    local script_name=$0

    local dependencies=(
        "curl"
        "grep"
        "head"
        "cut"
        "sed"
    )
    if ! check_dependencies; then
        exit 1
    fi

    local -A options
    if ! parse_arguments "$@"; then
        exit 2
    fi

    if ! check_webhook; then
        exit 3
    fi

    if ! send_to_discord; then
        exit 4
    fi
    exit 0
}

check_dependencies() {
    for el in "${dependencies[@]}"; do
        if ! command -v "$el" &>/dev/null; then # command -v returns 0 if the command is found
            echo "$script_name - $el is needed to work" >&2
            return 1
        fi
    done
    return 0
}

parse_arguments() {
    # Check if no options are provided
    if [ $# -eq 0 ]; then
        echo "$script_name - No options provided" >&2
        show_usage
        return 1
    fi

    local ask_help=0

    while getopts ":w:u:m:t:d:a:c:f:h" opt; do
        case $opt in
        w)
            options["webhook_url"]="$OPTARG"
            ;;
        u)
            if ! validate_username "$OPTARG"; then
                return 2
            fi
            ;;
        m)
            if ! validate_message "$OPTARG"; then
                return 3
            fi
            ;;
        t)
            if ! validate_title "$OPTARG"; then
                return 4
            fi
            ;;
        d)
            if ! validate_description "$OPTARG"; then
                return 5
            fi
            ;;
        a)
            if ! validate_avatar "$OPTARG"; then
                return 6
            fi
            ;;
        c)
            if ! validate_color "$OPTARG"; then
                return 7
            fi
            ;;
        f)
            if ! validate_file "$OPTARG"; then
                return 8
            fi
            ;;
        h)
            ask_help=1
            break
            ;;
        \?)
            echo "$script_name - Invalid option: $OPTARG" >&2
            show_usage
            return 9
            ;;
        :)
            echo "$script_name - Option -$OPTARG requires an argument." >&2
            show_usage
            return 10
            ;;
        esac
    done

    # If -h is used, show the usage and exit
    if [ $ask_help -eq 1 ]; then
        show_usage
        exit 0
    fi

    # Check if minimum content is provided
    if ! has_content; then
        return 8
    fi

    # Set the webhook url
    if ! set_webhook; then
        return 9
    fi
    return 0
}

validate_username() {
    local username=$(escape_string "$1")
    local username_length=${#username}

    # Username must be between 1 and 80 characters
    if [ $username_length -lt 1 ] || [ $username_length -gt 80 ]; then
        echo "$script_name - Username must be between 1 and 80 characters" >&2
        return 1
    fi
    options["username"]="$username"
    return 0
}

validate_message() {
    local message=$(escape_string "$1")
    local message_length=${#message}

    # Message must be between 1 and 2000 characters
    if [ $message_length -lt 1 ] || [ $message_length -gt 2000 ]; then
        echo "$script_name - Message must be between 1 and 2000 characters" >&2
        return 1
    fi
    options["message"]="$message"
    return 0
}

validate_title() {
    local title=$(escape_string "$1")
    local title_length=${#title}

    # Title must be between 1 and 256 characters
    if [ $title_length -lt 1 ] || [ $title_length -gt 256 ]; then
        echo "$script_name - Title must be between 1 and 256 characters" >&2
        return 1
    fi
    options["title"]="$title"
    return 0
}

validate_description() {
    local description=$(escape_string "$1")
    local description_length=${#description}

    # Description must be between 1 and 4096 characters
    if [ $description_length -lt 1 ] || [ $description_length -gt 4096 ]; then
        echo "$script_name - Description must be between 1 and 4096 characters" >&2
        return 1
    fi
    options["description"]="$description"
    return 0
}

validate_avatar() {
    local avatar_url=$1

    # Check if the avatar url is valid
    if ! validate_url "$avatar_url"; then
        echo "$script_name - Invalid avatar url" >&2
        return 1
    fi
    options["avatar"]="$avatar_url"
    return 0
}

validate_url() {
    local url=$1
    local regex="^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$"

    # Use a basic regex to check if the url is valid
    if [[ ! "$url =~ $regex" ]]; then
        return 1
    fi
    return 0
}

validate_color() {
    local color=$1

    # If the color starts with a #, remove it
    if [[ "$color" == \#* ]]; then
        color=${color:1}
    fi

    # Check if the color is a valid hex color
    if [[ ! "$color" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "$script_name - Invalid color: $color" >&2
        return 1
    fi
    # Convert the hex color to decimal
    # It is required by Discord to send the color as a decimal...
    options["color"]=$(convert_to_decimal "$color")
    return 0
}

convert_to_decimal() {
    local hex=$1

    echo "$((16#$hex))"
}

validate_file() {
    local file_path=$1

    if [[ ! -e "$OPTARG" ]]; then # -e checks if the file exists
        echo "$script_name - The file does not exist" >&2
        return 2
    elif [[ -d "$OPTARG" ]]; then # -d checks if the file is a directory
        echo "$script_name - The file is not a regular file" >&2
        return 3
    elif [[ ! -s "$OPTARG" ]]; then # -s checks if the file is empty
        echo "$script_name - The file is empty" >&2
        return 4
    elif [[ ! -r "$OPTARG" ]]; then # -r checks if the file is readable
        echo "$script_name - You are not authorized to read the file" >&2
        return 5
    fi
    options["file_path"]="$file_path"
    return 0
}

has_content() {
    # Check if at least one of the following options is provided
    # They are options who contain the minimum to send a message
    if [[ -z ${options["message"]} && -z ${options["title"]} && -z ${options["description"]} && -z ${options['file_path']} ]]; then
        echo "$script_name - You must specify at least -m, -t, -d or -f" >&2
        return 1
    fi
    return 0
}

escape_string() {
    local string="$1"

    # Escape \n
    string=$(echo "$string" | sed ':a;N;$!ba;s/\n/\\n/g')
    # Escape every \ except \n, \t and \r
    string=$(echo "$string" | sed -E 's/\\([^ntr])|\\$/\\\\\1/g')
    # Escape double quotes
    string=$(echo -n "$string" | sed 's/"/\\"/g')
    # Escape single quotes
    string=$(echo "$string" | sed "s/'/'\\\''/g")

    echo "$string"
}

show_usage() {
    echo "Usage: $script_name [OPTIONS]"
    echo ""
    echo "Options:"
    echo -e "  -w <webhook_url> OR <path/to/file>"
    echo -e "  -u <username>"
    echo -e "  -m <message>"
    echo -e "  -t <title>"
    echo -e "  -d <description>"
    echo -e "  -a <avatar_url>"
    echo -e "  -c <#color_hex>"
    echo -e "  -f <path/to/file>"
    echo -e "  -h"
    echo ""
    echo "Notes:"
    echo -e "  - The -w option can be used to specify the webhook url directly or via a file."
    echo -e "  - If the -w option is not specified, the script will read the webhook url from"
    echo -e "    \$HOME/.discord_webhook or the DISCORD_WEBHOOK_URL environment variable."
    echo -e "  - You must specify at least -m, -t or -d"
    echo -e "  - If -f is used, -m, -t and -d will be ignored."
}

set_webhook() {
    local webhook_url=${options["webhook_url"]}

    # Check if the webhook url is provided via a file
    if [[ -f "$webhook_url" && -r "$webhook_url" ]]; then
        # Read the webhook url from the file
        options["webhook_url"]=$(cat "$webhook_url")
        return 0
    elif [ -z "$webhook_url" ]; then
        # Check if the webhook url is provided in the home directory in the .discord_webhook file
        if [[ -f "$HOME/.discord_webhook" && -r "$HOME/.discord_webhook" ]]; then
            options["webhook_url"]=$(cat "$HOME/.discord_webhook")
            return 0
        elif [ -n "$DISCORD_WEBHOOK_URL" ]; then # Check if the webhook url is provided via an environment variable
            options["webhook_url"]="$DISCORD_WEBHOOK_URL"
            return 0
        else # No webhook url provided
            echo "$script_name - No webhook url provided" >&2
            show_usage
            return 1
        fi
    fi
    return 0
}

check_webhook() {
    local webhook_url=${options["webhook_url"]}

    # Pre check if the webhook is a valid discord url
    if [[ ! "$webhook_url" =~ ^https://discord.com/api/webhooks/[0-9]+/[a-zA-Z0-9_\-]+$ ]]; then
        echo "$script_name - Invalid webhook url" >&2
        return 1
    fi

    # Send a Head request to check if the webhook is valid
    local http_response=$(curl -s -I -o /dev/null -w "%{http_code}" "$webhook_url")
    # If the response is not 200, the webhook is invalid
    if [ "$http_response" -ne 200 ]; then
        echo "$script_name - Invalid webhook url" >&2
        return 2
    fi
    return 0
}

send_to_discord() {
    local webhook_url=${options["webhook_url"]}
    local curl_params="-s -D - "
    local request

    # If a file is provided, prepare the request for file content
    if [ -n "${options["file_path"]}" ]; then
        make_request_file
    else # else prepare the request for text content
        make_request_text
    fi

    # Add the request to the curl parameters
    curl_params+="$request"

    if ! send_request; then
        return 2
    fi
    return 0
}

make_request_file() {
    local file_path=${options["file_path"]}
    # The file is sent as a multipart/form-data
    local request_header="Content-Type: multipart/form-data"
    # The file is sent as a form field named "file"
    local request_body="-F \"file=@$file_path\""

    # Forge the request
    request="$request_header $request_body"
}

make_request_text() {
    # The request is sent as a JSON object
    local request_header="-H \"Content-Type: application/json\""
    # Create the request body with the beginning of the JSON object
    local request_body="-d '{"

    # Controle variables
    local in_embed=0
    local has_content=0

    if [ -n "${options["message"]}" ]; then
        local message="${options["message"]}"

        inject_content
        request_body+="\"content\": \"$message\""
    fi

    if [ -n "${options["username"]}" ]; then
        local username=${options["username"]}

        inject_content
        request_body+="\"username\": \"$username\""
    fi

    if [ -n "${options["avatar"]}" ]; then
        local avatar=${options["avatar"]}

        inject_content
        request_body+="\"avatar_url\": \"$avatar\""
    fi

    if [ -n "${options["title"]}" ]; then
        local title="${options["title"]}"

        inject_embeds
        request_body+="\"title\": \"$title\""
    fi

    if [ -n "${options["description"]}" ]; then
        local description="${options["description"]}"

        inject_embeds
        request_body+="\"description\": \"$description\""
    fi

    # If the color option is provided and the embed is open id it to the request
    if [[ -n "${options["color"]}" && in_embed -eq 1 ]]; then
        local color="${options["color"]}"

        request_body+=",\"color\": \"$color\""
    fi

    # If the embed is open, close it
    if [ $in_embed -eq 1 ]; then
        request_body+="}]"
    fi

    # Close the JSON object
    request_body+="}'"

    # Forge the request
    request="$request_header $request_body"
}

# This function is used to inject a comma if the content is not the first one
inject_content() {
    if [ $has_content -eq 1 ]; then
        request_body+=","
    fi
    has_content=1
}

# This function is used to inject the embeds array if it is not open
# It can add the coma if the content of the embed is not the first one
inject_embeds() {
    if [ $in_embed -eq 0 ]; then
        if [ $has_content -eq 1 ]; then
            request_body+=","
        fi
        request_body+="\"embeds\": [{"
        in_embed=1
    else
        request_body+=","
    fi
}

send_request() {
    # Send the request to the webhook url
    local response=$(eval curl $curl_params $webhook_url)
    # Get the HTTP code from the response
    local http_code=$(echo "$response" | grep HTTP | head -n 1 | cut -d " " -f2)

    # If the HTTP code is not 2xx, the request failed
    if [[ ! $http_code =~ ^2[0-9]{2}$ ]]; then
        echo "$script_name - Request failed with response: $http_code" >&2
        return 1
    fi
    return 0
}

main "$@"
