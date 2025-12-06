local types = require('openmw.types')
local core = require('openmw.core')


local function makeCompositeEffectName(effectId, suffixId)
  assert(effectId ~= nil and suffixId ~= nil)

  local t = "%s %s"
  local gmst = core.getGMST
  local effects = core.magic.EFFECT_TYPE

  if effectId == effects.FortifyAttribute then
    return string.format(t, gmst('sFortify'), gmst('sAttribute' .. suffixId))
  elseif effectId == effects.RestoreAttribute then
    return string.format(t, gmst('sRestore'), gmst('sAttribute' .. suffixId))
  elseif effectId == effects.DrainAttribute then
    return string.format(t, gmst('sDrain'), gmst('sAttribute' .. suffixId))
  elseif effectId == effects.DamageAttribute then
    return string.format(t, gmst('sDamage'), gmst('sAttribute' .. suffixId))
  elseif effectId == effects.FortifySkill then
    return string.format(t, gmst('sFortify'), gmst('sSkill' .. suffixId))

  -- unlikely in potions
  elseif effectId == effects.RestoreSkill then
    return string.format(t, gmst('sRestore'), gmst('sSkill' .. suffixId))
  elseif effectId == effects.DrainSkill then
    return string.format(t, gmst('sDrain'), gmst('sSkill' .. suffixId))
  elseif effectId == effects.DamageSkill then
    return string.format(t, gmst('sDamage'), gmst('sSkill' .. suffixId))
  elseif effectId == effects.AbsorbSkill then
    return string.format(t, gmst('sAbsorb'), gmst('sSkill' .. suffixId))
  elseif effectId == effects.AbsorbAttribute then
    return string.format(t, gmst('sAbsorb'), gmst('sAttribute' .. suffixId))
  end
end


local function setOneExperiment(experimentsTable, mainRecordId, targetRecordId)
  local exp = experimentsTable[mainRecordId]
  if exp == nil then
    exp = { tableLength = 0 }
    experimentsTable[mainRecordId] = exp
  end

  if exp[targetRecordId] == nil then
    exp.tableLength = exp.tableLength + 1
  end

  exp[targetRecordId] = true
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


-------------------------------------------------------------------------------



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
        hasDuration = effect.effect.hasDuration,
        hasMagnitude = effect.effect.hasMagnitude,
        baseCost = effect.effect.baseCost,
        harmful = effect.effect.harmful,
        known = isKnown,
        affectedAttribute = effect.affectedAttribute,
        affectedSkill = effect.affectedSkill,
      })
    end

    result[ingredientRecord.id] = shortRecord
    added = added + 1
  end

  result.tableLength = added

  module.ingredientsData = result
  module.experimentsTable = knownExperiments
end



module.markExperiment = function(recordId1, recordId2)
  setOneExperiment(module.experimentsTable, recordId1, recordId2)
  setOneExperiment(module.experimentsTable, recordId2, recordId1)
end



module.getAvailableItems = function(player)
  local bestApparatus = {}

  for i, apparatusItem in ipairs(types.Actor.inventory(player):getAll(types.Apparatus)) do
    local apparatusRecord = types.Apparatus.record(apparatusItem.recordId)
    local currentBest = bestApparatus[apparatusRecord.type]
    if currentBest == nil then
      bestApparatus[apparatusRecord.type] = {
        name = apparatusRecord.name,
        icon = apparatusRecord.icon,
        quality = apparatusRecord.quality,
      }
    elseif currentBest.quality < apparatusRecord.quality then
      currentBest.name = apparatusRecord.name
      currentBest.icon = apparatusRecord.icon
      currentBest.quality = apparatusRecord.quality
    end
  end

  local availableIngredients = {}

  for i, v in ipairs(types.Actor.inventory(player):getAll(types.Ingredient)) do
    local ingredientItem = {
      id = v.recordId,
      count = v.count,
      record = module.ingredientsData[v.recordId],
      gameObject = v,
      spend = reduceIngredientStack,
    }

    -- HACK: for utilsUI.itemList
    ingredientItem.icon = ingredientItem.record.icon

    table.insert(availableIngredients, ingredientItem)
  end

  return {
    apparatus = bestApparatus,
    ingredients = availableIngredients,
  }
end


module.getCommonEffects = function(record1, record2)
  local result = {}
  local added = 0

  for i, e1 in ipairs(record1.effects) do
    for j, e2 in ipairs(record2.effects) do
      if e1.key == e2.key then
        added = added + 1
        result[added] = e1
        added = added + 1
        result[added] = e2
        break
      end
    end
  end

  if added > 0 then
    return result
  else
    return nil
  end
end



return module
