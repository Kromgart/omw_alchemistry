local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local types = require('openmw.types')
local core = require('openmw.core')
local utilsUI = require('scripts.alchemistry.utils_ui')
local utilsCore = require('scripts.alchemistry.utils_core')

local playSound = require('openmw.ambient').playSound
local v2 = require('openmw.util').vector2
local getGMST = core.getGMST

local getIntelligence = types.Actor.stats.attributes.intelligence
local getLuck         = types.Actor.stats.attributes.luck
local getAlchemy      = types.NPC.stats.skills.alchemy

local fPotionStrengthMult = getGMST('fPotionStrengthMult')
local fPotionT1MagMult    = getGMST('fPotionT1MagMult')
local fPotionT1DurMult    = getGMST('fPotionT1DurMult')
local iAlchemyMod         = getGMST('iAlchemyMod')



local ctx = nil
local wordsMapCache = nil
local lastFilter = nil
local hadNoCommon = true


local function noop()
end


local function redrawTab()
  ctx.tabElement:update()
end


local function clearAutocomplete()
  ctx.autocompleteElement.layout.clearTextSilent()
  lastFilter = nil
end


local function updateWordsMap(datasource)
  local wordsMap = {}
  for k, item in ipairs(datasource) do
    for i, effect in ipairs(item.record.effects) do
      if effect.known then
        local name = effect.name
        wordsMap[wordsMapCache[name]] = name
      end
    end
  end

  ctx.autocompleteElement.layout.setWordsMap(wordsMap)
end



local function getBaseModifier()
  local playerInt = getIntelligence(ctx.player).modified
  local playerLuck = getLuck(ctx.player).modified
  local playerAlchemy = getAlchemy(ctx.player).modified

  -- print(string.format("Int: %i, Luck: %i, Alchemy: %i", playerInt, playerLuck, playerAlchemy))

  return playerAlchemy + 0.1 * playerInt + 0.1 * playerLuck
end


local function getMortarMult()
  local mortar = ctx.slotMortar:getCurrentQuality()
  return getBaseModifier() * mortar * fPotionStrengthMult
end



--
-- NOTE
-- This is an accurate implementation of vanilla formulas.
-- I did not invent this shit. See here:
-- https://wiki.openmw.org/index.php?title=Research:Player_Craft_Skills#Potions
-- https://en.uesp.net/wiki/Morrowind:Alchemy#Alchemy_Formulas
--
local function calculateVanillaPotionEffect(effect, mortarMult, alembic, retort, calcinator)
  local baseCost = effect.baseCost
  local isHarmful = effect.harmful

  local magnitude = 1
  local duration = 1

  if effect.hasMagnitude then
    magnitude = mortarMult / fPotionT1MagMult / baseCost

    if effect.hasDuration then -- duration + magnitude
      duration = mortarMult / fPotionT1DurMult / baseCost

      if not isHarmful then
        if retort > 0 and calcinator > 0 then
          local k = 2 * retort + calcinator
          duration = duration + k
          magnitude = magnitude + k
        elseif retort > 0 then
          duration = duration + retort
          magnitude = magnitude + retort
        elseif calcinator > 0 then
          duration = duration + calcinator
          magnitude = magnitude + calcinator
        end
      else -- harmful
        if alembic > 0 and calcinator > 0 then
          local k = (2 * alembic + 3 * calcinator)
          duration = duration / k
          magnitude = magnitude / k
        elseif alembic > 0 then
          local k = 1 + alembic
          duration = duration / k
          magnitude = magnitude / k
        elseif calcinator > 0 then
          duration = duration + calcinator
          magnitude = magnitude + calcinator
        end
      end
    else -- only magnitude
      if not isHarmful then
        if retort > 0 and calcinator > 0 then
          magnitude = magnitude + 2 / 3 * (retort + calcinator) + 0.5
        elseif retort > 0 then
          magnitude = magnitude * (retort + 0.5)
        elseif calcinator > 0 then
          magnitude = magnitude * (calcinator + 0.5)
        end
      else -- harmful
        if alembic > 0 and calcinator > 0 then
          magnitude = magnitude / (2 * alembic + 3 * calcinator)
        elseif alembic > 0 then
          magnitude = magnitude / (1 + alembic)
        elseif calcinator > 0 then
          magnitude = magnitude * (calcinator + 0.5)
        end
      end
    end
  elseif effect.hasDuration then -- only duration
    duration = mortarMult / fPotionT1DurMult / baseCost

    if not isHarmful then
      if retort > 0 and calcinator > 0 then
        duration = duration + 2 / 3 * (retort + calcinator) + 0.5
      elseif retort > 0 then
        duration = duration * (retort + 0.5)
      elseif calcinator > 0 then
        duration = duration * (calcinator + 0.5)
      end
    else -- harmful
      if alembic > 0 and calcinator > 0 then
        duration = duration / (2 * alembic + 3 * calcinator)
      elseif alembic > 0 then
        duration = duration / (1 + alembic)
      elseif calcinator > 0 then
        duration = duration * (calcinator + 0.5)
      end
    end
  end

  magnitude = math.floor(magnitude + 0.5)
  duration = math.floor(duration + 0.5)

  return magnitude, duration
