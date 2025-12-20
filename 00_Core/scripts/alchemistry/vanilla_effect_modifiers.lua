-- Modifiers for potion effects on top of vanilla formula
-- 
-- magnitude = (vanilla_magnitude ^ p) * k + b
-- duration  = (vanilla_duration ^ p) * k + b
--
-- Constraints:
-- 0 < p <= 1 (default 1)
-- k > 0 (default 1)
-- b: any number (default 0), negative number results in malus instead of bonus
--
-- p behaviour
-- p = 1 : linear scaling
-- 0 < p < 1 : non-linear (diminishing returns from higher values)

return {
  light = {
    -- magnitude divided by 4, then +5 pt constant bonus
    magnitude = { k = 0.25, b = 5 },
    -- duration doubled
    duration = { k = 2 }
  },

  invisibility = {
    -- duration x 1.5, then 10s bonus 
    duration = { k = 1.5, b = 10 }
  },
}
