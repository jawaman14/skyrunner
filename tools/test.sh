#!/usr/bin/env bash
# Run the headless test suite: ./tools/test.sh [filter]
# --import first (it can take minutes on a cold checkout now the art packs are in) so class_name scripts are registered; without it a headless
# --script run can stall on an unresolved class instead of failing.
# GDScript runtime errors don't abort the calling function (it carries on with
# null), so any "SCRIPT ERROR" in the output also fails the run.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
import_out=$(mktemp)
timeout 900 "$GODOT" --headless --import >"$import_out" 2>&1
import_code=$?
if [[ $import_code -ne 0 ]] || grep -qE "SCRIPT ERROR|Parse Error" "$import_out"; then
  cat "$import_out"
  rm -f "$import_out"
  echo "FAILED: import did not complete cleanly"
  [[ $import_code -eq 0 ]] && import_code=100
  exit "$import_code"
fi
rm -f "$import_out"
out=$(mktemp)
timeout "${TEST_TIMEOUT:-900}" "$GODOT" --headless --script res://tests/run_tests.gd -- "$@" >"$out" 2>&1
code=$?
grep -v -E "^\s*$" "$out"
if grep -qE "SCRIPT ERROR|Parse Error" "$out"; then
  echo "FAILED: script errors above"
  [[ $code -eq 0 ]] && code=100
fi
rm -f "$out"
exit $code
