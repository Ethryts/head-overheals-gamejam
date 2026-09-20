-- Run from the repository root: luajit tools/test_pickups.lua
-- Uses real HC collisions and anim8 playback with mocked graphics/input.
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;" .. package.path
local imageLoads, draws = 0, {}
local function dimension(header, offset)
  local a,b,c,d = header:byte(offset, offset + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end
love = {
  joystick = {getJoysticks = function() return {} end},
  graphics = {
    newImage = function(path)
      local file = assert(io.open("game/" .. path, "rb"))
      local header = file:read(24); file:close()
      local w,h = dimension(header,17),dimension(header,21)
      imageLoads = imageLoads + 1
      return {getWidth=function() return w end,getHeight=function() return h end,
        setFilter=function() end}
    end,
    newQuad = function(x,y,w,h)
      return {getViewport=function() return x,y,w,h end}
    end,
    push=function() end,pop=function() end,setColor=function() end,
    draw=function(...) draws[#draws+1]={...} end,
  },
}
package.loaded['lib.baton'] = {new=function()
  return {update=function() end, get=function(_,name)
    if name=='move' then return 1,0 end
    return 0,0
  end, down=function() return false end, pressed=function() return false end}
end}
local HC = require('lib.HC')
-- Player and beam now share the sound service through the game state.
package.loaded['gamestate.deps'] = {Gamestate = {soundEffectsSystem = {
  playWithLowPass = function() end, playSoundEffect = function() end, stopSoundEffect = function() end,
}}}
local Player = require('src.player')
local Knight = require('src.knight')
local Pickups = require('src.pickups')
local bootsItem = require('src.items.healer_boots')
local featherItem = require('src.items.knight_feather')
local hasteItem = require('src.items.party_haste')
local player, knight = Player.new(1000,-500), Knight.new(1000,-500)
player.shape = HC.circle(player.x,player.y,16)
local function shapeCount()
  local count=0
  for _ in pairs(HC.hash():shapes()) do count=count+1 end
  return count
end
local pickups=Pickups.new(player,{intervalMin=1,intervalMax=1,maxItems=4})
assert(player.stats.speed==200 and knight.stats.speed==120)
for _, item in ipairs(require('src.items')) do
  assert(getmetatable(item)==nil, 'Items are plain typed tables')
  assert(type(item.onCollect)=='function' and type(item.id)=='string')
end
assert(pickups:chooseItem(0).id=='healer_boots')
assert(pickups:chooseItem(69.999/170).id=='healer_boots')
assert(pickups:chooseItem(70/170).id=='knight_feather')
assert(pickups:chooseItem(95/170).id=='party_haste')
assert(pickups:chooseItem(0.99999).id=='gold_coin')
local counts={}
for i=0,16999 do
  local id=pickups:chooseItem((i+0.5)/17000).id
  counts[id]=(counts[id] or 0)+1
end
assert(counts.healer_boots==7000 and counts.knight_feather==2500 and counts.party_haste==500 and counts.gold_coin==7000)
local startLoads=imageLoads
local boots=pickups:create(bootsItem,player.x,player.y)
local boots2=pickups:create(bootsItem,player.x+100,player.y)
assert(boots.item==bootsItem)
assert(boots.image==boots2.image and boots.animation~=boots2.animation)
assert(imageLoads==startLoads+1,'Item artwork is cached')
pickups:checkCollected(player,knight)
assert(player.stats.speed==210 and #pickups.items==1 and shapeCount()==2)
assert(not boots:collect({player=player,knight=knight}),'Collection is once only')
assert(player.stats.speed==210)
pickups:create(featherItem,player.x,player.y)
pickups:create(hasteItem,player.x,player.y)
pickups:checkCollected(player,knight)
assert(player.stats.speed==220 and knight.stats.speed==140)
local oldX=player.x
Player.update(player,0.5)
assert(player.x==oldX+110,'Player movement uses current stats')
knight.state='moving'
knight.destination=knight.position + require('lib.hump.vector')(1000,0)
local knightX=knight.position.x
knight:update(0.5,{getAll=function() return {} end},player)
assert(knight.position.x==knightX+70,'Knight movement uses current stats')
pickups:destroy(); pickups:destroy()
assert(shapeCount()==1)
local fresh=Player.new(0,0)
assert(fresh.stats.speed==200,'Stats are independent between actors/runs')
pickups=Pickups.new(player,{intervalMin=1,intervalMax=1,maxItems=4,lifetime=2})
pickups:update(0.5); assert(#pickups.items==0)
pickups:update(0.5); assert(#pickups.items==2)
pickups:update(1); assert(#pickups.items==4)
assert(pickups:create(hasteItem,0,0)==nil)
for _,item in ipairs(pickups.items) do
  assert(math.abs(item.x-player.x)<=960*1.25/2)
  assert(math.abs(item.y-player.y)<=540*1.25/2)
end
pickups:draw(); assert(#draws>=4)
assert(draws[#draws][8]==8 and draws[#draws][9]==8,'Icons draw from their centers')
pickups.batchSize=0
pickups:update(3)
assert(#pickups.items==0 and shapeCount()==1,'Expiry removes HC shapes')
local lone=pickups:create(featherItem,player.x,player.y)
pickups:checkCollected(player)
assert(lone.removed,'Knight-target pickup handles missing knight')
local game = {score=0}
local coin = pickups:create(require('src.items.gold_coin'),player.x,player.y)
pickups:checkCollected(player,knight,game)
assert(game.score==1 and coin.removed and #pickups.items==0)
assert(not coin:collect({player=player,knight=knight,game=game}))
assert(game.score==1, 'The same coin must not award score twice')
pickups:create(require('src.items.gold_coin'),player.x,player.y)
pickups:checkCollected(player,knight,game)
assert(game.score==2, 'Coins accumulate score on the supplied game')
pickups:destroy(); HC.remove(player.shape)
assert(shapeCount()==0)
print('Pickup checks passed: weights, effects, movement, caching, timing, limits, bounds and collision cleanup')
