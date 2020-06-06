#!/bin/bash

SCRIPTS=$(dirname "$(realpath "$0")")
REPODIR="$SCRIPTS/.."

BIN=$(type mdl | awk '{print $NF}')

if [ -n "$1" ]; then
    args=( "$@" )
else
    cd "$REPODIR" || { echo "Failed to cd to repo root"; exit 1; }
    args=('.')
fi
# shellcheck disable=SC2086
exec $BIN "${args[@]}"
