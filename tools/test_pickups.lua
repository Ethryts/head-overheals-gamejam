-- Run from the repository root: luajit tools/test_pickups.lua
-- Uses real HC collisions and anim8 playback with mocked graphics/input.
package.path = "game/?.lua;game/?/init.lua;game/src/?.lua;" .. package.path
local imageLoads, draws = 0, {}
local function dimension(header, offset)
  local a,b,c,d = header:byte(offset, offset + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end
love = {
  mouse = {isDown = function() return false end, getPosition = function() return 0, 0 end},
  joystick = {getJoysticks = function() return {} end},
  graphics = {
    getDimensions = function() return 960, 540 end,
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
    polygon=function() end,rectangle=function() end,
    newFont=function() return {setFilter=function() end, getWidth=function(_, text) return #text*10 end} end,
    setFont=function() end,print=function() end,
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
-- Check proportions against the current item catalog, including newly added items.
local items=require('src.items')
local total=0
for _,item in ipairs(items) do total=total+item.weight end
local counts={}
for i=0,total*100-1 do
  local id=pickups:chooseItem((i+0.5)/(total*100)).id
  counts[id]=(counts[id] or 0)+1
end
for _,item in ipairs(items) do assert((counts[item.id] or 0)==item.weight*100) end
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
Player.update(player,0.5,require('src.heal_resource').new())
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
local visible, beforeDraw = 0, #draws
for _, item in ipairs(pickups.items) do if item:isVisible() then visible = visible+1 end end
pickups:draw(); assert(#draws == beforeDraw+visible)
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
local labelCount = #pickups.labels
local label = pickups.labels[labelCount]
assert(label.text == coin.item.name and label.x == coin.x, 'Collection names use the item and world position')
pickups:drawLabels(); pickups:drawLabels()
assert(label.age == 0, 'Drawing collection names does not advance time')
assert(not pickups:onCollect(coin, {player=player, knight=knight, game=game}))
assert(#pickups.labels == labelCount, 'Duplicate collection cannot add another name')
assert(not coin:collect({player=player,knight=knight,game=game}))
assert(game.score==1, 'The same coin must not award score twice')
pickups:create(require('src.items.gold_coin'),player.x,player.y)
pickups:checkCollected(player,knight,game)
assert(game.score==2, 'Coins accumulate score on the supplied game')
pickups:update(1.5)
assert(#pickups.labels == 0, 'Collection names expire promptly')
pickups:destroy(); HC.remove(player.shape)
assert(shapeCount()==0)
local Pickup = require('src.pickup')
local visual = Pickup.new(bootsItem, 100, 200, 6, 2)
visual:draw()
local firstY = draws[#draws][4]
visual:update(0.2); visual:draw()
assert(draws[#draws][4] ~= firstY, 'Pickup hovers as time advances')
local x, y = visual.shape:center()
assert(x == 100 and y == 200 and visual.y == 200, 'Hover never moves collection collision')
local age, lifetime = visual.age, visual.lifetime
visual:draw(); visual:draw()
assert(visual.age == age and visual.lifetime == lifetime, 'Drawing is safe while paused')
local function transitions(start)
  local count, previous = 0, nil
  for i = 0, 999 do
    visual.lifetime = start-i/1000
    local visible = visual:isVisible()
    if previous ~= nil and visible ~= previous then count = count+1 end
    previous = visible
  end
  return count
end
assert(transitions(6.1) == 0, 'No blinking before the final five seconds')
assert(transitions(1) > transitions(5), 'Blinking speeds up toward expiry')
for i = 1, 500 do
  visual.lifetime = 5-i/100
  if not visual:isVisible() then break end
end
assert(not visual:isVisible())
local count = #draws
visual:draw(); assert(#draws == count, 'Off phase hides the icon')
assert(visual:collect({player=player}), 'Blinking pickups remain collectible')
visual = Pickup.new(bootsItem, 0, 0, 0.1, 2)
visual:update(0.2)
assert(visual.removed and not visual:isVisible() and shapeCount() == 0)
print('Pickup checks passed: weights, effects, movement, caching, timing, limits, bounds and collision cleanup')
