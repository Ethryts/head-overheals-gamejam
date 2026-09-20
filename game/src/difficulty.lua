---@class DifficultyStage
---@field at number Seconds into the run; stages are ordered, starting at zero.
---@field interval number Seconds between spawns.
---@field pool {id: string, weight: number}[] Creature or spawn-group IDs with selection weights.

---@type DifficultyStage[]
return {
  {
    at = 0,
    interval = 2.5,
    pool = {
      {id = "death_slime", weight = 1},
    },
  },
  {
    at = 30,
    interval = 2,
    pool = {
      {id = "death_slime", weight = 4},
      {id = "bloodshot_eye", weight = 1},
    },
  },
  {
    at = 40,
    interval = 2,
    pool = {
      {id = "death_slime", weight = 4},
      {id = "bloodshot_eye", weight = 1},
      {id = "brawny_ogre", weight = 0.1}, -- About 2% of spawns.
    },
  },
  {
    at = 60,
    interval = 1.5,
    pool = {
      {id = "death_slime", weight = 4},
      {id = "bloodshot_eye", weight = 1.5},
      {id = "ocular_watcher", weight = 0.5},
      {id = "ochre_jelly", weight = 2},
      {id = "brawny_ogre", weight = 0.4}, -- About 5% of spawns.
    },
  },
  {
    at = 90,
    interval = 1.5,
    pool = {
      {id = "death_slime", weight = 4},
      {id = "bloodshot_eye", weight = 1.5},
      {id = "ocular_watcher", weight = 0.5},
      {id = "ochre_jelly", weight = 2},
      {id = "brawny_ogre", weight = 0.4},
      {id = "humongous_ettin", weight = 0.2}, -- About 2% of spawns.
    },
  },
  {
    at = 120,
    interval = 1.5,
    pool = {
      {id = "death_slime", weight = 4},
      {id = "bloodshot_eye", weight = 1.5},
      {id = "ocular_watcher", weight = 0.5},
      {id = "ochre_jelly", weight = 2},
      {id = "brawny_ogre", weight = 0.4},
      {id = "humongous_ettin", weight = 0.2},
      {id = "slime_swarm", weight = 0.6},
      {id = "eye_swarm", weight = 0.15},
      {id = "ogre_escort", weight = 0.1},
    },
  },
}
