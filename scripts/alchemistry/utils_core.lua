local types = require('openmw.types')
local core = require('openmw.core')


local function makeCompositeEffectName(effectId, suffixId)
  local prefix = 'nil'
  local suffix = 'nil'

  if effectId == 'drainattribute' then
    prefix = core.getGMST('sDrain')
    suffix = core.getGMST('sAttribute' .. suffixId)
  elseif effectId == 'drainskill' then
    prefix = core.getGMST('sDrain')
    suffix = core.getGMST('sSkill' .. suffixId)
  elseif effectId == 'damageattribute' then
    prefix = core.getGMST('sDamage')
    suffix = core.getGMST('sAttribute' .. suffixId)
  elseif effectId == 'damageskill' then
    prefix = core.getGMST('sDamage')
    suffix = core.getGMST('sSkill' .. suffixId)
  elseif effectId == 'absorbattribute' then
    prefix = core.getGMST('sAbsorb')
    suffix = core.getGMST('sAttribute' .. suffixId)
  elseif effectId == 'absorbskill' then
    prefix = core.getGMST('sAbsorb')
    suffix = core.getGMST('sSkill' .. suffixId)
  elseif effectId == 'restoreattribute' then
    prefix = core.getGMST('sRestore')
    suffix = core.getGMST('sAttribute' .. suffixId)
  elseif effectId == 'restoreskill' then
    prefix = core.getGMST('sRestore')
    suffix = core.getGMST('sSkill' .. suffixId)
  elseif effectId == 'fortifyattribute' then
    prefix = core.getGMST('sFortify')
    suffix = core.getGMST('sAttribute' .. suffixId)
  elseif effectId == 'fortifyskill' then
    prefix = core.getGMST('sFortify')
    suffix = core.getGMST('sSkill' .. suffixId)
  end

  return prefix .. ' ' .. suffix

end


local module = {}


module.initIngredients = function(knownEffects, knownExperiments)
  local result = {}
  local added = 0
  local namesCache = {}

  for i, ingredientRecord in ipairs(types.Ingredient.records) do
    local shortRecord = {
      id = ingredientRecord.id,
      name = ingredientRecord.name,
      icon = ingredientRecord.icon,
      value = ingredientRecord.value,
      weight = ingredientRecord.weight,
      effects = {}
    }

    local knownIngredientEffects = knownEffects[ingredientRecord.id]

    for j, effect in ipairs(ingredientRecord.effects) do

      local effectKey = nil
      if effect.affectedAttribute ~= nil then
        effectKey = effect.id .. '_' .. effect.affectedAttribute
      elseif effect.affectedSkill ~= nil then
        effectKey = effect.id .. '_' .. effect.affectedSkill
      else
        effectKey = effect.id
      end
      
      local effectName = namesCache[effectKey]
      if effectName == nil then
        if effect.affectedAttribute ~= nil then
          effectName = makeCompositeEffectName(effect.id, effect.affectedAttribute)
        elseif effect.affectedSkill ~= nil then
          effectName = makeCompositeEffectName(effect.id, effect.affectedSkill)
        else
          effectName = effect.effect.name
        end 
        namesCache[effectKey] = effectName
      end

      local isKnown = false
      if knownIngredientEffects ~= nil then
        isKnown = (true == knownIngredientEffects[effectKey])
      end

      table.insert(shortRecord.effects, {
        id = effect.id,
        key = effectKey,
        name = effectName,
        icon = effect.effect.icon,
        known = isKnown,
      })
    end

    result[ingredientRecord.id] = shortRecord
    added = added + 1
  end

  result.tableLength = added

  module.ingredientsData = result
  module.experimentsTable = knownExperiments
end



local function reduceIngredientStack(ingredientItem, removeCount)
  local newCount = ingredientItem.count - removeCount
  assert(newCount >= 0, "Tried to remove more ingredients than there are in the stack")

  ingredientItem.count = newCount

  core.sendGlobalEvent("alchemistryRemoveItem", {
    gameObject = ingredientItem.gameObject,
    count = removeCount,
  })
end


module.getAvailableItems = function(player)
  local result = {
    apparatus = {
      mortar = 1.0,
      calcinator = 1.0,
      alembic = 1.0,
      retort = 1.0
    },
    ingredients = {},
  }

  for i, v in ipairs(types.Actor.inventory(player):getAll(types.Ingredient)) do
    local ingredientItem = {
      id = v.recordId,
      count = v.count,
      record = module.ingredientsData[v.recordId],
      gameObject = v,
      spend = reduceIngredientStack,
    }

    -- for itemLists:
    ingredientItem.icon = ingredientItem.record.icon

    table.insert(result.ingredients, ingredientItem)
  end

  return result
end

module.getCommonEffects = function(...)
  local arg = {...}
  local result = {}
  local found = false

  for i = 1, (#arg - 1) do
    for j = (i + 1), #arg do

      for k1, e1 in ipairs(arg[i].effects) do
        for k2, e2 in ipairs(arg[j].effects) do
          if e1.name == e2.name then
            if result[e1.name] == nil then
              result[e1.name] = { e1, e2 }
            else
              table.insert(result[e1.name], e2)
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
