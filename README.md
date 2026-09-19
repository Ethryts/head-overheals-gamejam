# LÖVE jam starter

A small Lua starting point with a complete path to an itch.io browser upload.
No theme, mechanics, scene framework, or asset pack is assumed. Replace the
boot screen in `game/src/game.lua` and build from there.

## Start

Install **Node.js 22** and **Python 3.10+**. Install **LÖVE 11.4 or 11.5** only
if you want the native development loop; web builds do not need it.

```sh
npm ci
npm run dev
```

Open **http://127.0.0.1:8000**, then click **Play**. Click the canvas or press
Space to test input; F3 toggles stats. The page has a fullscreen button.

For faster iteration, use `love game` / `make run` locally. Rebuild the web
version regularly, especially after adding audio, shaders, or libraries.
There is no file watcher or hot reload: `npm run dev` builds once and serves;
after editing, run `npm run web` in another terminal and refresh the page.

## Commands

| Task | npm | Make |
| --- | --- | --- |
| Install pinned exporter | `npm ci` | `make install` |
| Run native LÖVE | `npm run run` | `make run` |
| Check packaging and structure | `npm run check` | `make check` |
| Build `.love` | `npm run love` | `make love` |
| Build web + itch.io ZIP | `npm run web` | `make web` |
| Rebuild web + report current sizes | `npm run size` | `make size` |
| Build web and serve it | `npm run dev` | `make dev` |
| Serve existing build | `npm run serve` | `make serve` |
| Delete generated output | `npm run clean` | `make clean` |

Use `npm run dev -- --port 8080` or `make dev PORT=8080` for another port.
Each task is also available as `python3 tools/build.py <task>`. On Windows,
use `py -3 tools/build.py <task>` if Python is not named `python3`.
Set `LOVE_BIN` to the full LÖVE executable path when it is not on PATH; for
example `/Applications/love.app/Contents/MacOS/love` on macOS.

## Edit here

| Location | Purpose |
| --- | --- |
| `game/src/game.lua` | Your game: load, update, draw, and input handlers |
| `game/main.lua` | LÖVE callbacks and viewport coordination; add other callbacks here as needed |
| `game/src/viewport.lua` | Virtual coordinates, desktop letterboxing, mouse mapping |
| `game/project.lua` | Native title, save identity, logical width and height |
| `game/conf.lua` | LÖVE configuration |
| `game/assets/` | Runtime art, sounds, fonts and data |
| `build.json` | Web title, output filename, initial WebAssembly memory and size budgets |
| `web/` | Browser loader, loading/errors, Play button, fullscreen and canvas sizing |
| `tools/build.py` | Packaging and local preview; Python standard library only |
| `.github/workflows/build.yml` | Build artifacts on pushes and pull requests |

Rename the title in both `game/project.lua` and `build.json`. Change
`project.identity` before adding saves so different games do not share a save
directory. The default logical resolution is 960×540. The browser fits the
canvas into the iframe while preserving aspect ratio; native window resizing
uses the viewport helper. Only code inside `game/` is shipped as Lua.

The boot screen is disposable. It contains an input indicator and a focus
pause/mute example, not game rules. Ordinary LÖVE APIs remain available.

## Build and upload to itch.io

```sh
npm run check
npm run web
```

Outputs:

- `dist/jam-starter.love`: Lua + assets; players need LÖVE installed.
- `dist/web/`: static website, including the WebAssembly runtime.
- **`dist/jam-starter-web.zip`**: upload this file to itch.io.

1. Create/edit an itch.io project and set its kind to **HTML**.
2. Upload `dist/jam-starter-web.zip` and mark it as playable in the browser.
3. Use a 960×540 embed initially, with click-to-play enabled. The included
   canvas scales when the embed changes size or enters fullscreen.
4. Preview on itch.io, check input/audio, then publish when ready.

Do not upload the whole starter archive or an extra parent folder.
The build places `index.html` at the upload ZIP's root and uses relative paths.
Other static hosts can serve `dist/web/` directly. Open it through an HTTP
server, not by double-clicking `index.html`.

If you already use itch.io's `butler`, subsequent uploads can use:

```sh
butler push dist/web YOUR_ACCOUNT/YOUR_GAME:html5
```

Configure the project/channel as playable HTML on itch.io first. Authentication
and publishing stay explicit; this starter does not store upload credentials.

