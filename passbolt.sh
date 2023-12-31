#!/bin/bash

# Script to make Passbolt CLI more user friendly.
# Copyright (C) 2023  Twilight Sparkle
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

dumb="Due to the really dumb way passbolt-cli returns the list of your
credentials, you must create an entry in your Passbolt with any string of
exactly 200 characters in the name, username, and URL field 🤦‍♀️"

# Print script help
printHelp() {
    cat <<EOF
Simple helper script to make Passbolt CLI a bit more usable.

$dumb

Usage: ./passbolt.sh [options] [search] [index]

Options:
    -c, --copy          Copy username, password, and current 2FA code to the
                        system clipboard.
    -d, --description   Print the description to the console.
    -h, --help          This help text.
    -p, --password      Print the password to the console.
        --totp          Print all TOTP details.
        --verbose       Show verbose debug information. Printed to STDERR.

search: Search for something in Passbolt. Optional, script will ask you
        if not set.
index:  If your search returns more than one result, and index is not
        set, you will be presented a list to choose an entry from.
        Set index to pre-select the result from the list.

Settings. Export environment variable with the value \"true\"
(including quotes) to enable the option. When one of these is set, they negate
the related option if set.
    - PASSBOLT_CLI_HELPER_COPY:         Automatically copy the username and
                                        password to system clipboard.
    - PASSBOLT_CLI_HELPER_CLEAR_CLIP:   Automatically clear the password or TOTP
                                        from the system clipboard after N
                                        seconds if the clipboard has not since
                                        been changed by the user. Default 10.
                                        Set to 0 to disable.
                                        Only works on Mac for now.
    - PASSBOLT_CLI_HELPER_SHOW_DESC:    Print the description by default.
    - PASSBOLT_CLI_HELPER_SHOW_PW:      Print the password by default.
    - PASSBOLT_CLI_HELPER_SHOW_TOTP:    Print all TOTP details by default.
EOF
}

# Parse command line parameters
while [ "$#" -gt 0 ]; do
    case $1 in
        # options
        -h | --help)        printHelp;                                  exit 0  ;;
        -c | --copy)        export OPTION_PB_HELPER_COPY="true";        shift   ;;
        -d | --description) export OPTION_PB_HELPER_DESC="true";        shift   ;;
        -p | --password)    export OPTION_PB_HELPER_PASSWORD="true";    shift   ;;
             --totp)        export OPTION_PB_HELPER_SHOW_TOTP="true";   shift   ;;
             --verbose)     export OPTION_PB_HELPER_VERBOSE="true";     shift   ;;
        # :cry:, but don't want any libraries or dependencies for this
        -cd)  export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true";                                          shift ;;
        -cp)  export OPTION_PB_HELPER_COPY="true";                                      export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -cdp) export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -cpd) export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -dc)  export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true";                                          shift ;;
        -dp)                                       export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -dcp) export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -dpc) export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -pc)  export OPTION_PB_HELPER_COPY="true";                                      export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -pd)                                       export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -pcd) export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        -pdc) export OPTION_PB_HELPER_COPY="true"; export OPTION_PB_HELPER_DESC="true"; export OPTION_PB_HELPER_PASSWORD="true"; shift ;;
        # Catch all invalid options
        -*)                 echo "Unknown option $1.";                  exit 1  ;;
        # Save positional arguments
        *)                  POSITIONAL_ARGS+=("$1");                    shift   ;;
    esac
done
# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

# Print a header for debug information
# Params:
# 1: Header name
printDebugHeader() {
    if [ "$OPTION_PB_HELPER_VERBOSE" == "true" ]; then
        local header
        header="$1"
        >&2 echo -e "\n-------------------Debug info for $header-------------------"
    fi
}

# Print a variable as a debug line or debug header
# Params:
# 1: The variable name to print without $
printDebugVar() {
    if [ "$OPTION_PB_HELPER_VERBOSE" == "true" ]; then
        local dots
        local length
        local numDots
        local var

        var="$1"
        length="${#var}"
        numDots="$((40-length))"
        dots=""
        for (( i=0; i<="$numDots"; ++i)); do dots+="."; done
        >&2 echo "DEBUG: \$$var$dots${!var}.........."
    fi
}

