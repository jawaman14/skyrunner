#!/usr/bin/env bash
# Repo hygiene checks (run first in CI, cheap): fails on things that should never be tracked or exported.
#   - scratch scripts named tools/zz_* (scratch goes outside the repo)
#   - the stray skyrunner-godot/ folder
#   - reference/python (the Python prototype lives on the python-prototype-archive tag)
#   - the export filter must keep tests, tools, docs, balance code and the unused 2D packs out of builds
cd "$(dirname "$0")/.."
bad=0
fail() { echo "HYGIENE FAIL: $1"; bad=1; }

if git ls-files | grep -q '^tools/zz_'; then fail "scratch script tracked under tools/zz_*"; fi
if git ls-files | grep -q '^skyrunner-godot/'; then fail "the stray skyrunner-godot/ folder is tracked"; fi
if git ls-files | grep -q '^reference/python/'; then fail "reference/python is back (use the python-prototype-archive tag)"; fi
for pat in 'tests/\*' 'tools/\*' 'docs/\*' 'scripts/balance/\*' 'assets/ui/\*'; do
	if ! grep -q "exclude_filter=.*$pat" export_presets.cfg; then fail "export_presets.cfg no longer excludes $pat"; fi
done
if [ "$bad" = 0 ]; then echo "hygiene OK"; fi
exit $bad
