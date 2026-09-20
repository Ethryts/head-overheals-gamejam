---@class DifficultyStage
---@field at number Seconds into the run; stages are ordered, starting at zero.
---@field interval number Seconds between spawns.
---@field pool {id: string, weight: number}[] Full weighted pool for this stage.

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
      {id = "bloodshot_eye", weight = 2},
      {id = "ochre_jelly", weight = 2},
      {id = "brawny_ogre", weight = 0.4}, -- About 5% of spawns.
    },
  },
}