# Ask for a search if not set on the command line
searchPhrase="$1"
if [ -z "$searchPhrase" ]; then
    read -rp "Search: " searchPhrase
fi

# Set index if provided
multiIndex="$2"

# Check what OS the system is running.
# Returns String. One of Darwin, LinuxWayland, or LinuxX11. Or Number 1 if unable to detect
checkOs() {
    local unameRes
    unameRes="$(uname)"
    printDebugHeader "function checkOs"
    printDebugVar "unameRes"
    
    case "$unameRes" in
        Darwin)
            echo "Darwin";;
        Linux)
            local windowManager
            # shellcheck disable=SC2046
            windowManager="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"
            printDebugVar "windowManager"
            if echo "$windowManager" | grep wayland 2>/dev/null; then
                echo "LinuxWayland"
            else
                echo "LinuxX11"
            fi;;
        *)
            echo 1
    esac
}

# Check if the given value is an integer
# Params:
# 1: The value to check
# Returns 1 if true or 0 if false
isInteger() {
    local input
    input="$1"

    printDebugHeader "function isInteger"
    printDebugVar "input"

    if [ -n "$input" ] && [ "$input" -eq "$input" ] 2>/dev/null; then
        echo 1
    else
        echo 0
    fi
}

# Defaults
COPY_USER_PASS="false"
SHOW_DESCRIPTION="false"
SHOW_PASSWORD="false"

[ -z "$PASSBOLT_CLI_HELPER_CLEAR_CLIP" ] && PASSBOLT_CLI_HELPER_CLEAR_CLIP=10
if [ "$(isInteger "$PASSBOLT_CLI_HELPER_CLEAR_CLIP")" == 0 ] || [ "$PASSBOLT_CLI_HELPER_CLEAR_CLIP" -lt 0 ]; then
    echo "Error. PASSBOLT_CLI_HELPER_CLEAR_CLIP must be an integer 0 or greater"
    exit 1
fi

# Negation. I'm sure there is a more elegant way of doing this, but :shrug:
if [ "$PASSBOLT_CLI_HELPER_COPY" == "true" ]        && [ -z "$OPTION_PB_HELPER_COPY" ];             then COPY_USER_PASS="true"; fi
if [ "$PASSBOLT_CLI_HELPER_SHOW_DESC" == "true" ]   && [ -z "$OPTION_PB_HELPER_DESC" ];             then SHOW_DESCRIPTION="true"; fi
if [ "$PASSBOLT_CLI_HELPER_SHOW_PW" == "true" ]     && [ -z "$OPTION_PB_HELPER_PASSWORD" ];         then SHOW_PASSWORD="true"; fi
if [ "$PASSBOLT_CLI_HELPER_SHOW_TOTP" == "true" ]   && [ -z "$OPTION_PB_HELPER_SHOW_TOTP" ];        then SHOW_USER_TOTP="true"; fi

if [ "$PASSBOLT_CLI_HELPER_COPY" == "true" ]        && [ "$OPTION_PB_HELPER_COPY" == "true" ];      then COPY_USER_PASS="false"; fi
if [ "$PASSBOLT_CLI_HELPER_SHOW_DESC" == "true" ]   && [ "$OPTION_PB_HELPER_DESC" == "true" ];      then SHOW_DESCRIPTION="false"; fi
if [ "$PASSBOLT_CLI_HELPER_SHOW_PW" == "true" ]     && [ "$OPTION_PB_HELPER_PASSWORD" == "true" ];  then SHOW_PASSWORD="false"; fi
if [ "$PASSBOLT_CLI_HELPER_SHOW_TOTP" == "true" ]   && [ "$OPTION_PB_HELPER_SHOW_TOTP" == "true" ]; then SHOW_USER_TOTP="false"; fi