end


local function calculatePotionEffects()
  local potionEffects = {}
  local visibleEffectsKeys = {}

  -- need at least 2 ingredients to even have an effect
  if ctx.ingredientSlots[2]:getItemIcon() == nil then
    visibleEffectsKeys = {}
  else
    local mortarMult = getMortarMult() -- includes player stats too
    local alembic = ctx.slotAlembic:getCurrentQuality()
    local retort = ctx.slotRetort:getCurrentQuality()
    local calcinator = ctx.slotCalcinator:getCurrentQuality()

    visibleEffectsKeys = { mortarMult, alembic, retort, calcinator }

    local allEffects = {}

    for i, islot in ipairs(ctx.ingredientSlots) do
      local itemIcon = islot:getItemIcon()
      if itemIcon == nil then
        break
      end
      for j, effect in ipairs(itemIcon.itemData.record.effects) do
        local added = allEffects[effect.key]
        if added == nil then
          allEffects[effect.key] = { effect }
        else
          table.insert(added, effect)
          if #added == 2 then
            local magnitude, duration = calculateVanillaPotionEffect(effect, mortarMult, alembic, retort, calcinator)
            -- print(string.format("Calculated effect %s(%i pts, %i sec)", effect.key, magnitude, duration))
            if magnitude > 0 and duration > 0 then
              local visibleFast = added[1].known and added[2].known
              table.insert(potionEffects, {
                effect = effect,
                magnitude = magnitude,
                duration = duration,
                visible = visibleFast,
              })
              if visibleFast then
                table.insert(visibleEffectsKeys, effect.key)
              end
            end
          end
        end
      end
    end

    for i, potionEffect in ipairs(potionEffects) do
      -- should be rare
      if not potionEffect.visible then
        local known_count = 0
        for j, e in ipairs(allEffects[potionEffect.effect.key]) do
          if e.known then
            known_count = known_count + 1
          end
          if known_count == 2 then
            potionEffect.visible = true
            table.insert(visibleEffectsKeys, potionEffect.effect.key)
            break
          end
        end
      end
    end

  end

  ctx.potionEffects = potionEffects

  visibleEffectsKeys = table.concat(visibleEffectsKeys, '+')
  if ctx.lastVisibleEffectsKey ~= visibleEffectsKeys then
    -- print("Update potions effect list: " .. visibleEffectsKeys)
    ctx.lastVisibleEffectsKey = visibleEffectsKeys
    local newContent = ui.content {}
    for i, e in ipairs(potionEffects) do
      if e.visible then
        local effectWidget = utilsUI.newMagicEffectWidgetWrapping(e.effect, e.magnitude, e.duration, 190, 35)
        newContent:add(effectWidget)
      end
    end
    ctx.flexPotionEffects.content = newContent
    ctx.brewButtonsRow.props.visible = #newContent > 0
  end
end


