# Dungeon items

40 original, programmatically drawn **16x16** icons in the same outlined pixel
style as the knight, healer and dark dungeon. The images are static, transparent
PNGs with a one-pixel clear margin. Names describe their appearance only.

| Row | Items, left to right |
| --- | --- |
| 1 | Red Heart, Blue Heart, Golden Heart, Lightning Bolt, Flame, Snowflake, Sun, Crescent Moon |
| 2 | Ruby, Emerald, Sapphire, Amethyst, Gold Coin, Silver Coin, Gold Ring, Silver Ring |
| 3 | Boots, Gauntlet, Shield, Dagger, Arrow, Helmet, Book, Scroll |
| 4 | White Feather, Black Feather, Clover, Leaf, Mushroom, Fang, Skull, Eye |
| 5 | Red Potion, Blue Potion, Green Potion, Purple Potion, Hourglass, Key, Bell, Candle |

## Files

- `assets/individual/`: one transparent 16x16 PNG per named item.
- `assets/items.png`: 128x80 atlas, eight columns by five rows, 16x16 cells.
- `assets/items-2x.png`: exact nearest-neighbour 2x copy, with 32x32 cells.
- `assets/catalog.lua` / `.json`: literal names, native atlas rectangles, centre origins and ordering.
- `items-preview.png`: labelled enlarged overview.
- `items-on-floor.png`: all icons shown against a dark floor at 4x pixel scale.
- `items.lua`: optional draw-only LÖVE helper.
- `generate.py` and `art/`: editable pixel drawing source.

There are no effects, stat values, rarity levels, collision sizes or pickup
behaviours assigned to these assets. Heart, metal and potion colour choices are
visual variants; they carry no metadata beyond their literal names.

## LÖVE

Copy `assets/` into a folder such as `assets/items/`, and copy `items.lua` wherever
you keep draw helpers. Call from your existing game state after LÖVE initializes:

```lua
local Items = require("items")
local art = Items.new("assets/items")

-- In your draw function: source name, centre x/y, display scale.
love.graphics.setColor(1, 1, 1, 1)
art:draw("lightning_bolt", 120, 90, 4)
art:draw("red_heart", 180, 90, 4)
```

The helper installs no callbacks, changes no game state and respects the current
draw colour. It has no SUIT/HUMP dependency. Position/animate icons in your own
code. Integer scaling and pixel-aligned positions give the most even pixel edges.

The supplied catalog and helper address the **native** atlas. If you manually use
`items-2x.png`, multiply source rectangles and origins by two (cell size 32x32),
or use the native atlas and draw it at scale 2 for the same appearance.

## Rebuild

```sh
python -m pip install Pillow
python generate.py
```

The shared palette lives in `art/common.py`. Shape definitions live in
`art/symbols.py`, `treasures.py`, `gear.py`, `nature.py` and `relics.py`.
Pillow is needed only to rebuild the images. No outside artwork or services are
needed, and there is no runtime Python dependency.
