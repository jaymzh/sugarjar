#!/bin/bash

SCRIPTS=$(dirname "$(realpath "$0")")
REPODIR="$SCRIPTS/.."

BIN='bundle exec mdl'

if [ -n "$1" ]; then
    args=( "$@" )
else
    cd "$REPODIR" || { echo "Failed to cd to repo root"; exit 1; }
    args=('.')
fi
#echo "Running: $BIN" "${args[@]}"
exec $BIN "${args[@]}"
