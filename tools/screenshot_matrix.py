"""Capture a representative UI screen at four resolutions and both palettes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOLUTIONS = [(1024, 768), (1280, 720), (1920, 1080), (2560, 1080)]
PALETTES = ["neon", "safe"]


def png_size(path):
    with Path(path).open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("Invalid PNG header: %s" % path)
    return struct.unpack(">II", header[16:24])


def run(command, log, timeout):
    options = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}
    with log.open("wb") as output:
        result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                timeout=timeout, **options)
    text = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode or "SCRIPT ERROR" in text or "Parse Error" in text:
        raise RuntimeError("Capture/import failed; see %s\n%s" % (log, text[-2000:]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--output", type=Path, default=ROOT / ".build" / "screenshot-matrix")
    parser.add_argument("--screen", default="lobby", choices=["lobby", "jobs", "hangar", "boss", "chief", "seats"])
    parser.add_argument("--skip-import", action="store_true")
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output / "manifest.json"
    manifest_path.unlink(missing_ok=True)  # a failed rerun must not leave an earlier success manifest
    (args.output / "index.html").unlink(missing_ok=True)
    for palette in PALETTES:
        for width, height in RESOLUTIONS:
            name = "%s-%s-%dx%d" % (args.screen, palette, width, height)
            for extension in [".png", ".log"]:
                (args.output / (name + extension)).unlink(missing_ok=True)
    if not args.skip_import:
        run([args.godot, "--headless", "--import"], args.output / "import.log", 900)
    captures = []
    for palette in PALETTES:
        for width, height in RESOLUTIONS:
            name = "%s-%s-%dx%d" % (args.screen, palette, width, height)
            image = args.output / (name + ".png")
            image.unlink(missing_ok=True)
            command = [args.godot, "--path", str(ROOT), "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--resolution", "%dx%d" % (width, height),
                       "--script", "res://tools/shots/ui_shot.gd", "--", args.screen, str(image),
                       palette, str(width), str(height)]
            if sys.platform.startswith("linux"):
                if not shutil.which("xvfb-run"):
                    raise RuntimeError("Linux captures require xvfb-run and Mesa")
                command = ["xvfb-run", "-a", "-s", "-screen 0 %dx%dx24" % (width, height), *command]
            run(command, args.output / (name + ".log"), 180)
            actual = png_size(image)
            if actual != (width, height):
                raise RuntimeError("%s has size %s; expected %s" % (image, actual, (width, height)))
            captures.append({"file": image.name, "screen": args.screen, "palette": palette,
                             "width": width, "height": height,
                             "sha256": hashlib.sha256(image.read_bytes()).hexdigest()})
            print("CAPTURE OK", name, flush=True)
    sha = subprocess.check_output(["git", "-c", "core.fsmonitor=false", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    changes = subprocess.check_output(["git", "-c", "core.fsmonitor=false", "status", "--porcelain"], cwd=ROOT, text=True).splitlines()
    manifest = {"commit": sha, "source_dirty": bool(changes), "source_changes": changes,
                "human_visual_acceptance": "not run", "captures": captures}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    html = "<!doctype html><meta charset=utf-8><title>Screenshot matrix</title><h1>Screenshot matrix</h1><p>Human visual acceptance: not run</p>"
    for capture in captures:
        html += '<h2>{file}</h2><a href="{file}"><img style="max-width:100%" src="{file}" alt="{file}"></a>'.format(**capture)
    (args.output / "index.html").write_text(html, encoding="utf-8")
    print("MATRIX OK: eight dimension-checked captures; human acceptance remains outstanding", flush=True)


if __name__ == "__main__":
    main()
