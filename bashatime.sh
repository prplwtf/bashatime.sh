#!/bin/bash

# bashatime by Emma (prpl.wtf)
# MIT License
BASHATIME_VERSION="1.1"

# shellcheck disable=SC1091
source .bashatimerc 2>/dev/null

if [[ "$OSTYPE" == "darwin"* ]]; then
    alias md5sum=md5
fi

get_hash() {
    git ls-files --others --exclude-standard --cached -z | xargs -0 md5sum | sort | md5sum
}

printout() {
    case "$1" in
    log)
        echo -e "\e[30;42;1m bashatime.sh \e[0;30;47m $(date +"%H:%M:%S") \e[0m $2"
        ;;
    error)
        echo -e "\e[30;41;1m bashatime.sh \e[0;30;47m $(date +"%H:%M:%S") \e[0m $2"
        ;;
    today)
        echo -e "\e[30;42;1m bashatime.sh \e[0;30;47m $(date +"%H:%M:%S") \e[0m $2 \e[0;35;49;1m\e[30;45;1m$(wakatime-cli --today --today-hide-categories true)\e[0;35;49;1m\e[0m"
        ;;
    verbose)
        if [[ $LOG_VERBOSE == 1 ]]; then
            echo -e "\e[30;42;1m bashatime.sh \e[0;30;47m $(date +"%H:%M:%S") \e[0m $2"
        fi
        ;;
    esac
}

# alias wakatime-cli to wakatime if wakatime is installed
if [ -x "$(command -v wakatime)" ]; then
    alias wakatime-cli=wakatime
fi

# dependency checks
check_dependency() {
    if ! [ -x "$(command -v "$1")" ]; then
        printout error "dependency '$1' is missing from \$PATH (are you sure that it's installed?)"
        exit 202
    fi
}
check_dependency diff
check_dependency git
check_dependency sed
check_dependency fswatch
check_dependency wakatime-cli
check_dependency md5sum
check_dependency xargs
check_dependency sort

# bashatime requires git ls-files
if ! git status &>/dev/null; then
    printout error "directory is not a git repository"
    exit 254
fi

# make cache directory
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/bashatime/$RANDOM"
mkdir -p "$cache_dir"
printout verbose "bashatime cache directory is $cache_dir"

get_cache_path() {
    local filepath="$1"
    local hash
    hash=$(echo "$filepath" | md5sum | cut -d' ' -f1)
    echo "$cache_dir/$hash"
}

get_changed_line() {
    local filepath="$1"
    local cache_path
    cache_path=$(get_cache_path "$filepath")

    if [[ ! -f "$cache_path" ]]; then
        # no cache, assume middle of file
        echo $(($(wc -l <"$filepath") / 2))
        return
    fi

    # get first changed line from diff
    local line
    line=$(diff -U0 "$cache_path" "$filepath" 2>/dev/null | grep -m1 "^@@" | sed -n 's/@@ -[0-9,]* +\([0-9]*\).*/\1/p')

    if [[ -z "$line" ]]; then
        # diff failed or no changes, use middle
        echo $(($(wc -l <"$filepath") / 2))
    else
        echo "$line"
    fi
}

get_cursor_pos() {
    local filepath="$1"
    local lineno="$2"

    # get length of the changed line
    local line_content
    line_content=$(sed -n "${lineno}p" "$filepath")
    local line_length="${#line_content}"

    if [[ $line_length -eq 0 ]]; then
        echo 0
    else
        echo "$line_length"
    fi
}

