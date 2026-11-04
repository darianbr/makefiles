#!/usr/bin/env sh

mf_require_project_root_arg() {
    [ "$#" -eq 1 ] || {
        printf '%s\n' "usage: $0 <project-root>" >&2
        exit 2
    }
}

mf_strip_quotes() {
    value=$1
    value=${value#\"}
    value=${value%\"}
    value=${value#\'}
    value=${value%\'}
    printf '%s' "$value"
}

mf_join_path() {
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