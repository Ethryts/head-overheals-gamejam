# Third-party resources and notices

The project's own code is under the MIT license in [LICENSE](LICENSE).
Third-party resources retain their respective licenses and notices below.

## Runtime

Web exports include Davidobot's love.js 11.4.1 (MIT), including its bundled
LÖVE 11.4 runtime. The exporter license is copied into every web build as
lovejs-LICENSE.txt. LÖVE uses the zlib/libpng license and incorporates several
other libraries; its upstream license bundle is included as love-LICENSE.txt.
Preserve these notices when redistributing the runtime:

The web build patches love.js 11.4.1's bulk OpenAL play/pause/stop calls to
resolve source IDs to source objects, matching current Emscripten's
`src/lib/libopenal.js`. This correction is applied to the exported JavaScript
by `tools/build.py`; the installed npm package is unchanged.

- love.js source and license: https://github.com/Davidobot/love.js
- LÖVE 11.4 license and bundled-library notices:
  https://github.com/love2d/love/blob/11.4/license.txt
- Emscripten: https://github.com/emscripten-core/emscripten/blob/main/LICENSE

## Gameplay libraries

| Resource | Author | Source | Bundled license notice |
| --- | --- | --- | --- |
| anim8 2.3.1 | Enrique García Cota (kikito) | [kikito/anim8](https://github.com/kikito/anim8) | MIT; embedded in `game/lib/anim8.lua` |
| Baton 1.0.2 | Andrew Minnich (tesselode) | [tesselode/baton](https://github.com/tesselode/baton) | MIT; embedded in `game/lib/baton.lua` |
| HC | Matthias Richter (vrld) | [vrld/HC](https://github.com/vrld/HC) | `game/lib/HC/docs/license.rst` |
| HUMP | Matthias Richter (vrld) | [vrld/hump](https://github.com/vrld/hump) | `game/lib/hump/README.md` and `game/lib/hump/docs/license.rst` |
| SUIT | Matthias Richter (vrld) | [vrld/SUIT](https://github.com/vrld/SUIT) | `game/lib/suit/license.txt` |

Preserve the bundled library notices, including the additional restriction on
using the copyright holders' names in advertising in HC, HUMP, and SUIT.

## Art, fonts, and sound

| Resource | Files | Author and source | License / usage notes |
| --- | --- | --- | --- |
| Monster Asset Pack [16x16], basic tier | `game/assets/images/Basic Asset Pack/` | DeepDiveGameStudio; [source and terms](https://deepdivegamestudio.itch.io/monsterassetpack), [July 2024 pack update](https://deepdivegamestudio.itch.io/monsterassetpack/devlog/769648/monster-asset-pack-major-changes) | Custom terms allow use and editing in commercial and non-commercial games; attribution is optional. |
| Cryo's Mini GUI | `game/assets/images/ui/cryo-mini-gui.png` | PaperHatLizard / Cryo; [source page](https://paperhatlizard.itch.io/cryos-mini-gui) | The source page lists [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Imported from `GUI/GUI_1x.png` in the original pack and renamed. |
| Monogram | `game/assets/fonts/monogram/` | Vinícius Menézio (datagoblin); [source page](https://datagoblin.itch.io/monogram) | CC0; see bundled `credits.txt`. |

## Project-created assets

- Music in `game/assets/audio/music/` was composed by the project maintainer.
- Hero and healer artwork in `game/assets/images/Hero Asset/` and
  `game/assets/images/Healer Asset/` was AI-generated for the project.
- The tileset in `game/assets/images/Tileset/` and particle artwork in
  `game/assets/images/fx/particles.png` were AI-generated for the project.
- The [dungeon items README](game/assets/images/dungeon-items/README.md) describes
  those icons as original, programmatically drawn artwork with no outside artwork.

