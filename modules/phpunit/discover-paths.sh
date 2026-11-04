#!/usr/bin/env sh
set -eu

script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)
# shellcheck source=/dev/null
. "$script_dir/../core/discover-common.sh"

mf_require_project_root_arg "$@"

project_root=$1
config_file="$project_root/phpunit.xml"
output_dir=""

if [ -f "$config_file" ]; then
    output_dir=$(tr '\n' ' ' < "$config_file" | sed -n 's/.*<html[^>]*outputDirectory="\([^"]*\)"[^>]*>.*/\1/p')
fi

if [ -n "$output_dir" ]; then
    output_dir=$(mf_strip_quotes "$output_dir")
else
    output_dir="coverage"
fi

mf_join_path "$project_root" "$output_dir"