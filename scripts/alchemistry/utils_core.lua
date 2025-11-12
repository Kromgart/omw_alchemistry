local types = require('openmw.types')

local function initIngredients()
  local result = {}

  for i, v in ipairs(types.Ingredient.records) do
    idata = {
      name = v.name,
      icon = v.icon,
      value = v.value,
      weight = v.weight,
      effects = {}
    }

    for j, effect in ipairs(v.effects) do
      local effect_key = nil
      if effect.affectedAttribute ~= nil then
        effect_key = effect.id .. '_' .. effect.affectedAttribute
      elseif effect.affectedSkill ~= nil then
        effect_key = effect.id .. '_' .. effect.affectedSkill
      else
        effect_key = effect.id
      end

      idata.effects[effect_key] = {
        id = effect.id, intensity = 2, duration = 2, known = true
      }
    end

    result[v.id] = idata
  end

  return result
end


local module = {}

module.ingredientsData = initIngredients()

module.getAvailableItems = function(player)
  local result = {
    apparatus = {
      mortar = 1.0,
      calcinator = 1.0,
      alembic = 1.0,
      retort = 1.0
    },
    ingredients = {}
  }

  for i, v in ipairs(types.Actor.inventory(player):getAll(types.Ingredient)) do
    -- result.ingredients[v.recordId] = v.count
    table.insert(result.ingredients, {
      id = v.recordId,
      count = v.count
    })
  end

  return result
end

module.getCommonEffects = function(...)
  local arg = {...}
  local result = {}
  local found = false

  for i = 1, (#arg - 1) do
    for j = (i + 1), #arg do
      local e2 = arg[j].effects

      for key1, e1 in pairs(arg[i].effects) do
        for key2, e2 in pairs(arg[j].effects) do
          if key1 == key2 then
            if result[key1] == nil then
              result[key1] = { e1, e2 }
            else
              table.insert(result[key1], e2)
            end
            found = true
          end
        end
      end
    end
  end

  if found then
    return result
  else
    return nil
  end
end


return module
