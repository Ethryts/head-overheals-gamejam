# Build size: OK

Decimal MB (1 MB = 1,000,000 bytes). Deltas compare with the last successful local web build.

| Measurement | Current | Change |
| --- | ---: | ---: |
| Upload ZIP | 1.73 MB | +1 B |
| Extracted website | 5.13 MB | 0 B |
| Game bundle (.love / game.data) | 3.14 KB | 0 B |
| Included game files, before compression | 6.91 KB | 0 B |
| WebAssembly runtime | 4.72 MB | 0 B |

| Jam budget | Warn at | Fail above |
| --- | ---: | ---: |
| Upload ZIP | 20 MB | 30 MB |
| Included game files, before compression | 50 MB | 100 MB |

Included game files: 5. Exported web files: 10.
Largest web file: love.wasm (4.72 MB).
Configured initial WebAssembly memory: 64 MiB (67,108,864 bytes). This is not measured browser RAM; decoded textures/audio and other allocations need additional memory.

## Largest included game files

| Path | Before compression | Inside .love |
| --- | ---: | ---: |
| src/game.lua | 4.26 KB | 1.52 KB |
| src/viewport.lua | 1.19 KB | 465 B |
| main.lua | 907 B | 340 B |
| conf.lua | 364 B | 166 B |
| project.lua | 179 B | 132 B |

The game bundle contains all these files; it is not additional content alongside game.data.
The .love and ZIP sizes do not predict decoded asset memory.

Hosting checks cover 200 MB per file, 500 MB extracted total, 1,000 web files, and 240-character paths.

Budget thresholds live in build.json. They are early jam targets, not itch.io's maximums.
Playtest web builds regularly; passing size checks does not verify runtime behavior.
