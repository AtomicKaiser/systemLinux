#!/bin/sh
# Copy host programs and the shared libraries they need into a directory tree (same paths as on the
# host). Used to put the installer's few boot/disk tools into the live image and initramfs.
# usage: copy-bin.sh DEST PROGRAM...
set -eu
DEST=${1:?usage: copy-bin.sh DEST PROGRAM...}; shift
for p in "$@"; do
    path=$(command -v "$p" 2>/dev/null || true)
    [ -n "$path" ] || { echo "copy-bin: $p not found on the build host" >&2; exit 1; }
    path=$(readlink -f "$path")
    mkdir -p "$DEST$(dirname "$path")"; cp -L "$path" "$DEST$path"
    if ldd "$path" 2>/dev/null | grep -q 'not found'; then echo "copy-bin: missing libraries for $path" >&2; exit 1; fi
    ldd "$path" 2>/dev/null | sed -n 's#.*=> \(/[^ ]*\) .*#\1#p; s#^[[:space:]]*\(/[^ ]*\) (.*#\1#p' | while read -r lib; do
        lib=$(readlink -f "$lib")
        mkdir -p "$DEST$(dirname "$lib")"; cp -L "$lib" "$DEST$lib"
    done
done
