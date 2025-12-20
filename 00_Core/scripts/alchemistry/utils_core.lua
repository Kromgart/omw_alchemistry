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

  print("Loaded lua effects for ", added, " ingredients")

  ----------------------------------------
  --               DEBUG
  -- local count = 0
  -- for k, v in pairs(result) do
  --   count = count + 1
  -- end

  -- print("Lua effects table size: ", count)
  ---------------------------------------

  return result
end


local function ingredientsCompare(x, y)
  return x.record.name < y.record.name
end


-------------------------------------------------------------------------------



local module = {}



module.init = function(knownEffects, knownExperiments)
  local effectsCache = {}
  local effectNamesCache = {}

  local luaEffects = loadLuaEffects()
  local magicEffects = core.magic.effects.records

  local function getIngredientEffects(ingredientRecord)
    -- Normalizing paths
    local ingredientHash = {
      string.gsub(string.lower(ingredientRecord.icon), '\\', '/'),
      string.gsub(string.lower(ingredientRecord.model), '\\', '/'),
    }
    local hashEntries = 2

    local ingredientLuaEffects = luaEffects[ingredientRecord.id]
    if ingredientLuaEffects == nil then
      error(string.format("%s has no associated lua effects", ingredientRecord.id))
    end

    for i, effectEntry in ipairs(ingredientLuaEffects) do
      if 'string' == type(effectEntry) then
        hashEntries = hashEntries + 1
        ingredientHash[hashEntries] = effectEntry
      else
        hashEntries = hashEntries + 1
        ingredientHash[hashEntries] = effectEntry[1]
        hashEntries = hashEntries + 1
        ingredientHash[hashEntries] = effectEntry[2]
      end
    end

    ingredientHash = table.concat(ingredientHash, '|')
    local effects = effectsCache[ingredientHash]
    if effects ~= nil then
      -- this item is a clone: same icon, model and effects
      -- All clones should point to the same table with effects (changing the table will affect all the clones)
      -- DEBUG
      -- print("Found clone ", ingredientRecord.id) --, ": ", ingredientHash)
      return effects, ingredientHash
    end

    effects = {}

    local knownIngredientEffects = knownEffects[ingredientRecord.id]

    for i, effectEntry in ipairs(ingredientLuaEffects) do
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
          error(string.format('%s: unsupported effect type %s', ingredientRecord.id, effectId))
        end
      end

      local magicEffect = magicEffects[effectId]
      assert(magicEffect ~= nil)

      local effectName = effectNamesCache[effectKey]
      if effectName == nil then
        if isSimpleEffect then
          effectName = magicEffect.name
        else
          effectName = makeCompositeEffectName(effectId, effectEntry[2])
        end

        effectNamesCache[effectKey] = effectName
      end

      local isKnown = false
      if knownIngredientEffects ~= nil then
        isKnown = (true == knownIngredientEffects[effectKey])
      end

      effects[i] = {
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

    effectsCache[ingredientHash] = effects
    return effects, ingredientHash
  end


  local result = {}
  local added = 0

  local clones = {}

  for i, ingredientRecord in ipairs(types.Ingredient.records) do
    local effects, ingredientHash = getIngredientEffects(ingredientRecord)
    local shortRecord = {
      id = ingredientRecord.id,
      name = ingredientRecord.name,
      icon = ingredientRecord.icon,
      value = ingredientRecord.value,
      weight = ingredientRecord.weight,
      effects = effects,
      hasScript = ingredientRecord.mwscript ~= nil,
    }

    local cs = clones[ingredientHash]
    if cs == nil then
      -- most common case, just one entry, no clone tracking yet
      clones[ingredientHash] = ingredientRecord.id
    elseif 'string' == type(cs) then
      -- got the first clone, need to keep track of them now
      local csArray = { cs, ingredientRecord.id }
      clones[ingredientHash] = csArray
      -- fix the first entry
      result[cs].clones = csArray
      shortRecord.clones = csArray
    else
      -- 2+ clones, already an array
      table.insert(clones, ingredientRecord.id)
      shortRecord.clones = cs
    end

    result[ingredientRecord.id] = shortRecord
    added = added + 1
  end

  module.ingredientsCount = added
  module.ingredientsData = result
  module.experimentsTable = knownExperiments
end



module.markExperiment = function(recordId1, recordId2)
  for i, id1 in ipairs(module.ingredientsData[recordId1].clones or { recordId1 }) do
    for i, id2 in ipairs(module.ingredientsData[recordId2].clones or { recordId2 }) do
      setOneExperiment(module.experimentsTable, id1, id2)
      setOneExperiment(module.experimentsTable, id2, id1)
    end
  end

  if module.onExperimentAdded ~= nil then
    module.onExperimentAdded(recordId1, recordId2)
  end
end



module.getAvailableItems = function(player)
  local inventory = types.Actor.inventory(player)
  local bestApparatus = {}

  for i, apparatusItem in ipairs(inventory:getAll(types.Apparatus)) do
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
  local added = 0
  local idata = module.ingredientsData

  for i, v in ipairs(inventory:getAll(types.Ingredient)) do
    local ingredientItem = {
      id = v.recordId,
      count = v.count,
      record = idata[v.recordId],
      spend = reduceIngredientStack,
      gameObject = v,
    }

    -- HACK: for utilsUI.itemList
    ingredientItem.icon = ingredientItem.record.icon

    added = added + 1
    availableIngredients[added] = ingredientItem
  end

  table.sort(availableIngredients, ingredientsCompare)

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
