#!/bin/bash

SCRIPTS=$(dirname "$(realpath "$0")")
REPODIR="$SCRIPTS/.."

BIN='bundle exec rspec'
CMD="$BIN --format d"

if [ -n "$1" ]; then
    args=( "$@" )
else
    cd "$REPODIR" || { echo "Failed to cd to repo root"; exit 1; }
    args=()
fi
#echo "Running: $CMD" "${args[@]}"
exec $CMD "${args[@]}"
