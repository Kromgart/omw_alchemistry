local core = require('openmw.core')
local world = require('openmw.world')
local types = require('openmw.types')

local potionVisuals = {
  { 'meshes/m/misc_potion_bargain_01.nif',   'icons/m/tx_potion_bargain_01.tga' },
  { 'meshes/m/misc_potion_cheap_01.nif',     'icons/m/tx_potion_cheap_01.tga' },
  { 'meshes/m/misc_potion_exclusive_01.nif', 'icons/m/tx_potion_exclusive_01.tga' },
  { 'meshes/m/misc_potion_fresh_01.nif',     'icons/m/tx_potion_fresh_01.tga' },
  { 'meshes/m/misc_potion_quality_01.nif',   'icons/m/tx_potion_quality_01.tga' },
  { 'meshes/m/misc_potion_standard_01.nif',  'icons/m/tx_potion_standard_01.tga' },
}

local function makePotionName(potionEffects)
  local function getEffectName(effect)
    if effect.id == core.magic.EFFECT_TYPE.RestoreFatigue then
      return 'Stamina'
    elseif effect.id == core.magic.EFFECT_TYPE.RestoreHealth then
      return 'Healing'
    elseif effect.id == core.magic.EFFECT_TYPE.RestoreMagicka then
      return 'Magicka'
    elseif effect.id == core.magic.EFFECT_TYPE.FortifyAttribute then
      return core.getGMST('sAttribute' .. effect.affectedAttribute)
    elseif effect.id == core.magic.EFFECT_TYPE.FortifySkill then
      return core.getGMST('sSkill' .. effect.affectedSkill)
    else
      return effect.name
    end
  end

  local potionNameBuf = { 'Potion of ', getEffectName(potionEffects[1].effect) }

  for i = 2, #potionEffects do
    potionNameBuf[i * 2 - 1] = ', '
    potionNameBuf[i * 2] = getEffectName(potionEffects[i].effect)
  end

  return table.concat(potionNameBuf)
end


local createdPotionRecords = {}


local function getPotionRecord(potionEffects, weight, price)
  assert(#potionEffects > 0)

  local potionRecordKey = {}
  for i, potionEffect in ipairs(potionEffects) do
    table.insert(potionRecordKey, potionEffect.effect.key)
    if potionEffect.effect.hasMagnitude then
      table.insert(potionRecordKey, potionEffect.magnitude)
    end

    if potionEffect.effect.hasDuration then
      table.insert(potionRecordKey, potionEffect.duration)
    end
  end

  table.insert(potionRecordKey, weight)
  table.insert(potionRecordKey, price)

  potionRecordKey = table.concat(potionRecordKey, '_')
  -- print("potionRecordKey: ", potionRecordKey)

  local potionRecordId = createdPotionRecords[potionRecordKey]
  if potionRecordId == nil then
    local visuals = potionVisuals[math.random(1, #potionVisuals)]
    local recordEffects = {}
    for i, pe in ipairs(potionEffects) do
      table.insert(recordEffects, {
        affectedAttribute = pe.effect.affectedAttribute or -1,
        affectedSkill = pe.effect.affectedSkill or -1,
        duration = pe.duration,
        magnitudeMin = pe.magnitude,
        magnitudeMax = pe.magnitude,
        id = pe.effect.id,
        area = 0,
        range = core.magic.RANGE.Self,
      })
    end

    local draftTable = {
      effects = recordEffects,
      model = visuals[1],
      icon = visuals[2],
      name = makePotionName(potionEffects),
      value = price,
      weight = weight,
      isAutocalc = false,
    }

    local recordDraft = types.Potion.createRecordDraft(draftTable)
    local potionRecord = world.createRecord(recordDraft)
    createdPotionRecords[potionRecordKey] = potionRecord.id
    print("Created potion record, id = ", potionRecord.id)
    return potionRecord
  else
    local potionRecord = types.Potion.record(potionRecordId)
    print("Cached potion record, id = ", potionRecord.id)
    return potionRecord
  end
end


local function createPotions(data)
  local playerInventory = types.Actor.inventory(world.players[1])
  for i, potionData in ipairs(data) do
    local record = getPotionRecord(potionData.effects, potionData.weight, potionData.price)
    local newItem = world.createObject(record.id, potionData.count)
    newItem:moveInto(playerInventory)
  end
end


local function saveData()
  local result = {
    createdPotionRecords = createdPotionRecords,
  }

  return result
end


local function loadData(data)
  if data == nil then
      createdPotionRecords = {}
  else
      createdPotionRecords = data.createdPotionRecords
      -- print("loaded potion records map")
      -- for k, v in pairs(createdPotionRecords) do
      --   print("  ", k,  " -> ", v)
      -- end
  end
end


local function initData()
  loadData(nil)
end


return {
  eventHandlers = {
    alchemistryCreatePotions = createPotions,
    alchemistryRemoveItem = function(data)
      -- HACK: comment out for easier testing
      data.gameObject:remove(data.count)
    end
  },
  engineHandlers = {
    onSave = saveData,
    onLoad = loadData,
    onInit = initData,
  }
}
