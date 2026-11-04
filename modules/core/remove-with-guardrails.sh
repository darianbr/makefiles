#!/usr/bin/env sh
set -eu

[ "$#" -eq 4 ] || {
    printf '%s\n' "usage: $0 <project-root> <module-name> <dir|file> <cleanup-path>" >&2
    exit 2
}

project_root=$1
module_name=$2
entry_type=$3
cleanup_path=$4

project_root=${project_root%/}

case "$entry_type" in
    dir|file) ;;
    *)
        printf '[%s] invalid cleanup entry type: %s\n' "$module_name" "$entry_type" >&2
        exit 2
        ;;
esac

if [ "$entry_type" = "dir" ]; then
    if [ ! -d "$cleanup_path" ]; then
        printf '[%s] skipping %s (not found)\n' "$module_name" "$cleanup_path"
        exit 0
    fi

    resolved_path=$(cd "$cleanup_path" 2>/dev/null && pwd -P || true)
else
    if [ ! -f "$cleanup_path" ]; then
        printf '[%s] skipping %s (not found)\n' "$module_name" "$cleanup_path"
        exit 0
    fi

    resolved_dir=$(cd "$(dirname "$cleanup_path")" 2>/dev/null && pwd -P || true)
    if [ -z "$resolved_dir" ]; then
        printf '[%s] skipping %s (unable to resolve path)\n' "$module_name" "$cleanup_path"
        exit 0
    fi

    resolved_path="$resolved_dir/$(basename "$cleanup_path")"
fi

if [ -z "$resolved_path" ]; then
    printf '[%s] skipping %s (unable to resolve path)\n' "$module_name" "$cleanup_path"
    exit 0
fi

if [ "$resolved_path" = "/" ] || [ "$resolved_path" = "$project_root" ]; then
    printf '[%s] refusing to remove unsafe path %s\n' "$module_name" "$resolved_path" >&2
    exit 0
fi

case "$resolved_path" in
    "$project_root"/*) ;;
    *)
        printf '[%s] refusing to remove path outside project root: %s\n' "$module_name" "$resolved_path" >&2
        exit 0
        ;;
esac

if ! command -v git >/dev/null 2>&1 || ! git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '[%s] refusing to remove %s (cannot verify .gitignore coverage)\n' "$module_name" "$resolved_path" >&2
    exit 0
fi

rel_path=${resolved_path#"$project_root"/}

if [ "$entry_type" = "dir" ]; then
    if git -C "$project_root" check-ignore -q -- "$rel_path" || git -C "$project_root" check-ignore -q -- "$rel_path/"; then
        printf '[%s] removing %s\n' "$module_name" "$resolved_path"
        rm -rf "$resolved_path"
    else
        printf '[%s] refusing to remove %s (.gitignore does not match)\n' "$module_name" "$resolved_path" >&2
    fi
else
    if git -C "$project_root" check-ignore -q -- "$rel_path"; then
        printf '[%s] removing %s\n' "$module_name" "$resolved_path"
        rm -f "$resolved_path"
    else
        printf '[%s] refusing to remove %s (.gitignore does not match)\n' "$module_name" "$resolved_path" >&2
    fi
fi