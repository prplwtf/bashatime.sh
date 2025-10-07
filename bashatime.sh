#!/bin/bash

get_hash() {
    git ls-files -z | xargs -0 md5sum | sort | md5sum
}

last_hash=$(get_hash)
echo "initial hash: $last_hash"

should_heartbeat=false
heartbeat_timer=0
echo "initialized: should_heartbeat=$should_heartbeat, heartbeat_timer=$heartbeat_timer"

while true; do
    echo "waiting for changes..."
    output="$(inotifywait -q -t 1 -r -e modify,create ./)"
    # shellcheck disable=SC2181
    if [[ $? == "0" ]]; then
        echo "inotifywait triggered: $output"
        current_time=$(date +%s)
        echo "current time: $current_time"

        if [[ $should_heartbeat == "false" ]]; then
            heartbeat_timer=$((current_time + 30))
            echo "setting heartbeat timer to: $heartbeat_timer"
        fi

        if [[ "$output" =~ ^(.*/)[[:space:]]([A-Z]+)[[:space:]](.*)$ ]]; then
            dir="${BASH_REMATCH[1]}"
            action="${BASH_REMATCH[2]}"
            filename="${BASH_REMATCH[3]}"
            filepath="${dir}${filename}"
            echo "parsed: dir=$dir, action=$action, filename=$filename, filepath=$filepath"

            # only track if file is actually in git
            if git ls-files --error-unmatch "$filepath" &>/dev/null; then
                echo "file is tracked by git"
                should_heartbeat=true
                echo "should_heartbeat set to true"
            else
                echo "file not tracked by git, ignoring"
                should_heartbeat=false
            fi
        else
            echo "regex didn't match output"
            should_heartbeat=false
        fi
    fi

    current_time=$(date +%s)
    echo "checking heartbeat: should_heartbeat=$should_heartbeat, current_time=$current_time, heartbeat_timer=$heartbeat_timer"

    if [[ ($should_heartbeat == true) && ($current_time -ge $heartbeat_timer) ]]; then
        echo "heartbeat conditions met, checking hash..."
        current_hash=$(get_hash)
        echo "current hash: $current_hash"

        if [ "$last_hash" != "$current_hash" ]; then
            echo "hash changed, sending to wakatime: $filepath"
            wakatime-cli \
                --time "$current_time" \
                --write true \
                --entity "$filepath" \
                --plugin "Emma Corp. Makeshift Wakatime"
            last_hash=$current_hash
            echo "wakatime sent, updated last_hash"
        else
            echo "hash unchanged, skipping wakatime"
        fi
        should_heartbeat=false
        echo "reset should_heartbeat to false"
    fi
done