local newDataSource = function(mutActiveIngredients, matchEffects)
  local result = {}
  local added = 0
  local activesCount = #mutActiveIngredients

  for i, ingredient in ipairs(ctx.ingredients) do
    if ingredient.count < 1 then
      goto next_ingredient
    end

    local rec = ingredient.record

    -- any actives or their clones should not be present in output
    for j = 1, activesCount do
      local active = mutActiveIngredients[j]
      if active == rec or (active == rec.id and type(active) == 'string') then
        -- this one will not be added to output
        -- shorten the list for less checks in the future
        for m = j, activesCount do
          mutActiveIngredients[m] = mutActiveIngredients[m + 1]
        end
        activesCount = activesCount - 1
        goto next_ingredient
      end
    end

    local keep = false
    for j, effect in ipairs(rec.effects) do
      if effect.known then
        if (matchEffects == nil or matchEffects[effect.key]) and (lastFilter == nil or lastFilter == effect.name) then
          keep = true
          break
        end
      end
    end

    if keep then
      added = added + 1
      result[added] = ingredient
      -- print("Added ", rec.name)
    end

    ::next_ingredient::
  end

  return result
end


local function filterIngredientsList()
  local actives = {}
  for i = 1, #ctx.ingredientSlots do
    local islot = ctx.ingredientSlots[i]
    local itemIcon = islot:getItemIcon()
    if itemIcon == nil then
      break
    end
    actives[i] = itemIcon.itemData.record
  end

  local activesCount = #actives
  -- print(string.format("Filtering for %i ingredients", activesCount))
  assert(activesCount >= 0 and activesCount <= 4)

  local datasource = nil
  if activesCount == 0 then
    datasource = newDataSource(actives)
  elseif activesCount == 4 then
    datasource = {}
  else -- 1, 2, 3
    local matchEffects = {}
    local cloneIdx = activesCount
    local haveAtLeastOneCommon = false

    for i = 1, activesCount do
      local active = actives[i]

      local clones = active.clones
      if clones ~= nil then
        -- add cloneIds to actives list (to filter them out)
        for j, cloneId in ipairs(clones) do
          cloneIdx = cloneIdx + 1
          actives[cloneIdx] = cloneId
        end
      end

      for j, effect in ipairs(active.effects) do
        if matchEffects[effect.key] then
          haveAtLeastOneCommon = true
          goto actives_processed
        end
        matchEffects[effect.key] = true
        -- print(string.format("Add match effect %s", effect.key))
      end
    end

    ::actives_processed::

    if haveAtLeastOneCommon then
      if hadNoCommon then
        hadNoCommon = false
        clearAutocomplete()
      end
      datasource = newDataSource(actives)
    else
      -- if not a single effect in the potion yet, filter out all
      -- ingredients that don't match anything in ingredient slots
      datasource = newDataSource(actives, matchEffects)
      hadNoCommon = true
    end
  end

  ctx.ingredientsList:setDataSource(datasource)
  updateWordsMap(datasource)
end



local function autocompleteFired(strValue)
  if strValue == lastFilter then
    return
  end

  lastFilter = strValue
  filterIngredientsList()
  redrawTab()
end