if [ ! "$PASSBOLT_CLI_HELPER_COPY" == "true" ]      && [ -z "$OPTION_PB_HELPER_COPY" ];             then COPY_USER_PASS="false"; fi
if [ ! "$PASSBOLT_CLI_HELPER_SHOW_DESC" == "true" ] && [ -z "$OPTION_PB_HELPER_DESC" ];             then SHOW_DESCRIPTION="false"; fi
if [ ! "$PASSBOLT_CLI_HELPER_SHOW_PW" == "true" ]   && [ -z "$OPTION_PB_HELPER_PASSWORD" ];         then SHOW_PASSWORD="false"; fi
if [ ! "$PASSBOLT_CLI_HELPER_SHOW_TOTP" == "true" ] && [ -z "$OPTION_PB_HELPER_SHOW_TOTP" ];        then SHOW_USER_TOTP="false"; fi

if [ ! "$PASSBOLT_CLI_HELPER_COPY" == "true" ]      && [ "$OPTION_PB_HELPER_COPY" == "true" ];      then COPY_USER_PASS="true"; fi
if [ ! "$PASSBOLT_CLI_HELPER_SHOW_DESC" == "true" ] && [ "$OPTION_PB_HELPER_DESC" == "true" ];      then SHOW_DESCRIPTION="true"; fi
if [ ! "$PASSBOLT_CLI_HELPER_SHOW_PW" == "true" ]   && [ "$OPTION_PB_HELPER_PASSWORD" == "true" ];  then SHOW_PASSWORD="true"; fi
if [ ! "$PASSBOLT_CLI_HELPER_SHOW_TOTP" == "true" ] && [ "$OPTION_PB_HELPER_SHOW_TOTP" == "true" ]; then SHOW_USER_TOTP="true"; fi

# Check if able to determine OS
if [ "$COPY_USER_PASS" == "true" ]; then
    operatingSystem="$(checkOs)"
    if [ "$operatingSystem" == 1 ]; then
        echo "Unable to detect operating system. Update the script or disable copy to clipboard";
        exit 1
    fi
fi

# Print debug vars
printDebugHeader "input variables and settings"
debugVars=(searchPhrase multiIndex operatingSystem COPY_USER_PASS SHOW_USER_TOTP OPTION_PB_HELPER_COPY
    OPTION_PB_HELPER_DESC OPTION_PB_HELPER_PASSWORD PASSBOLT_CLI_HELPER_SHOW_TOTP PASSBOLT_CLI_HELPER_CLEAR_CLIP
    PASSBOLT_CLI_HELPER_COPY PASSBOLT_CLI_HELPER_SHOW_DESC PASSBOLT_CLI_HELPER_SHOW_PW PASSBOLT_CLI_HELPER_SHOW_TOTP
    SHOW_DESCRIPTION SHOW_PASSWORD)
for v in "${debugVars[@]}"; do printDebugVar "$v" ; done

# Make sure required programs are installed
checkRequiredPrograms() {
    local program
    local programs
    local missing

    programs=(bash echo gpg grep jq oathtool passbolt read sed xargs)

    if [ "$COPY_USER_PASS" == "true" ]; then
        case "$operatingSystem" in
            Darwin)         programs+=(pbcopy pbpaste);;
            LinuxWayland)   programs+=(wl-copy);;
            LinuxX11)       programs+=(xclip);;
        esac
    fi

    missing=""
    for program in "${programs[@]}"; do
        if ! hash "$program" &>/dev/null; then
            missing+="\n- $program "
        fi
    done

    printDebugHeader "function checkRequiredPrograms"
    printDebugVar "programs[*]"
    printDebugVar "missing"

    if [ -n "$missing" ]; then
        echo -e "Some required programs are missing on this system. Please install:$missing"
        exit 1
    fi
}

checkRequiredPrograms

# Make a word plural by appending s if a number other than 1 is provided
# Params:
# 1: A string in singular
# 2: How many?
# Returns: The work in singular or plural
plural() {
    local string
    local count

    string="$1"
    count="$2"

    [ "$count" != "1" ] && string+="s"
    echo "$string"
}

