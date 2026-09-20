---@class SpawnGroup
---@field id string ID usable in a difficulty pool.
---@field spacing number World pixels between members in the formation.
---@field members {id: string, count: integer}[] Creature IDs, not nested groups.

-- Add another typed group module here to make its ID available to spawn pools.
local groups = {}
for _, group in ipairs({
  (require("spawns.slime_swarm")),
  (require("spawns.eye_swarm")),
  (require("spawns.ogre_escort")),
}) do
  groups[group.id] = group
end
return groups
