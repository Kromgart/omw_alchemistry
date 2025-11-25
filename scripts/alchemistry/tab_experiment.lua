local ambient = require('openmw.ambient')
local ui = require('openmw.ui')
local async = require('openmw.async')
local I = require('openmw.interfaces')
local v2 = require('openmw.util').vector2
local self = require('openmw.self')
local utilsUI = require('scripts.alchemistry.utils_ui')
local utilsCore = require('scripts.alchemistry.utils_core')


local ctx = nil

-- local redrawCount = 0

local function redraw()
  -- print(string.format("-- REDRAW -- %i", redrawCount))
  -- redrawCount = redrawCount + 1
  ctx.tabElement:update()
end


local newTooltipContent = function(ingredientRecord)
  local result = {
    type = ui.TYPE.Flex,
    props = {
      horizontal = false,
      arrange = ui.ALIGNMENT.Center,
    },
    content = ui.content {
      {
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textHeader,
        props = { text = ingredientRecord.name },
      }
    }
  }

  local separated = false

  for i, effect in ipairs(ingredientRecord.effects) do
    if effect.known == true then
      -- print(string.format("%s, %s", effect.name, effect.icon))
      if not separated then
        result.content:add(utilsUI.spacerRow5)
        separated = true
      end
      local effectWidget = utilsUI.newMagicEffectWidget(effect)
      result.content:add(effectWidget)
    end
  end

  return result
end


local function getSlot()
  return ctx.tabElement.layout.content[1].content[1]
end

local function setResultHeader(txt)
  ctx.tabElement.layout.content[1].content[3].props.text = txt
end


local function setResultEffects(effects)
  local content = ui.content {}
  if effects ~= nil then
    for name, eff in pairs(effects) do
      local wx = utilsUI.newMagicEffectWidget(eff[1])
      content:add(wx)
    end
  end
  ctx.tabElement.layout.content[1].content[5].content = content
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
    ctx.tooltip.layout:update(nil)
    redraw()
  end
end


local function ingredientIconMouseMoved(mouseEvent, sender)
  if ctx.lastTooltipActivator ~= sender then
    if sender ~= nil then
      ctx.tooltipContent = newTooltipContent(sender.itemData.record)
    end
    ctx.lastTooltipActivator = sender
  end
  ctx.tooltip.layout:update(ctx.tooltipContent, mouseEvent.position + v2(0, 25))
end


local function slotMouseMoved(mouseEvent, slot, itemIcon)
  if itemIcon ~= nil then
    ingredientIconMouseMoved(mouseEvent, itemIcon)
  end
end


local function addExperiment(rec1, rec2, result)
  local exp = ctx.experiments[rec1.id]
  if exp == nil then
    exp = { tableLength = 0 }
    ctx.experiments[rec1.id] = exp
  end

  exp[rec2.id] = result
  exp.tableLength = exp.tableLength + 1
end



local function ingredientIconClicked(mouseEvent, sender)
  ctx.ingredientList:removeItem(sender)
  ctx.lastClickedIngredient = sender
  ctx.tooltip.layout:update(nil)

  local clickedIngredient = sender.itemData

  local slot = getSlot()

  if ctx.mainIngredient == nil then
    ambient.playSound('Item Ingredient Down')
    slot:setItemIcon(sender)
    setResultHeader(nil)
    setResultEffects(nil)
    ctx.mainIngredient = clickedIngredient
    -- print("Main ingredient is " .. clickedIngredient.record.name)
    ctx:filterListDataSource(ctx.mainIngredient.record)
  else
    -- print(string.format("Trying %s with %s", ctx.mainIngredient.name, clickedIngredient.name))
    local common = utilsCore.getCommonEffects(ctx.mainIngredient.record, clickedIngredient.record)
    local result = nil
    if common ~= nil then
      result = 1
      ambient.playSound('potion success')
      for k, v in pairs(common) do
        for i, e in ipairs(v) do
          e.known = true
        end
      end
      setResultHeader(string.format("%s + %s:", ctx.mainIngredient.record.name, clickedIngredient.record.name))
      setResultEffects(common)
    else
      result = 0
      ambient.playSound('potion fail')
      setResultHeader(nil)
      setResultEffects(nil)
      ui.showMessage("No reaction")
    end

    addExperiment(ctx.mainIngredient.record, clickedIngredient.record, result)
    addExperiment(clickedIngredient.record, ctx.mainIngredient.record, result)

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
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {}
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


local function removeWellTestedIngredients(ingredients)
  -- Filter out ingredients that are useless for experiments
  local ingredientsLength = #ingredients
  local removed = 0

  local maxPossibleExperiments = utilsCore.ingredientsData.tableLength - 1 -- all the others minus self

  for i = 1, ingredientsLength do
    local record = ingredients[i].record
    local exp = ctx.experiments[record.id]
    local keep = false
    if exp == nil or exp.tableLength < ingredientsLength - 1 then
      -- keep it, because it has less overall test data than the amount of ingredients
      -- (there are some untested combinations)
      keep = true
    elseif exp.tableLength < maxPossibleExperiments then
      for j = 1, ingredientsLength do
        if i ~= j then
          local recordTest = ingredients[j].record
          if exp[recordTest.id] == nil then
            -- this combination is untested
            keep = true
            break
          end
        end
      end
    end

    ingredients[i - removed] = ingredients[i]

    if not keep then
      removed = removed + 1
      -- print(string.format("Filtered out %s (no useful experiments are possible)", record.name))
    end
  end

  -- vacuum the potential hole at the end of the array
  for i = (ingredientsLength - removed + 1), ingredientsLength do
    ingredients[i] = nil
  end

  -- if removed > 0 then
  --   print(string.format("removeWellTested: %i - %i = %i", ingredientsLength, removed, #ingredients))
  -- end

  assert(#ingredients + removed == ingredientsLength)
end






--------------------------------------------------------------------------------------------------------


local module = {}

module.create = function(tooltip, alchemyItems)
  assert(ctx == nil, "Attempting to create a tab when its context still exists, this should never happen")

  ctx = {
    alchemyItems = alchemyItems,
    experiments = utilsCore.experimentsTable,
    tabElement = ui.create(newTabLayout()),
    mainIngredient = nil,
  }

  removeWellTestedIngredients(ctx.alchemyItems.ingredients)
  table.sort(ctx.alchemyItems.ingredients, function(x, y) return x.record.name < y.record.name end)

  local newDataSource = function()
    assert(ctx.mainIngredient == nil) -- otherwise should just filter the existing

    local result = {}
    for i, v in ipairs(ctx.alchemyItems.ingredients) do
      if v.count > 0 then
        table.insert(result, v)
      end
    end

    -- print("New datasource: " .. tostring(#result))
    return result
  end

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
      -- when clicking there are 2 events sent: mouseClick and then mouseMove
      if ctx.lastClickedIngredient ~= sender then
        ingredientIconMouseMoved(mouseEvent, sender)
      end
    end,
    redraw = redraw, -- the list uses this when paging
  }

  ctx.tabElement.layout.content:add(ctx.ingredientList)
  ctx.tooltip = tooltip

  return ctx.tabElement
end

module.destroy = function()
  assert(ctx ~= nil, "Attempting to destroy a tab when it doesn't exist")
  ctx.tabElement:destroy()
  ctx = nil
end

return module
