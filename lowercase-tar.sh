#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <input.tar.gz> <output.tar.gz>"
    exit 1
fi

input=$(realpath "$1")
output=$(realpath -m "$2")
tmpdir=$(mktemp -d)

cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

tar xzf "$input" -C "$tmpdir"

# -depth ensures children are processed before parents
# -mindepth 1 excludes the tmpdir itself from being renamed
find "$tmpdir" -mindepth 1 -depth -name '*[A-Z]*' | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    lower=$(echo "$base" | tr '[:upper:]' '[:lower:]')
    [[ "$base" != "$lower" ]] && mv "$f" "$dir/$lower" || true
done

tar czf "$output" -C "$tmpdir" .
echo "Created: $output"