local ambient = require('openmw.ambient')
local ui = require('openmw.ui')
local async = require('openmw.async')
local I = require('openmw.interfaces')
local v2 = require('openmw.util').vector2
local self = require('openmw.self')
local utilsUI = require('scripts.alchemistry.utils_ui')
local utilsCore = require('scripts.alchemistry.utils_core')


local ctx = nil


local function redraw()
  -- print("-- REDRAW --")
  ctx.tabElement:update()
end


local function getSlot()
  return ctx.tabElement.layout.content[1]
end


local function slotClicked(e, sender)
  if ctx.mainIngredient ~= nil then
    ambient.playSound('Item Ingredient Down')
    ctx.mainIngredient = nil
    getSlot():setItemIcon(nil)
    ctx:resetListDataSource()
    redraw()
  end
end


local function addExperiment(rec1, rec2, result)
  local exp = ctx.experiments[rec1]
  if exp == nil then
    exp = { tableLength = 0 }
    ctx.experiments[rec1] = exp
  end

  exp[rec2] = result
  exp.tableLength = exp.tableLength + 1
end



local function ingredientIconClicked(mouseEvent, sender)
  ctx.ingredientList:removeItem(sender)
  ctx.lastRemoved = sender
  ctx.tooltip.layout:update(nil)

  local clickedIngredient = sender.itemData

  local slot = getSlot()

  if ctx.mainIngredient == nil then
    ambient.playSound('Item Ingredient Down')
    slot:setItemIcon(sender)
    ctx.mainIngredient = clickedIngredient
    print("++++ Main ingredient is " .. clickedIngredient.record.name)
    ctx:filterListDataSource(ctx.mainIngredient.record)
  else
    -- print(string.format("Trying %s with %s", ctx.mainIngredient.name, clickedIngredient.name))
    local common = utilsCore.getCommonEffects(ctx.mainIngredient.record, clickedIngredient.record)
    local result = 0
    if common ~= nil then
      ambient.playSound('potion success')
      result = 1

    -- TODO display result
      for key, eff in pairs(common) do
        print(string.format("Common '%s'", key))
      end
    else
      ambient.playSound('potion fail')
      ui.showMessage("No reaction")
    -- TODO display result
    end

    addExperiment(ctx.mainIngredient.record, clickedIngredient.record, result)
    addExperiment(clickedIngredient.record, ctx.mainIngredient.record, result)

    -- TODO remove one piece of each ingredient from inventory

    clickedIngredient.count = clickedIngredient.count - 1
    ctx.mainIngredient.count = ctx.mainIngredient.count - 1

    if ctx.mainIngredient.count == 0 then
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
      utilsUI.newItemSlot('tab2_slot', slotClicked),
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
    local exp = ctx.experiments[record]
    local keep = false
    if exp == nil or exp.tableLength < ingredientsLength - 1 then
      -- keep it, because it has less overall test data than the amount of ingredients
      -- (there are some untested combinations)
      keep = true
    elseif exp.tableLength < maxPossibleExperiments then
      for j = 1, ingredientsLength do
        if i ~= j then
          local recordTest = ingredients[j].record
          if exp[recordTest] == nil then
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
    end
  end

  -- vacuum the potential hole at the end of the array
  for i = (ingredientsLength - removed + 1), ingredientsLength do
    ingredients[i] = nil
  end

  if removed > 0 then
    print(string.format("removeWellTested: %i - %i = %i", ingredientsLength, removed, #ingredients))
  end

  assert(#ingredients + removed == ingredientsLength)
end

--------------------------------------------------------------

local module = {}

module.create = function(tooltip)
  assert(ctx == nil, "Attempting to create a tab when its context still exists, this should never happen")

  ctx = {
    alchemyItems = utilsCore.getAvailableItems(self),
    experiments = utilsCore.experimentsTable,
    tabElement = ui.create(newTabLayout()),
    mainIngredient = nil,
  }

  for i, v in ipairs(ctx.alchemyItems.ingredients) do
    v.record = utilsCore.ingredientsData[v.id]
    v.icon = v.record.icon
  end

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
        local exp = ctx.experiments[record]
        return exp == nil or exp[x.record] == nil
      end
    end)
  end

  ctx.tooltipContent = {
    type = ui.TYPE.Text,
    template = I.MWUI.templates.textNormal,
    props = { text = "..." },
  }

  ctx.setTooltipText = function(self, txt)
    self.tooltipContent.props.text = txt
  end

  local function ingredientIconMouseMoved(mouseEvent, sender)
    -- when clicking there are 2 events sent: mouseClick and then mouseMove
    if ctx.lastRemoved ~= sender then
      ctx:setTooltipText(sender.itemData.record.name)
      tooltip.layout:update(ctx.tooltipContent, mouseEvent.position + v2(0, 25))
    end
  end


  ctx.ingredientList = utilsUI.newItemList {
    width = 10,
    height = 8,
    dataSource = newDataSource(),
    fnItemClicked = ingredientIconClicked,
    fnItemMouseMoved = ingredientIconMouseMoved,
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
