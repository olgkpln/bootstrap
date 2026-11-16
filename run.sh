#!/bin/sh
# Fetches this repo and runs bootstrap.sh. Extra arguments are passed through (e.g. --dry-run).
set -e

DEST="$HOME/dev/bootstrap"
mkdir -p "$HOME/dev"

if [ ! -d "$DEST" ]; then
    if command -v git >/dev/null 2>&1; then
        git clone https://github.com/olgkpln/bootstrap.git "$DEST"
    else
        tmp="$(mktemp -d)"
        curl -fsSL -o "$tmp/bootstrap.zip" https://github.com/olgkpln/bootstrap/archive/refs/heads/main.zip
        unzip -q "$tmp/bootstrap.zip" -d "$tmp"
        mv "$tmp"/bootstrap-* "$DEST"
        rm -rf "$tmp"
    fi
fi

cd "$DEST"
chmod +x bootstrap.sh
./bootstrap.sh "$@"
