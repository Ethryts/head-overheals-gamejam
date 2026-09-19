local anim8 = require("lib.anim8")

local root = "assets/images/Basic Asset Pack/Basic Monster Animations/"
local sheets = {
  blinded_grimlock = "Blinded Grimlock/BlindedGrimlock.png",
  bloodshot_eye = "Bloodshot Eye/BloodshotEye.png",
  brawny_ogre = "Brawny Ogre/BrawnyOgre.png",
  crimson_slaad = "Crimson Slaad/CrimsonSlaad.png",
  crushing_cyclops = "Crushing Cyclops/CrushingCyclops.png",
  death_slime = "Death Slime/DeathSlime.png",
  fungal_myconid = "Fungal Myconid/FungalMyconid.png",
  humongous_ettin = "Humongous Ettin/HumongousEttin.png",
  murky_slaad = "Murky Slaad/MurkySlaad.png",
  ochre_jelly = "Ochre Jelly/OchreJelly.png",
  ocular_watcher = "Ocular Watcher/OcularWatcher.png",
  red_cap = "Red Cap/RedCap.png",
  shrieker_mushroom = "Shrieker Mushroom/ShriekerMushroom.png",
  stone_troll = "Stone Troll/StoneTroll.png",
  swamp_troll = "Swamp Troll/SwampTroll.png",
}
local images = {}
local animations = {}

---@param monsterId string
---@param frameDuration? number Seconds per frame; defaults to 0.2.
---@return love.Image image
---@return table<string, Anim8Animation> animations
function animations.loadMonster(monsterId, frameDuration)
  local path = assert(sheets[monsterId], "Unknown monster ID: " .. tostring(monsterId))
  local image = images[monsterId]
  if not image then
    image = love.graphics.newImage(root .. path)
    image:setFilter("nearest", "nearest")
    images[monsterId] = image
  end
  local grid = anim8.newGrid(16, 16, image:getWidth(), image:getHeight())
  -- Images are shared, but timers and flip state belong to each creature.
  return image, { idle = anim8.newAnimation(grid("1-4", 1), frameDuration or 0.2) }
end

return animations
