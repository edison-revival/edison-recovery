#!/usr/bin/env bash
# Download the Intel recovery blobs listed in blobs.lock into blobs/ and verify them.
# Exits non-zero if any file is missing or its SHA256 doesn't match.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/blobs"
mkdir -p "$dest"

status=0
while read -r sha file url; do
    case "$sha" in ''|'#'*) continue ;; esac
    if [ -f "$dest/$file" ] && echo "$sha  $dest/$file" | sha256sum -c --quiet - 2>/dev/null; then
        echo "ok        $file (cached)"
        continue
    fi
    echo "fetching  $file"
    curl -fsSL --retry 3 -o "$dest/$file.part" "$url"
    if echo "$sha  $dest/$file.part" | sha256sum -c --quiet - 2>/dev/null; then
        mv "$dest/$file.part" "$dest/$file"
        echo "ok        $file"
    else
        echo "MISMATCH  $file: got $(sha256sum "$dest/$file.part" | cut -d' ' -f1), want $sha" >&2
        rm -f "$dest/$file.part"
        status=1
    fi
done < "$root/blobs.lock"

exit "$status"