local function brewPotionsClick(amount)
  local function getSummedPower()
    local res = 0
    for i, effect in ipairs(ctx.potionEffects) do
      res = res + effect.magnitude
      res = res + effect.duration
    end
    return res
  end

  local refilter = false
  local playerAlchemy = getAlchemy(ctx.player).modified
  local potionPower = getSummedPower()
  local successChance = getBaseModifier()
  local ingredientsCount = 0

  for i, slot in ipairs(ctx.ingredientSlots) do
    local ingredientIcon = slot:getItemIcon()
    if ingredientIcon == nil then
      break
    end
    amount = math.min(amount, ingredientIcon.itemData.count)
    ingredientsCount = ingredientsCount + 1
  end

  local potionWeight = 0.5
  local potionEntry = nil
  local created = {}
  local createdCount = 0
  local skillUsedParam = {
    useType = I.SkillProgression.SKILL_USE_TYPES.Alchemy_CreatePotion,
    scale = 0.5,
  }

  for i = 1, amount do
    local roll = math.random(1, 100)
    if roll <= successChance then
      createdCount = createdCount + 1

      if potionEntry == nil then
        potionEntry = {
          effects = ctx.potionEffects,
          weight = potionWeight,
          -- vanilla price
          price = getMortarMult() * iAlchemyMod,
          count = 1
        }
        table.insert(created, potionEntry)
      else
        potionEntry.count = potionEntry.count + 1
      end

      I.SkillProgression.skillUsed('alchemy', skillUsedParam)
      local newAlchemy = getAlchemy(ctx.player).modified
      if newAlchemy ~= playerAlchemy then
        playerAlchemy = newAlchemy
        successChance = getBaseModifier()
        calculatePotionEffects()
        local newPower = getSummedPower()
        if potionPower ~= newPower then
          potionPower = newPower
          potionEntry = nil
        end
      end
    end
  end

  if createdCount > 0 then
    playSound('potion success')

    local msg = getGMST('sPotionSuccess')
    if createdCount > 1 then
      msg = string.format("%s (x%i)", msg, createdCount)
    end
    ui.showMessage(msg)

    if ingredientsCount == 2 then
      local rec1 = ctx.ingredientSlots[1]:getItemIcon().itemData.record
      local rec2 = ctx.ingredientSlots[2]:getItemIcon().itemData.record

      -- in case this combination was not tested (but was possible because of matching effects)
      utilsCore.markExperiment(rec1.id, rec2.id)
      for i, e in ipairs(utilsCore.getCommonEffects(rec1, rec2) or {}) do
        e.known = true
      end
    end

    core.sendGlobalEvent("alchemistryCreatePotions", created)
  else
    playSound('potion fail')

    local msg = getGMST('sNotifyMessage8')
    if amount > 1 then
      msg = string.format("%s (x%i)", msg, amount)
    end

    ui.showMessage(msg)
  end

  for i, slot in ipairs(ctx.ingredientSlots) do
    local ingredientIcon = slot:getItemIcon()
    if ingredientIcon ~= nil then
      print(string.format("spend %i of %s", amount, ingredientIcon.itemData.record.name))
      ingredientIcon.itemData:spend(amount)
      local newCount = ingredientIcon.itemData.count
      ingredientIcon:setCount(newCount)
      if newCount == 0 then
        slot:setItemIcon(nil)
        refilter = true
      end
    end
  end

  if refilter then
    filterIngredientsList()
    calculatePotionEffects()
  end

  redrawTab()
end


