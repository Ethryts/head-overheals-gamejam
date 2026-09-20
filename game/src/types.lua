---@meta
-- Editor declarations for the subset of vendored APIs used by the game.
-- This file is not required at runtime.

---@class HumpVector
---@operator add(HumpVector): HumpVector
---@operator sub(HumpVector): HumpVector
---@operator mul(number): HumpVector
---@operator div(number): HumpVector
---@field x number
---@field y number
---@field clone fun(self: HumpVector): HumpVector
---@field unpack fun(self: HumpVector): number, number
---@field len fun(self: HumpVector): number
---@field normalized fun(self: HumpVector): HumpVector

---@class Anim8Animation
---@field timer number
---@field position integer Current frame (1-based).
---@field status "playing"|"paused"
---@field update fun(self: Anim8Animation, dt: number)
---@field draw fun(self: Anim8Animation, image: love.Image, x: number, y: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number)
---@field clone fun(self: Anim8Animation): Anim8Animation
---@field getDimensions fun(self: Anim8Animation): number, number
---@field flipH fun(self: Anim8Animation): Anim8Animation
---@field flipV fun(self: Anim8Animation): Anim8Animation
---@field pause fun(self: Anim8Animation)
---@field resume fun(self: Anim8Animation)
---@field gotoFrame fun(self: Anim8Animation, frame: integer)

---@class BatonInput
---@field update fun(self: BatonInput)
---@field pressed fun(self: BatonInput, control: string): boolean
---@field down fun(self: BatonInput, control: string): boolean
---@field get fun(self: BatonInput, control: string): number, number? Second value is present for paired controls.

---@class HCShape
---@field isPickup? boolean
---@field move fun(self: HCShape, dx: number, dy: number)
---@field moveTo fun(self: HCShape, x: number, y: number)
---@field center fun(self: HCShape): number, number
---@field collidesWith fun(self: HCShape, other: HCShape): boolean, number, number

---@class PickupContext
---@field game? GameState The current run, available to score and other game-wide effects.
---@field player Player The healer collecting the pickup.
---@field knight? Knight The current knight, if present.

---@alias PickupRarity "common"|"uncommon"|"rare"

---@class Item
---@field color? number[] RGB tint used by pickup particles.
---@field id string Stable item ID.
---@field name string Display name.
---@field rarity PickupRarity
---@field weight number Relative spawn weight; zero disables random spawning.
---@field description string
---@field imagePath string Image or horizontal sprite sheet, relative to game/.
---@field frames? string Anim8 frame range; defaults to "1-1" for static icons.
---@field frameDuration? number Defaults to 0.2 seconds; frames are 16x16.
---@field onCollect fun(pickup: Pickup, context: PickupContext) Effect owned by the item.
---@field soundEffectName? string Optional sound effect to play on collection; defaults to "Pickup".
