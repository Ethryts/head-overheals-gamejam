# Game assets

Put game assets here; suggested folders are `images/`, `audio/`, `fonts/`, and
`data/`. Load files using paths relative to `game/`, such as
`love.graphics.newImage("assets/images/player.png")`.

Keep filenames and paths lowercase and case-consistent: browser builds are
case-sensitive. Include only assets you can redistribute, with their licenses
or attribution requirements alongside them. This starter uses LÖVE's default
font and draws its graphics in code, so no external asset is required.

Read bundled assets using LÖVE's filesystem. Write saves using
`love.filesystem.write` rather than `io.open`; use portable Lua and LÖVE APIs
instead of shell commands, native extensions, or FFI for code that runs on the
web. Browser persistence depends on the player's storage/privacy settings;
check save behavior in the exported game before relying on it.
