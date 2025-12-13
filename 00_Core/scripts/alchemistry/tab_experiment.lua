local ambient = require('openmw.ambient')
local ui = require('openmw.ui')
local async = require('openmw.async')
local I = require('openmw.interfaces')
local v2 = require('openmw.util').vector2
local self = require('openmw.self')
local types = require('openmw.types')
local core = require('openmw.core')
local utilsUI = require('scripts.alchemistry.utils_ui')
local utilsCore = require('scripts.alchemistry.utils_core')


local maxPossibleExperiments = nil -- is set on tab creation

-- runtime lazy cache for showing only relevant stuff on this tab
local untestedCombinations = nil

local function updateUntestedCombinations(ingredients, experiments)
  local count = #ingredients
  local firstRun = untestedCombinations == nil
  if firstRun then
    untestedCombinations = {}
  end

  for i = 1, count do
    local id = ingredients[i].record.id

    local exp = experiments[id]
    if exp ~= nil and exp.tableLength == maxPossibleExperiments then
      -- tested with ALL ingredients
      goto next_ingredient
    end

    local matches = untestedCombinations[id]
    if matches ~= nil then
      -- don't touch cached ones, they will be updated by newcomers
      goto next_ingredient
    end

    -- A newcomer in the cache: check for done experiments with ALL CACHED entries
    matches = {}
    untestedCombinations[id] = matches

    for m = 1, i - 1 do
      local idPrevious = ingredients[m].record.id
      if exp == nil or exp[idPrevious] ~= true then
        -- INVARIANT untestedCombinations[idPrevious] ~= nil
        -- it was ensured on previous iteration of the outer for loop
        untestedCombinations[idPrevious][id] = true
        matches[idPrevious] = true
      end
    end

    if firstRun then
      -- there is nothing to do for the following ingredients:
      -- on the first run the untestedCombinations[idFollowing] is always nil
      goto next_ingredient
    end

    for m = i + 1, count do
      local idFollowing = ingredients[m].record.id
      local followingMatches = untestedCombinations[idFollowing]
      if followingMatches ~= nil then
        -- this one will be skipped normally, so we add ourself in it now
        -- if it IS nil, then it is also a new item for the cache and will be processed as this one
        if exp == nil or exp[followingId] ~= true then
          untestedCombinations[idFollowing][id] = true
          matches[idFollowing] = true
        end
      end
    end

    ::next_ingredient::
  end

end


local ctx = nil

-- local redrawCount = 0

local function redraw()
  -- print(string.format("-- REDRAW -- %i", redrawCount))
  -- redrawCount = redrawCount + 1
  ctx.tabElement:update()
end


local function getSlot()
  return ctx.tabElement.layout.content[1].content[1]
end


local function setResultHeader(txt1, txt2)
  local container = ctx.tabElement.layout.content[1].content[3]
  local equals = ctx.tabElement.layout.content[1].content[5]
  if txt1 == nil then
    container.props.visible = false
    equals.props.visible = false
  else
    container.props.visible = true
    equals.props.visible = true
    container.content[1].props.text = txt1
    container.content[3].props.text = txt2
  end
end


local function setResultEffects(effectPairs)
  local content = ui.content {}
  if effectPairs ~= nil then
    -- they are coming in pairs, taking just odd ones
    for i = 1, 100, 2 do
      local eff = effectPairs[i]
      if eff == nil then
        break
      end

      local wx = utilsUI.newMagicEffectWidget(eff)
      content:add(wx)
    end
  end
  ctx.tabElement.layout.content[1].content[7].content = content
end


local function slotClicked(e, sender)
  ctx.lastClickedIngredient = sender
  if ctx.mainIngredient ~= nil then
    ambient.playSound('Item Ingredient Down')
    ctx.mainIngredient = nil
    getSlot():setItemIcon(nil)
    ctx:resetListDataSource()
    setResultHeader(nil)
    setResultEffects(nil)
    ctx.updateTooltip(nil)
    redraw()
  end
end