# Copy a string to the system clipboard
# Params:
# 1: The string to copy
copy() {
    local string
    string="$1"

    printDebugHeader "function copy"
    printDebugVar "string"

    case $operatingSystem in
        Darwin)         echo "$string" | tr -d '\n' | pbcopy;;
        LinuxWayland)   wl-copy "$string";;
        LinuxX11)       xclip -i -selection clipboard -t "$string";;
        *)
            echo "Unable to copy to system clipboard."
            return 1
    esac
}

# Read the system clipboard
# Returns: String from clipboard
readClipboard() {
    local clipContent

    printDebugHeader "function readClipboard"

    case $operatingSystem in
        Darwin)         clipContent="$(pbpaste)";;
        # TODO add support for Linux
        # LinuxWayland)   wl-copy "$string";;
        # LinuxX11)       xclip -i -selection clipboard -t "$string";;
        *)
            echo "Unable to read system clipboard."
            return 1
    esac

    printDebugVar "clipContent"
    echo "$clipContent"
}

# Takes one line returned from passbolt find, parses it, and returns it as a usable string
# Params:
# 1: The line from Passbolt
# 2: Format to return the string in
#   all:    name;username;uri;modified;uuid
#   short:  name, username. If URL is set, append (url)
# Returns:  Formatted string
splitLine() {
    local debugVars
    local input
    local resultMode
    local string
    local inputName
    local username
    local uri
    local modified
    local uuid
    input="$1"

    resultMode="$2"
    inputName="$(echo "${input:0:200}" | xargs)"
    username="$(echo "${input:201:64}" | xargs)"
    uri="$(echo "${input:266:200}" | xargs)"
    modified="$(echo "${input:467:25}" | xargs)"
    uuid="$(echo "${input:493:36}" | xargs)"

    printDebugHeader "function splitLine"
    debugVars=(input resultMode inputName username uri modified uuid)
    for v in "${debugVars[@]}"; do printDebugVar "$v"; done

    case $resultMode in
        all)    echo "$inputName;$username;$uri;$modified;$uuid";;
        short)
                string="$inputName, $username"
                [ -n "$uri" ] && string+=" ($uri)"
                printDebugVar "string"
                echo "$string";;
        *)
                echo "Invalid result mode $resultMode. Must be one of all|short"
                exit 1;;
    esac
}

# Clear the clipboard after the configured time, if enabled. Clipboard will only be cleared if the content was not
# changed by the user during the wait.
# Params:
# 1: The password that was copied earlier. 
clearClipboard() {
    local compareTo
    local clipContent
    compareTo="$1"

    printDebugHeader "function clearClipboard"
    printDebugVar "PASSBOLT_CLI_HELPER_CLEAR_CLIP"
    printDebugVar "compareTo"

    if [ "$PASSBOLT_CLI_HELPER_CLEAR_CLIP" -gt 0 ]; then
        echo "Waiting $PASSBOLT_CLI_HELPER_CLEAR_CLIP seconds to clear the system clipboard..."
        sleep "$PASSBOLT_CLI_HELPER_CLEAR_CLIP"
        clipContent="$(readClipboard)"
    
        printDebugHeader "function clearClipboard"
        printDebugVar "clipContent"

        if [ "$clipContent" == "$compareTo" ]; then
            copy ""
        fi
    fi
}

# Get the number of seconds remaining for 30-second TOTP
# Returns: Seconds remaining
totpSecondsRemaining() {
    local remaining
    local seconds

    seconds="$(date "+%S")"
    if [ "$seconds" -lt 30 ]; then
        remaining="$((30 - seconds))"
    else
        remaining="$((60 - seconds))"
    fi

    printDebugHeader "function totpSecondsRemaining"
    printDebugVar "remaining"
    printDebugVar "seconds"

    echo "$remaining"
}

