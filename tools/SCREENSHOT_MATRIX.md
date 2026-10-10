# Screenshot matrix

Tracker task P09: capture a representative screen at 1024×768, 1280×720,
1920×1080 and 2560×1080 in the neon and colour-safe palettes.

Run from the repository root with the pinned Godot 4.7.2 binary:

```bash
python tools/screenshot_matrix.py --godot /path/to/godot
```

The tool imports first, then captures the lobby eight times sequentially. Linux requires Xvfb and
Mesa; Windows can use its normal compatibility renderer. Supply `--skip-import` only with a warm
class cache. `--screen jobs`, `hangar`, `boss`, `chief` or `seats` selects another existing capture
fixture for the same matrix.

Output is gitignored under `.build/screenshot-matrix/`: labelled PNGs and logs, a JSON manifest
with source commit (the PR merge commit in CI), dirty-state marker and changed paths,
dimensions and image hashes, and an HTML gallery.
CI publishes these as the `ui-screenshot-matrix` artifact. A failed render, script/parse error,
missing PNG or wrong dimensions fails the job; stale manifests and current-case PNGs are removed
before each run.

These are scripted source-build captures, not exported-build or physical-input acceptance.
The lobby matrix is representative tooling coverage, not a visual pass over every game screen.
Human focus, read-aloud, controller, clipping and legibility checks remain outstanding and must be
recorded against the appropriate build in `docs/PROJECT_STATUS.md`.