local function ingredientIconMouseMoved(mouseEvent, sender)
  if ctx.lastTooltipActivator ~= sender then
    if sender ~= nil then
      ctx.tooltipContent = utilsUI.newIngredientTooltipContent(sender.itemData.record)
    end
    ctx.lastTooltipActivator = sender
  end
  ctx.updateTooltip(ctx.tooltipContent, mouseEvent.position)
end


local function slotMouseMoved(mouseEvent, slot, itemIcon)
  if itemIcon ~= nil then
    ingredientIconMouseMoved(mouseEvent, itemIcon)
  end
end


local function ingredientIconClicked(mouseEvent, sender)
  if ctx.alchemyItems.apparatus[types.Apparatus.TYPE.MortarPestle] == nil then
    -- can't do alchemy without mortar-and-pestle
    ui.showMessage(string.format('%s %s', core.getGMST('sNotifyMessage45'), core.getGMST('sSkillAlchemy')))
    return
  end

  ctx.ingredientList:removeItem(sender)
  ctx.lastClickedIngredient = sender
  ctx.updateTooltip(nil)

  local clickedIngredient = sender.itemData

  local slot = getSlot()

  if ctx.mainIngredient == nil then
    ambient.playSound('Item Ingredient Down')
    slot:setItemIcon(sender)
    setResultHeader(nil)
    setResultEffects(nil)
    ctx.mainIngredient = clickedIngredient
    -- print("Main ingredient is " .. clickedIngredient.record.name)
    ctx:filterListDataSource(clickedIngredient.record)
  else
    local mainRecord = ctx.mainIngredient.record
    local clickedRecord = clickedIngredient.record
    -- print(string.format("Trying %s with %s", ctx.mainIngredient.name, clickedIngredient.name))
    local common = utilsCore.getCommonEffects(mainRecord, clickedRecord)
    if common ~= nil then
      ambient.playSound('potion success')
      local discovered = 0
      for i, e in ipairs(common) do
        if not e.known then
          discovered = discovered + 1
          e.known = true
        end
      end
      setResultHeader(mainRecord.name, clickedRecord.name)
      setResultEffects(common)
      I.SkillProgression.skillUsed('alchemy', {
        useType = I.SkillProgression.SKILL_USE_TYPES.Alchemy_CreatePotion,
        scale = discovered,
      })
    else
      ambient.playSound('potion fail')
      setResultHeader(nil)
      setResultEffects(nil)
      ui.showMessage("No reaction")
    end

    local mainId = mainRecord.id
    local clickedId = clickedRecord.id

    utilsCore.markExperiment(mainId, clickedId)
    untestedCombinations[mainId][clickedId] = nil
    untestedCombinations[clickedId][mainId] = nil

    clickedIngredient:spend(1)
    ctx.mainIngredient:spend(1)

    if ctx.mainIngredient.count == 0 or ctx.ingredientList:getItemsCount() == 0 then
      -- print(string.format("Purging datasource from %s", ctx.mainIngredient.name))

      local shift = 0
      -- kick it from this tab's data source
      for i = 1, #ctx.alchemyItems.ingredients do
        if ctx.alchemyItems.ingredients[i] == ctx.mainIngredient then
          shift = 1
        end
        ctx.alchemyItems.ingredients[i] = ctx.alchemyItems.ingredients[i + shift]
      end

      slot:setItemIcon(nil)
      ctx.mainIngredient = nil
      ctx:resetListDataSource()
    else
      slot:setCount(ctx.mainIngredient.count)
    end
  end

  redraw()
end


local function newTabLayout()
  return {
    type = ui.TYPE.Flex,
    props = { horizontal = false },
    content = ui.content {
      {
        type = ui.TYPE.Flex,
        props = {
          horizontal = true,
          arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
          utilsUI.newItemSlot('tab2_slot', slotClicked, slotMouseMoved),
          utilsUI.spacerColumn10,
          {
            type = ui.TYPE.Flex,
            props = {
              horizontal = false,
              arrange = ui.ALIGNMENT.Center,
              visible = false,
            },
            content = ui.content {
              {
                type = ui.TYPE.Text,
                template = I.MWUI.templates.textNormal,
                props = {}
              },
              {
                type = ui.TYPE.Text,
                template = I.MWUI.templates.textNormal,
                props = { text = "+" }
              },
              {
                type = ui.TYPE.Text,
                template = I.MWUI.templates.textNormal,
                props = {}
              },
            },
          },
          utilsUI.spacerColumn10,
          {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = { text = "=", visible = false }
          },
          utilsUI.spacerColumn10,
          {
            type = ui.TYPE.Flex,
            props = { horizontal = false }
          }
        }
      },
      utilsUI.spacerRow20,
    }
  }