# Copy TOTP code to the system clipboard. If less than 10 seconds remaining on the code, copy the next code when it's
# time. Clears system the clipboard at the end
# Params:
# 1: Array of TOTP codes
copyTotp() {
    local remaining
    local totpCodesArr
    local totpIndex

    totpCodesArr=("$@")

    totpIndex=0
    copy "${totpCodesArr[totpIndex]}"
    remaining="$(totpSecondsRemaining)"
    echo "The TOTP code has been copied to your clipboard. $remaining $(plural "second" "$remaining") remaining"

    printDebugHeader "function copyTotp"
    printDebugVar "remaining"
    printDebugVar "totpCodesArr[*]"
    printDebugVar "totpIndex"

    if [ "$remaining" -lt 10 ]; then
        ((totpIndex++))
        ((varemainingr++))
        printDebugVar "totpIndex"
        printDebugVar "remaining"
        sleep "$remaining"
        copy "${totpCodesArr[totpIndex]}"
        echo "Updated TOTP code has been copied to your clipboard"
    fi
    clearClipboard "${totpCodesArr[totpIndex]}"
}

# Get the encrypted password + description from Passbolt, then print it and/or copy to clipboard
# Params:
# 1: One line from passbolt find
printEntry() {
    local baseUrl
    local debugVars
    local decrypted
    local description
    local descriptionStr
    local encrypted
    local entryName
    local modified
    local password
    local passwordStr
    local remaining
    local seconds
    local split
    local printString
    local totpAlgorithm
    local totpCodes
    local totpCodesArr
    local totpDetails
    local totpDigits
    local totpLine
    local totpPeriod
    local totpSecretKey
    local uri
    local username
    local uuid

    split="$(splitLine "$1" "all")"

    # Get the line as individual variables
    SAVEIFS="$IFS"
    IFS=';' read -r entryName username uri modified uuid <<< "$split"
    IFS="$SAVEIFS"

    # Extract individual pieces of information
    encrypted="$(passbolt get "$uuid")"
    decrypted="$(echo "$encrypted" | gpg --quiet --no-tty 2>/dev/null | sed 's#\n#\\n#g')"
    password="$(echo "$decrypted" | jq --raw-output .password 2>/dev/null)"
    totpAlgorithm="$(echo "$decrypted" | jq --raw-output .totp.algorithm 2>/dev/null)"
    totpDigits="$(echo "$decrypted" | jq --raw-output .totp.digits 2>/dev/null)"
    totpPeriod="$(echo "$decrypted" | jq --raw-output .totp.period 2>/dev/null)"
    totpPeriod+="s"
    totpSecretKey="$(echo "$decrypted" | jq --raw-output .totp.secret_key 2>/dev/null)"
    baseUrl="$(jq --raw-output .domain.baseUrl "$HOME/.config/passbolt/config.json")"

    # If the entry does not have a description, the encrypted data is not JSON. It just encrypts the password as a
    # simple string. This check should (tm) always work because Passbolt does not allow adding an entry without entering
    # something in the password field
    if [ "${#password}" == 0 ]; then
        password="$decrypted"
    else
        description="$(echo "$decrypted" | jq --raw-output .description)"
    fi

    totpLine=""
    if [ "$totpSecretKey" != "null" ]; then
        remaining="$(totpSecondsRemaining)"
        totpCodes="$(
            oathtool \
                --base32 \
                --digits="$totpDigits" \
                --time-step-size="$totpPeriod" \
                --totp="$totpAlgorithm" \
                --window="3" \
                "$totpSecretKey"
        )"

        # Convert the 4 returned codes to an array
        SAVEIFS="$IFS"
        # shellcheck disable=SC2206
        IFS=$'\n' totpCodesArr=($totpCodes)
        IFS="$SAVEIFS"

        totpLine="\nNext 4 TOTP codes:  ${totpCodesArr[*]} - $remaining $(plural "second" "$remaining") remaining"

        if [ "$SHOW_USER_TOTP" == "true" ]; then
            totpDetails="