if [[ $PROJECT_NAME == "" ]]; then
    PROJECT_NAME=${PWD##*/}
    PROJECT_NAME=${PROJECT_NAME:-/}
fi

echo -e ""
echo -e "" \
    "\e[32;1m▟▉▙▝▙▝▙ \e[0;30;42;1m bashatime.sh \e[0;32;1m $BASHATIME_VERSION\e[0m \n" \
    "\e[32;1m▜▉▛▗▛▗▛ \e[0;2m© 2025 Emma (prpl.wtf)\e[0m \n"

# shellcheck disable=SC2329
cleanup() {
    echo ""
    printout log "cleaning up.."
    if [[ -d "$cache_dir" ]]; then
        rm -r "$cache_dir"
    fi

    exit
}
trap cleanup SIGINT SIGTERM

last_hash=$(get_hash)
printout verbose "initial hash: $last_hash"

should_heartbeat=false
printout verbose "initialized: should_heartbeat=$should_heartbeat"

printout log "bashatime is ready! tracking project $PROJECT_NAME"
while true; do
    printout verbose "waiting for changes..."
    output="$(fswatch -1 -r -x --event Updated --event Created --event Removed --event Renamed . | head -n1)"
    # shellcheck disable=SC2181
    if [[ $? == "0" ]]; then
        printout verbose "fswatch triggered: $output"

        if [[ "$output" =~ ^(.*)[[:space:]]([A-Z][a-z]+)$ ]]; then
            filepath="${BASH_REMATCH[1]}"
            action="${BASH_REMATCH[2]}"
            dir="${filepath%/*}/"
            filename="${filepath##*/}"
            printout verbose "parsed: dir=$dir, action=$action, filename=$filename, filepath=$filepath"

            if [[ -f "$filepath" ]]; then
                # only track if file is actually in git
                if git ls-files --others --exclude-standard --cached --error-unmatch "$filepath" &>/dev/null; then
                    printout verbose "file is tracked by git"
                    should_heartbeat=true
                    printout verbose "should_heartbeat set to true"
                else
                    printout verbose "file not tracked by git, ignoring"
                    should_heartbeat=false
                    printout verbose "should_heartbeat set to false"
                fi
            else
                printout verbose "file does not exist, ignoring"
                should_heartbeat=false
                printout verbose "should_heartbeat set to false"
            fi
        else
            printout verbose "regex didn't match output"
            should_heartbeat=false
            printout verbose "should_heartbeat set to false"
        fi
    fi

    current_time=$(date +%s)
    printout verbose "checking heartbeat: should_heartbeat=$should_heartbeat, current_time=$current_time"

    if [[ ($should_heartbeat == true) && (-f "$filepath") ]]; then
        printout verbose "heartbeat conditions met, checking hash..."
        current_hash=$(get_hash)
        printout verbose "current hash: $current_hash"
        printout verbose "last hash: $last_hash"

        if [ "$last_hash" != "$current_hash" ]; then
            printout verbose "hash changed, sending to wakatime: $filepath"

            if [[ $action == "Updated" ]]; then
                printout verbose "file action 'Updated'. calculating lineno, cursorpos, linestotal"
                lineno=$(get_changed_line "$filepath")
                cursorpos=$(get_cursor_pos "$filepath" "$lineno")
                linestotal=$(wc -l <"$filepath")
            else
                printout verbose "file action is NOT 'Updated'. setting lineno to 1, cursorpos to 1, linestotal to 1"
                lineno=1
                cursorpos=1
                linestotal=1
            fi
            printout verbose "lineno is $lineno, cursorpos is $cursorpos, linestotal is $linestotal"

            wakatime-cli \
                --time "$current_time" \
                --write true \
                --entity "$filepath" \
                --plugin "bashatime.sh/$BASHATIME_VERSION" \
                --lines-in-file "$linestotal" \
                --lineno "$lineno" \
                --cursorpos "$cursorpos" \
                --project "$PROJECT_NAME"
            waka_exitcode=$?
            printout verbose "wakatime exit code is $waka_exitcode"

            # update cache after sending
            cache_path=$(get_cache_path "$filepath")
            cp "$filepath" "$cache_path"
            printout verbose "updated file edit cache ($filepath -> $cache_path)"

            if [[ $waka_exitcode == "0" ]]; then
                printout today "wakatime heartbeat sent"
            else
                printout error "wakatime heartbeat failed"
            fi

            unset lineno
            unset cursorpos
            unset linestotal
            printout verbose "unset lineno, cursorpos, linestotal"

            should_wait=true
            printout verbose "set should_wait to true"
        else
            printout verbose "hash unchanged, skipping wakatime"
        fi
        should_heartbeat=false
        printout verbose "set should_heartbeat to false"

        unset dir
        unset action
        unset filename
        unset filepath
        printout verbose "unset dir, action, filename, filepath"

        if [[ $should_wait == true ]]; then
            printout verbose "should_wait is true, sleeping for 30 seconds"
            sleep 30

            unset should_wait
            printout verbose "slept for 30 seconds, unset should_wait"
        fi

        current_hash=$(get_hash)
        printout verbose "recalculated current_hash ($last_hash -> $current_hash)"
        last_hash=$current_hash
        printout verbose "set last_hash to current_hash ($last_hash -> $current_hash)"
    fi
done
