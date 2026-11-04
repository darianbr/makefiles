#!/usr/bin/env sh
set -eu

script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)
# shellcheck source=/dev/null
. "$script_dir/../core/discover-common.sh"

mf_require_project_root_arg "$@"

project_root=$1
config_file="$project_root/codeception.yml"
output_dir=""

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
    output_dir=$(mf_strip_quotes "$output_dir")
else
    output_dir="_output"
fi

mf_join_path "$project_root" "${output_dir%/}/coverage"