TOTP Algorithm:     $totpAlgorithm
TOTP Digits:        $totpDigits
TOTP Period:        $totpPeriod
TOTP Secret Key:    $totpSecretKey"
        fi
    fi

    passwordStr="<hidden>"
    descriptionStr="<hidden>"
    [ "$SHOW_PASSWORD" == "true" ] && passwordStr="$password"
    [ "$SHOW_DESCRIPTION" == "true" ] && descriptionStr="\n$description"

    printDebugHeader "function printEntry"
    debugVars=(baseUrl decrypted description descriptionStr encrypted entryName modified password passwordStr
        remaining seconds split totpAlgorithm totpCodes totpCodesArr[*] totpDetails totpDigits totpIndex totpLine
        totpPeriod totpSecretKey uri username uuid)
    for v in "${debugVars[@]}"; do printDebugVar "$v"; done

    # $totpDetails and $totpLine are set to an enpty strings by default, and \n<content> if they are used. So they will
    # be on their own lines if used or not dispayed if not used. This approach removes the need for a bunch of logic
    # building the output
    echo -e "
Details for entry   $entryName
Username:           $username
Password:           $passwordStr$totpDetails$totpLine
URL:                $uri
Last modified:      $modified
Passbolt link:      $baseUrl/app/passwords/view/$uuid
Description:        $descriptionStr"

    if [ "$COPY_USER_PASS" == "true" ]; then
        if [ -n "$username" ]; then
            copy "$username"
            read -rp "The username has been copied to your clipboard. Press enter to copy the password"
        fi

        copy "$password"
        printString="The password has been copied to your clipboard"

        if [ -n "$totpLine" ]; then
            printString+=". Press enter to copy the TOTP"
            read -rp "$printString"
            copyTotp "${totpCodesArr[@]}"
        else
            echo "$printString"
            clearClipboard "$password"
        fi
    fi
}

# Get all passwords from Passbolt and select one of them to process further
getPassword() {
    local allEntries
    local chosenEntry
    local counter
    local searchResult
    local split
    local resultCount

    # Log in to passbolt
    if ! passbolt auth check | grep "You are already logged in." &>/dev/null; then
        while true; do
            if passbolt auth login; then
                break
            else
                passbolt auth logout 1>/dev/null
            fi
        done
    fi

    # Fetch all entries from Passbolt. passbolt-cli does not have any native filter/search function
    allEntries="$(passbolt find)"

    # Do the search and convert the result list to an array
    SAVEIFS="$IFS"
    # shellcheck disable=SC2207
    IFS=$'\n' searchResult=($(echo "$allEntries" | grep -i "$searchPhrase"))
    IFS="$SAVEIFS"

    # Count results
    resultCount=${#searchResult[@]}

    # Check that the user has the 200 string entry requirement
    if [ "$resultCount" -gt 0 ] && [ ${#searchResult[0]} != 529 ]; then
        echo "Error: $dumb"
        exit 1
    fi

    case "$resultCount" in
        0)
            echo "No entries found for $searchPhrase. If you believe this is"
            echo "    wrong, try \"passbolt auth logout\", then rerun the search"
            exit 1;;
        1)
            printEntry "${searchResult[0]}";;
        *)
            # Skip the choice if a number was pre selected from the command line
            if [ -n "$multiIndex" ]; then
                chosenEntry="$multiIndex"
            else
                # List all results
                counter=1
                for i in "${searchResult[@]}"; do
                    splitLine "$counter: $i" "short"
                    ((counter++))
                done
                # Keep asking the user for a selection until a valid integer is entered
                while
                    read -rp "Choose entry number: " chosenEntry
                    [[
                        -z "$chosenEntry" ||                        # Empty
                        "$chosenEntry" == *[^0-9]* ||               # Not an integer
                        "$chosenEntry" -lt 1 ||                     # Lower than 1
                        "$chosenEntry" -gt "${#searchResult[@]}"    # Greater than the number of results
                    ]];
                do
                    true
                done
            fi

            # Process and print the chosen entry
            ((chosenEntry--))
            printEntry "${searchResult[$chosenEntry]}"
            ;;
    esac
}

getPassword
