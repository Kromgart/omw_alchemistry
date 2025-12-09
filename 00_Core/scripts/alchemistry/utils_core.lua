local types = require('openmw.types')
local core = require('openmw.core')
local vfs = require('openmw.vfs')


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


local function loadLuaEffects()
  local result = {}
  local added = 0

  local patchModules = {}
  for patchFile in vfs.pathsWithPrefix('scripts/alchemistry/patches/') do
    local moduleName = string.match(patchFile, '^.+/([^/]+)%.lua$')
    if moduleName == nil then
      print("skipping ", luaFile)
    else
      added = added + 1
      patchModules[added] = moduleName
    end
  end
  added = 0

  table.sort(patchModules, function(x, y) return x < y end)

  for i, patchModule in ipairs(patchModules) do
    patchModule = 'scripts.alchemistry.patches.' .. patchModule
    print("Loading effects from " .. patchModule)

    local effectsTable = require(patchModule)
    for k, v in pairs(effectsTable) do
      for i = 1, #v do
        local eff = v[i]
        if 'string' == type(eff) then
          v[i] = string.lower(eff)
        else
          for j = 1, #eff do
            eff[j] = string.lower(eff[j])
          end
        end
      end
      result[string.lower(k)] = v
      added = added + 1
    end
  end

  print("Loaded ", added, " lua effects")

  local count = 0
  for k, v in pairs(result) do
    count = count + 1
  end

  print("Lua effects count: ", count)

  return result
end


-------------------------------------------------------------------------------



local module = {}



module.init = function(knownEffects, knownExperiments)
  local result = {}
  local added = 0
  local namesCache = {}

  local luaEffects = loadLuaEffects()
  local magicEffects = core.magic.effects.records


  for i, ingredientRecord in ipairs(types.Ingredient.records) do
    local ingredientRecordId = ingredientRecord.id

    local effects = {}
    local shortRecord = {
      id = ingredientRecordId,
      name = ingredientRecord.name,
      icon = ingredientRecord.icon,
      value = ingredientRecord.value,
      weight = ingredientRecord.weight,
      effects = effects,
    }


    local ingredientLuaEffects = luaEffects[ingredientRecordId]
    if ingredientLuaEffects == nil then
      error(string.format("%s has no associated lua effects", ingredientRecordId))
    end
    
    local knownIngredientEffects = knownEffects[ingredientRecordId]

    for j, effectEntry in ipairs(ingredientLuaEffects) do

      local isSimpleEffect = 'string' == type(effectEntry)
      local effectId = nil
      local effectKey = nil
      local affectedAttribute = nil
      local affectedSkill = nil

      if isSimpleEffect then
        effectId = effectEntry
        effectKey = effectId
      else
        effectId = effectEntry[1]

        if string.match(effectId, 'attribute$') ~= nil then
          affectedAttribute = effectEntry[2]
          effectKey = string.format("%s_%s", effectId, affectedAttribute)
        elseif string.match(effectId, 'skill$') ~= nil then
          affectedSkill = effectEntry[2]
          effectKey = string.format("%s_%s", effectId, affectedSkill)
        else
          error(string.format('%s: unsupported effect type %s', ingredientRecordId, effectId))
        end

      end

      local magicEffect = magicEffects[effectId]
      assert(magicEffect ~= nil)

      local effectName = namesCache[effectKey]
      if effectName == nil then
        if isSimpleEffect then
          effectName = magicEffect.name
        else
          effectName = makeCompositeEffectName(effectId, effectEntry[2])
        end

        namesCache[effectKey] = effectName
      end

      local isKnown = false
      if knownIngredientEffects ~= nil then
        isKnown = (true == knownIngredientEffects[effectKey])
      end

      effects[j] = {
        id = effectId,
        key = effectKey,
        name = effectName,
        icon = magicEffect.icon,
        hasDuration = magicEffect.hasDuration,
        hasMagnitude = magicEffect.hasMagnitude,
        baseCost = magicEffect.baseCost,
        harmful = magicEffect.harmful,
        known = isKnown,
        affectedAttribute = affectedAttribute,
        affectedSkill = affectedSkill,
      }
    end

    result[ingredientRecordId] = shortRecord
    added = added + 1
  end

  module.ingredientsCount = added
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
