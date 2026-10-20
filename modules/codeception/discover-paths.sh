#!/usr/bin/env sh
set -eu

[ "$#" -eq 1 ] || {
    printf '%s\n' "usage: $0 <project-root>" >&2
    exit 2
}

project_root=$1
config_file="$project_root/codeception.yml"
output_dir=""

strip_quotes() {
    value=$1
    value=${value#\"}
    value=${value%\"}
    value=${value#\'}
    value=${value%\'}
    printf '%s' "$value"
}

join_path() {
    base=$1
    tail=$2

    case "$tail" in
        /*)
            printf '%s\n' "$tail"
            ;;
        *)
            base=${base%/}
            printf '%s/%s\n' "$base" "$tail"
            ;;
    esac
}

if [ -f "$config_file" ]; then
    output_dir=$(awk '
        BEGIN { in_paths = 0 }
        /^[[:space:]]*paths:[[:space:]]*$/ { in_paths = 1; next }
        in_paths && /^[^[:space:]]/ { in_paths = 0 }
        in_paths && /^[[:space:]]*output:[[:space:]]*/ {
            line = $0
            sub(/^[[:space:]]*output:[[:space:]]*/, "", line)
            gsub(/[[:space:]]+$/, "", line)
            print line
            exit
        }
    ' "$config_file")
fi

if [ -n "$output_dir" ]; then
    output_dir=$(strip_quotes "$output_dir")
else
    output_dir="_output"
fi

join_path "$project_root" "${output_dir%/}/coverage"