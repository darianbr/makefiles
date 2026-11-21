#!/usr/bin/env sh
# Open a generated report using the configured opener or a platform default.
set -eu

if [ "$#" -ne 4 ]; then
    printf 'usage: %s <project-root> <module-name> <report-path> <browser>\n' "$0" >&2
    exit 2
fi

project_root=$1
module_name=$2
report_path=$3
browser=$4

cd "$project_root"
if [ -n "$browser" ]; then
    if ! command -v "$browser" >/dev/null 2>&1; then
        printf '[%s] Browser opener not found: %s\n' "$module_name" "$browser" >&2
        exit 1
    fi
elif command -v xdg-open >/dev/null 2>&1; then
    browser=xdg-open
elif command -v open >/dev/null 2>&1; then
    browser=open
else
    printf '[%s] No browser opener found; open %s manually.\n' "$module_name" "$report_path" >&2
    exit 1
fi

"$browser" "$report_path"