local function ingredientSlotClicked(mouseEvent, slot)
  local itemIcon = slot:getItemIcon()
  if itemIcon == nil then
    return
  end

  playSound('Item Ingredient Down')
  local shifting = false
  for i, islot in ipairs(ctx.ingredientSlots) do
    if shifting then
      ctx.ingredientSlots[i - 1]:setItemIcon(islot:getItemIcon())
    elseif islot == slot then
      shifting = true
    end
  end

  ctx.ingredientSlots[#ctx.ingredientSlots]:setItemIcon(nil)
  filterIngredientsList()
  ctx.updateTooltip(nil)
  calculatePotionEffects()
  redrawTab()
end


local function ingredientClicked(mouseEvent, sender)
  if not ctx.slotMortar.enabled then
    -- can't do alchemy without mortar-and-pestle
    ui.showMessage(string.format('%s %s', getGMST('sNotifyMessage45'), getGMST('sSkillAlchemy')))
    return
  end

  ctx.lastClickedIngredient = sender
  ctx.updateTooltip(nil)
  local clickedIngredient = sender.itemData

  local freeSlot = nil
  for i, slot in ipairs(ctx.ingredientSlots) do
    if slot:getItemIcon() == nil then
      freeSlot = slot
      break
    end
  end

  assert(freeSlot ~= nil, "No free ingredient slots, ingredient list must have been empty")

  playSound('Item Ingredient Down')
  freeSlot:setItemIcon(sender)
  filterIngredientsList()
  calculatePotionEffects()
  redrawTab()
  -- print("Added ingredient " .. clickedIngredient.record.name)
end


local function ingredientIconMouseMoved(mouseEvent, sender)
  if ctx.lastTooltipActivator ~= sender then
    if sender ~= nil then
      ctx.tooltipContent = utilsUI.newIngredientTooltipContent(sender.itemData.record)
      -- print("new tooltip target: " .. sender.itemData.record.name)
    end
    ctx.lastTooltipActivator = sender
  end
  ctx.updateTooltip(ctx.tooltipContent, mouseEvent.position)
end


local function ingredientSlotMouseMoved(mouseEvent, slot, itemIcon)
  if itemIcon ~= nil then
    ingredientIconMouseMoved(mouseEvent, itemIcon)
  end
end


local function makeHeader(text)
  return {
    type = ui.TYPE.Text,
    template = I.MWUI.templates.textNormal,
    props = {
      text = text,
      textAlignV = ui.ALIGNMENT.Center,
      autoSize = false,
      size = v2(0, 35),
      relativeSize = v2(1, 0),
    }
  }
end


local function apparatusSlotMouseMoved(mouseEvent, slot, itemIcon)
  if slot ~= nil and itemIcon ~= nil then
    if ctx.lastTooltipActivator ~= slot then

      if slot.tooltipContent == nil then
        slot.tooltipContent = {
          type = ui.TYPE.Flex,
          props = {
            horizontal = false,
            arrange = ui.ALIGNMENT.Center,
          },
          content = ui.content {
            {
              type = ui.TYPE.Text,
              template = I.MWUI.templates.textHeader,
              props = { text = slot.apparatusData.name },
            },
            utilsUI.spacerRow5,
            {
              type = ui.TYPE.Text,
              template = I.MWUI.templates.textNormal,
              props = { text = string.format("%s: %.1f", getGMST('sQuality'), slot.apparatusData.quality) },
            }
          }
        }
      end
      ctx.tooltipContent = slot.tooltipContent
      ctx.lastTooltipActivator = slot
    end
    ctx.updateTooltip(ctx.tooltipContent, mouseEvent.position)
  end
end


local function apparatusSlotClicked(mouseEvent, slot)
  if slot == ctx.slotMortar then
    -- mortar-and-pestle is required and can't be toggled
    return
  end

  playSound('Item Ingredient Down')
  if slot.enabled then
    slot.enabled = false
    slot:setItemIcon(nil)
  else
    slot.enabled = true
    slot:setItemIcon(slot.apparatusIcon)
  end

  calculatePotionEffects()
  redrawTab()
end


local function makeApparatusSlot(id, type)
  local slot = nil

  local apparatusItem = ctx.apparatus[type]
  if apparatusItem ~= nil then
    slot = utilsUI.newItemSlot(id, apparatusSlotClicked, apparatusSlotMouseMoved)
    slot.apparatusData = apparatusItem
    slot.apparatusIcon = utilsUI.newItemIcon(apparatusItem.icon, 1)
    slot.enabled = true
    slot:setItemIcon(slot.apparatusIcon)
  else
    slot = utilsUI.newItemSlot(id, noop, noop)
  end

  slot.getCurrentQuality = function(self)
    if self.enabled then
      return self.apparatusData.quality
    else
      return 0
    end
  end

  return slot
end


local function newTabLayout()
  ctx.ingredientSlots[1] = utilsUI.newItemSlot('slot_ingredient_1', ingredientSlotClicked, ingredientSlotMouseMoved)
  ctx.ingredientSlots[2] = utilsUI.newItemSlot('slot_ingredient_2', ingredientSlotClicked, ingredientSlotMouseMoved)
  ctx.ingredientSlots[3] = utilsUI.newItemSlot('slot_ingredient_3', ingredientSlotClicked, ingredientSlotMouseMoved)
  ctx.ingredientSlots[4] = utilsUI.newItemSlot('slot_ingredient_4', ingredientSlotClicked, ingredientSlotMouseMoved)

  local ingredientSlotsRow = {
    type = ui.TYPE.Flex,
    props = { horizontal = true },
    content = ui.content {
      ctx.ingredientSlots[1],
      utilsUI.spacerColumn20,
      ctx.ingredientSlots[2],
      utilsUI.spacerColumn20,
      ctx.ingredientSlots[3],
      utilsUI.spacerColumn20,
      ctx.ingredientSlots[4],
    }
  }

  ctx.slotMortar     = makeApparatusSlot('slot_mortar',     types.Apparatus.TYPE.MortarPestle)
  ctx.slotAlembic    = makeApparatusSlot('slot_alembic',    types.Apparatus.TYPE.Alembic)
  ctx.slotRetort     = makeApparatusSlot('slot_retort',     types.Apparatus.TYPE.Retort)
  ctx.slotCalcinator = makeApparatusSlot('slot_calcinator', types.Apparatus.TYPE.Calcinator)

  local apparatusSlotsRow = {
    type = ui.TYPE.Flex,
    props = { horizontal = true },
    content = ui.content {
      ctx.slotMortar,
      utilsUI.spacerColumn20,
      ctx.slotAlembic,
      utilsUI.spacerColumn20,
      ctx.slotRetort,
      utilsUI.spacerColumn20,
      ctx.slotCalcinator,
    }
  }

  local ingredientsList = utilsUI.newItemList {
    height = 4,
    width = 12,
    dataSource = {},
    fnItemClicked = ingredientClicked,
    fnItemMouseMoved = function(mouseEvent, sender)
      -- HACK: when clicking there are 2 events sent: mouseClick and then mouseMove (which should be ignored)
      if ctx.lastClickedIngredient ~= sender then
        ingredientIconMouseMoved(mouseEvent, sender)
      end
    end,
    redraw = redrawTab,
  }

  ctx.ingredientsList = ingredientsList

  ctx.flexPotionEffects = {
    type = ui.TYPE.Flex,
    props = {
      horizontal = false,
      autoSize = false,
      relativeSize = v2(1, 1),
    },
    content = ui.content {
      -- list of potion effects
    }
  }

  ctx.brewButtonsRow = {
    type = ui.TYPE.Flex,
    props = {
      horizontal = true,
      visible = false,
    },
    content = ui.content {
      utilsUI.newButton('Brew 1', function() brewPotionsClick(1) end, true),
      utilsUI.spacerColumn3,
      utilsUI.newButton('Brew 5', function() brewPotionsClick(5) end, true),
      utilsUI.spacerColumn3,
      utilsUI.newButton('Brew 20', function() brewPotionsClick(20) end, true),
    }
  }

  return {
    type = ui.TYPE.Flex,
    props = { horizontal = false },
    content = ui.content {
      {
        type = ui.TYPE.Flex,
        props = { horizontal = true },
        content = ui.content {
          {
            type = ui.TYPE.Flex,
            props = { horizontal = false },
            content = ui.content {
              makeHeader("Apparatus:"),
              apparatusSlotsRow,
              makeHeader("Ingredients:"),
              ingredientSlotsRow,
              makeHeader("Effects filter:"),
              ctx.autocompleteElement,
            }
          },
          utilsUI.spacerColumn40,
          {
            type = ui.TYPE.Flex,
            props = { horizontal = false },
            content = ui.content {
              makeHeader("Expected effects:"),
              {
                type = ui.TYPE.Widget,
                template = I.MWUI.templates.borders,
                props = {
                  size = v2(204, 190),
                },
                content = ui.content { ctx.flexPotionEffects }
              },
            }
          }
        }
      },
      utilsUI.spacerRow20,
      ingredientsList,
      ctx.brewButtonsRow,
    }
  }
end


local function getNormalizedIngredients(inputIngredients)
  local result = {}
  local added = 0

  for i, v in ipairs(inputIngredients) do
    if v.count > 0 then
      for j, e in ipairs(v.record.effects) do
        if e.known then
          added = added + 1
          result[added] = v
          break
        end
      end
    end
  end

  return result
end


local function createTab(fnUpdateTooltip, alchemyItems, player)
  assert(ctx == nil, "Attempting to create a tab when its context still exists, this should never happen")

  hadNoCommon = true

  ctx = {
    apparatus = alchemyItems.apparatus,
    -- we need our own copy to mutate
    ingredients = getNormalizedIngredients(alchemyItems.ingredients),
    player = player,
    updateTooltip = fnUpdateTooltip,
    ingredientSlots = {},
  }

  ctx.autocompleteElement = utilsUI.newAutocomplete(240, autocompleteFired, {})

  local datasource = {}
  wordsMapCache = {}

  for i, item in ipairs(ctx.ingredients) do
    datasource[i] = item
    for i, effect in ipairs(item.record.effects) do
      if effect.known then
        local name = effect.name
        wordsMapCache[name] = string.lower(name)
      end
    end
  end

  updateWordsMap(datasource)
  ctx.tabElement = ui.create(newTabLayout())
  ctx.ingredientsList:setDataSource(datasource)

  return ctx.tabElement
end

local function destroyTab()
  assert(ctx ~= nil, "Attempting to destroy a tab when it doesn't exist")
  ctx.autocompleteElement:destroy()
  ctx.tabElement:destroy()
  ctx = nil
  wordsMapCache = nil
  lastFilter = nil
end

return {
  create = createTab,
  destroy = destroyTab,
}
