#!/usr/bin/env python3
"""Local and web builds for the starter. Python standard library only."""

from __future__ import annotations

import argparse
from functools import partial
import html
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

import size_report


ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
EXCLUDED_DIRS = {"__pycache__", "node_modules", "cache"}
EXCLUDED_SUFFIXES = {".md", ".markdown", ".pyc", ".pyo", ".swp", ".swo"}


class BuildError(Exception):
    """An actionable build failure."""


def config(root: Path = ROOT) -> dict:
    try:
        value = json.loads((root / "build.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise BuildError(f"Cannot read build.json: {error}") from error
    if not isinstance(value, dict):
        raise BuildError("build.json must contain an object.")
    if not isinstance(value.get("name"), str) or not re.fullmatch(
        r"[a-z0-9]+(?:-[a-z0-9]+)*", value["name"]
    ):
        raise BuildError("build.json name must use lowercase letters, digits and hyphens.")
    if not isinstance(value.get("title"), str) or not value["title"].strip():
        raise BuildError("build.json title must be a nonempty string.")
    memory = value.get("memory")
    if type(memory) is not int or not 16777216 <= memory < 2147483648 or memory % 65536:
        raise BuildError("build.json memory must be a multiple of 65536, from 16 MiB to under 2 GiB.")
    try:
        value["size_budget"] = size_report.validate_budget(value.get("size_budget"))
    except ValueError as error:
        raise BuildError(str(error)) from error
    return value


def runtime_files(game: Path) -> list[Path]:
    """Reject symlinks and return only files that belong inside the game."""
    if game.is_symlink() or not game.is_dir():
        raise BuildError(f"Expected a real game directory: {game}")
    result = []
    for parent, directories, filenames in os.walk(game, followlinks=False):
        folder = Path(parent)
        for name in directories + filenames:
            path = folder / name
            if path.is_symlink():
                raise BuildError(f"Symlinks are not packaged: {path.relative_to(game)}")
        directories[:] = sorted(
            name for name in directories
            if not name.startswith(".") and name not in EXCLUDED_DIRS
        )
        for name in sorted(filenames):
            path = folder / name
            if name.startswith(".") or path.suffix.lower() in EXCLUDED_SUFFIXES:
                continue
            if not path.is_file():
                raise BuildError(f"Only ordinary files are packaged: {path.relative_to(game)}")
            result.append(path)
    if game / "main.lua" not in result:
        raise BuildError("game/main.lua is required at the root of the LÖVE package.")
    return sorted(result)


def write_zip(files: list[Path], base: Path, destination: Path) -> None:
    """Use stable ordering, timestamps and permissions, then replace atomically."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for source in sorted(files):
                entry = zipfile.ZipInfo(source.relative_to(base).as_posix(), (1980, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.create_system = 3
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, source.read_bytes())
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def build_love(root: Path = ROOT) -> Path:
    settings = config(root)
    game = root / "game"
    destination = root / "dist" / f"{settings['name']}.love"
    write_zip(runtime_files(game), game, destination)
    print(f"Built {destination.relative_to(root)}")
    return destination


def replace_directory(destination: Path) -> None:
    """Clear previous output so deleted game assets cannot survive a rebuild."""
    if destination.is_symlink():
        raise BuildError(f"Refusing to replace a symlink: {destination}")
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)


def patch_lovejs_audio(runtime: Path) -> None:
    """Fix love.js 11.4.1's OpenAL vector calls passing IDs instead of sources.

    Matches the source lookup in current Emscripten's libopenal.js. Patch only
    the exported runtime, leaving the npm dependency intact; already fixed
    runtimes are unchanged.
    """
    source = runtime.read_text(encoding="utf-8")
    broken = "AL.setSourceState(HEAP32[pSourceIds+i*4>>2],"
    fixed = "AL.setSourceState(AL.currentCtx.sources[HEAP32[pSourceIds+i*4>>2]],"
    if broken in source:
        runtime.write_text(source.replace(broken, fixed), encoding="utf-8")


def build_web(root: Path = ROOT) -> Path:
    settings = config(root)
    dist = root / "dist"
    previous = size_report.read_baseline(dist)
    destination = dist / "web"
    web_zip = dist / f"{settings['name']}-web.zip"
    # A failed current build must not leave an older upload looking ready.
    web_zip.unlink(missing_ok=True)
    replace_directory(destination)
    love_file = build_love(root)

    def report(*, complete=False, error=None):
        result = size_report.analyze(
            settings, love_file, web_directory=destination if complete else None,
            upload_zip=web_zip if complete else None, error=error, previous=previous,
        )
        size_report.save(result, dist)
        size_report.print_report(result)
        return result

    preflight = size_report.analyze(settings, love_file, previous=previous)
    if preflight["errors"]:
        report()
        raise BuildError("Size preflight failed. See dist/size-report.md.")

    exporter = root / "node_modules" / "love.js" / "index.js"
    try:
        if not exporter.is_file():
            raise BuildError("The web exporter is missing. Run npm ci first.")
        node = shutil.which("node")
        if node is None:
            raise BuildError("Node.js is missing. Install Node.js 22, then run npm ci.")
        for name in ("index.html", "player.js", "style.css", "love-LICENSE.txt"):
            if not (root / "web" / name).is_file():
                raise BuildError(f"Missing web/{name}.")
        if not (root / "THIRD-PARTY.md").is_file():
            raise BuildError("Missing THIRD-PARTY.md.")
        subprocess.run(
            [node, str(exporter), "-c", "-t", settings["title"], "-m", str(settings["memory"]),
             str(love_file), str(destination)],
            cwd=root, check=True,
        )
        patch_lovejs_audio(destination / "love.js")
        for name in ("index.html", "player.js", "style.css"):
            content = (root / "web" / name).read_text(encoding="utf-8")
            content = content.replace("__GAME_TITLE__", html.escape(settings["title"], quote=True))
            content = content.replace("__INITIAL_MEMORY__", str(settings["memory"]))
            (destination / name).write_text(content, encoding="utf-8")
        shutil.rmtree(destination / "theme", ignore_errors=True)
        shutil.copyfile(root / "web" / "love-LICENSE.txt", destination / "love-LICENSE.txt")
        shutil.copyfile(exporter.parent / "LICENSE", destination / "lovejs-LICENSE.txt")
        shutil.copyfile(root / "THIRD-PARTY.md", destination / "THIRD-PARTY.txt")
        for name in ("index.html", "player.js", "style.css", "game.js", "game.data", "love.js", "love.wasm"):
            if not (destination / name).is_file():
                raise BuildError(f"The exporter did not produce {name}.")
        write_zip([path for path in destination.rglob("*") if path.is_file()], destination, web_zip)
    except (BuildError, OSError, subprocess.CalledProcessError) as error:
        web_zip.unlink(missing_ok=True)
        report(error=f"Web export failed: {error}")
        raise
    result = report(complete=True)
    if result["errors"]:
        web_zip.unlink(missing_ok=True)
        raise BuildError("Web build exceeds its size limits; upload ZIP removed. See dist/size-report.md.")
    print(f"Built {web_zip.relative_to(root)} (upload this ZIP as an HTML game)")
    return web_zip


class WebHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def serve(port: int) -> None:
    directory = DIST / "web"
    if not (directory / "index.html").is_file():
        raise BuildError("No web build found. Run npm run web, or npm run dev to build and serve.")
    handler = partial(WebHandler, directory=str(directory))
    with ThreadingHTTPServer(("127.0.0.1", port), handler) as server:
        print(f"Preview: http://127.0.0.1:{server.server_port}/ (Ctrl+C to stop)", flush=True)
        server.serve_forever()


def check() -> None:
    config()
    files = runtime_files(ROOT / "game")
    for name in ("index.html", "player.js", "style.css"):
        if not (ROOT / "web" / name).is_file():
            raise BuildError(f"Missing web/{name}.")
    with tempfile.TemporaryDirectory() as directory:
        package = Path(directory) / "check.love"
        write_zip(files, ROOT / "game", package)
        with zipfile.ZipFile(package) as archive:
            if archive.testzip() is not None or "main.lua" not in archive.namelist():
                raise BuildError("LÖVE package integrity check failed.")
    suite = unittest.defaultTestLoader.discover(str(ROOT / "tools"), pattern="test_*.py")
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    if not result.wasSuccessful():
        raise BuildError("Build tooling checks failed.")
    print(f"Checks passed: {len(files)} runtime files. Playtest the game in a browser before publishing.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name, description in (
        ("check", "Check project structure and packaging behavior"),
        ("love", "Build the desktop .love package"),
        ("web", "Build the .love package and itch.io web ZIP"),
        ("size", "Rebuild web from current sources and report size, growth and budgets"),
        ("run", "Run game/ using the locally installed LÖVE executable"),
        ("clean", "Remove generated dist/ output"),
    ):
        commands.add_parser(name, help=description)
    for name, description in (
        ("serve", "Serve the existing web build over localhost HTTP"),
        ("dev", "Rebuild for web, then serve over localhost HTTP"),
    ):
        command = commands.add_parser(name, help=description)
        command.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    try:
        if args.command == "check":
            check()
        elif args.command == "love":
            build_love()
        elif args.command in {"web", "size"}:
            build_web()
        elif args.command in {"serve", "dev"}:
            if not 0 <= args.port <= 65535:
                raise BuildError("Port must be between 0 and 65535.")
            if args.command == "dev":
                build_web()
            serve(args.port)
        elif args.command == "run":
            runtime_files(ROOT / "game")
            executable = os.environ.get("LOVE_BIN") or shutil.which("love")
            if not executable:
                raise BuildError("LÖVE is missing. Install LÖVE 11.4+ or set LOVE_BIN to its executable path.")
            subprocess.run([executable, str(ROOT / "game")], cwd=ROOT, check=True)
        elif args.command == "clean":
            if DIST.is_symlink():
                raise BuildError("Refusing to clean a symlinked dist directory.")
            if DIST.exists():
                shutil.rmtree(DIST)
            print("Removed dist/")
        return 0
    except KeyboardInterrupt:
        return 0
    except (BuildError, OSError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
