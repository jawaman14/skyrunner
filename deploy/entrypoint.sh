#!/bin/sh
# Runs the dedicated server and turns `docker stop` (SIGTERM) into a clean shutdown: Godot does not handle SIGTERM, so the server
# watches a stop file; this wrapper touches it, then waits for the server to save and exit.
STOP="${SKYRUNNER_STOP_FILE:-/data/stop}"
rm -f "$STOP"
godot --headless --path /app --script res://scripts/net/dedicated.gd -- "$@" &
PID=$!
trap 'touch "$STOP"; wait $PID' TERM INT
wait $PID
STATUS=$?
# (a trapped signal ends the first wait early: wait again for the real exit)
wait $PID 2>/dev/null
exit $STATUS
