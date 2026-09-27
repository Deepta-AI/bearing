#!/usr/bin/env bash
# Copies our hooks into .git/hooks. Run once after cloning (make setup).
set -eu
root="$(git rev-parse --show-toplevel)"
cp "$root"/scripts/hooks/* "$root"/.git/hooks/
chmod +x "$root"/.git/hooks/*
echo "hooks installed"
