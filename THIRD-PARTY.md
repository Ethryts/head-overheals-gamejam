# Runtime notices

The starter's own code is under the MIT license in LICENSE.

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

The starter includes no external art, music, fonts, or gameplay libraries.
Record asset authors and licenses here as you add them.