GitHub Actions builds the same two artifacts automatically. Download the
`web-build` artifact and extract its outer GitHub archive; upload the inner
`jam-starter-web.zip`. CI checks packaging and runs the exporter; it does not
playtest or publish your game.

## Watch build size

Every web build (`npm run web`, `npm run build`, or `npm run dev`) reports sizes
and checks budgets. Use **`npm run size`** / **`make size`** after adding assets;
it rebuilds the current game rather than reading a previous export.

The report includes:

- Upload ZIP, extracted website, and total unpacked game code/assets.
- Compressed `game.data` bundle and WebAssembly runtime sizes.
- The ten largest included game files, with raw and compressed sizes.
- Changes since the previous successful complete local build, when available.

Keep assets you actually ship under `game/`; source art and other working files
belong outside it. Files excluded by the packager do not count toward game size.

`build.json` starts with these adjustable jam budgets, in decimal MB
(1 MB = 1,000,000 bytes):

```json
"size_budget": {
  "web_zip": { "warn_mb": 20, "fail_mb": 30 },
  "game_unpacked": { "warn_mb": 50, "fail_mb": 100 }
}
```

These are starter budgets, not itch.io limits. Warnings let the build continue;
a failed budget makes the command fail and leaves no final upload ZIP.
Change the numbers to fit your game, or set an individual threshold to `null`
to disable it. When both are enabled, `fail_mb` must be at least `warn_mb`.

The pipeline also checks itch.io's extracted-upload limits: **200 MB per file,
500 MB total, 1,000 files, and 240 characters per file path**. All game assets
are packed into one `game.data` file, so the per-file check matters even when
the upload ZIP is small. See [itch.io's requirements](https://itch.io/docs/creators/html5#zip-file-requirements).

Detailed reports are saved as `dist/size-report.md` and `dist/size-report.json`,
outside the upload. If the exporter fails, they still show source sizes and
the error; web sizes are unavailable. Failed builds do not replace the previous
successful baseline in `dist/size-baseline.json`. `npm run clean` removes that
baseline along with the other output.

CI uses the same checks, adds the Markdown report to its job summary, and saves
a separate `size-report` artifact even on build failure when a report exists.
Clean CI runs have no previous local baseline, so they do not show size deltas.
Game artifacts are uploaded only after a successful build.

Size checks do not measure browser RAM or guarantee the game will run. The
report shows configured initial WebAssembly memory, and the build checks that
the `.love` archive fits within it before export. Decoded textures, audio and
runtime allocations need more memory. Rebuild and playtest in a browser as
assets grow, including on itch.io before the jam deadline.

## Browser target

The pinned npm package is **love.js 11.4.1**, which bundles **LÖVE 11.4**.
Native LÖVE 11.5 is suitable for development while sticking to the 11.4 API.
This is a community web port; LÖVE itself does not provide this web export.

- Compatibility mode (`-c`) avoids the special cross-origin isolation headers
  required by the threaded exporter. The upstream port notes possible audio
  glitches, so test your actual sound playback early.
- Keep game code compatible with Lua 5.1. Do not assume native libraries,
  LuaJIT FFI, operating-system processes, raw sockets, or threads work on web.
- Use exact asset filename case. Package assets under `game/`, and reference
  them using LÖVE-relative paths such as `assets/sound.ogg`.
- Browser storage is browser-managed. Test persistence separately before
  depending on saves; it is not a desktop filesystem.
- Desktop/browser keyboard and mouse are the initial target. Touch controls,
  mobile performance, gamepad support, and platform-specific features need
  their own playtesting before being advertised.
- `build.json` starts with 64 MiB of WebAssembly memory. Increase it if startup
  or asset loading requires more, then test the resulting browser build.

`npm run check` verifies packaging boundaries, not Lua syntax or game behavior.
The exporter bundles Lua without checking it: a successful build still needs
a browser run. Rebuilding clears old web assets. Dotfiles, Markdown docs,
editor swap files and cache directories are excluded from the `.love` file.

## References

- [LÖVE downloads and API](https://love2d.org/)
- [Published love.js 11.4.1](https://www.npmjs.com/package/love.js/v/11.4.1)
- [love.js source and compatibility notes](https://github.com/Davidobot/love.js)
- [itch.io HTML5 upload requirements](https://itch.io/docs/creators/html5)
- [itch.io butler documentation](https://itch.io/docs/butler/)

The starter code is MIT licensed. Runtime notices are included in each web
export; record new asset credits in `THIRD-PARTY.md`.