end




local newDataSource = function()
  assert(ctx.mainIngredient == nil) -- otherwise should just filter the existing

  local myIngredients = ctx.alchemyItems.ingredients
  local ingrCount = #myIngredients
  local result = {}
  local indices = {}

  for i = 1, ingrCount do
    local v = myIngredients[i]
    if v.count < 1 then
      result[i] = false
      goto next_ingredient
    end

    local id = v.record.id

    local exp = ctx.experiments[id]
    if exp ~= nil and exp.tableLength == maxPossibleExperiments then
      -- tested with EVERYTHING
      result[i] = false
      goto next_ingredient
    end

    local needsMe = indices[id]
    if needsMe ~= nil then
      for j, index in ipairs(needsMe) do
        result[index] = myIngredients[index]
      end
      result[i] = v
      indices[id] = true
    else
      result[i] = false
    end

    for key, b in pairs(untestedCombinations[id]) do
      local bucket = indices[key]
      if bucket == nil then
        indices[key] = { i }
      elseif 'table' == type(bucket) then
        table.insert(bucket, i)
      end
    end

    ::next_ingredient::
  end

  local holes = 0
  -- compact
  for i = 1, ingrCount do
    local x = result[i]
    result[i - holes] = x
    myIngredients[i - holes] = x
    if x == false then
      holes = holes + 1
    end
  end
  -- vacuum
  for i = ingrCount - holes + 1, ingrCount do
    result[i] = nil
    myIngredients[i] = nil
  end

  assert(#result + holes == ingrCount)

  return result
end




--------------------------------------------------------------------------------------------------------


local module = {
  needsItems = true,
}

module.create = function(fnUpdateTooltip, alchemyItems)
  assert(ctx == nil, "Attempting to create a tab when its context still exists, this should never happen")

  maxPossibleExperiments = utilsCore.ingredientsCount - 1 -- all the others minus self

  ctx = {
    updateTooltip = fnUpdateTooltip,
    alchemyItems = alchemyItems,
    experiments = utilsCore.experimentsTable,
    tabElement = ui.create(newTabLayout()),
    mainIngredient = nil,
  }

  updateUntestedCombinations(ctx.alchemyItems.ingredients, ctx.experiments)
  -- for k, v in pairs(untestedCombinations) do
  --   print(k,":")
  --   for j, b in pairs(v) do
  --     print("  ", j)
  --   end
  -- end

  table.sort(ctx.alchemyItems.ingredients, function(x, y) return x.record.name < y.record.name end)


  ctx.resetListDataSource = function(self)
    self.ingredientList:setDataSource(newDataSource())
  end

  ctx.filterListDataSource = function(self, record)
    self.ingredientList:filterDataSource(function(x)
      if x.record == record then
        return false
      else
        local exp = ctx.experiments[record.id]
        return exp == nil or exp[x.record.id] == nil
      end
    end)
  end

  ctx.ingredientList = utilsUI.newItemList {
    width = 12,
    height = 7,
    dataSource = newDataSource(),
    fnItemClicked = ingredientIconClicked,
    fnItemMouseMoved = function(mouseEvent, sender)
      -- HACK: when clicking there are 2 events sent: mouseClick and then mouseMove (which should be ignored)
      if ctx.lastClickedIngredient ~= sender then
        ingredientIconMouseMoved(mouseEvent, sender)
      end
    end,
    redraw = redraw, -- the list uses this when paging
  }

  ctx.tabElement.layout.content:add(ctx.ingredientList)
  -- ctx.tooltip = tooltip

  return ctx.tabElement
end

module.destroy = function()
  assert(ctx ~= nil, "Attempting to destroy a tab when it doesn't exist")
  ctx.tabElement:destroy()
  ctx = nil
end

return module
