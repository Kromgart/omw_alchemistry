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
  ctx.tabElement:update()
end


local function getSlot()
  return ctx.tabElement.layout.content[1]
end


local function slotClicked(e, sender)
  if ctx.mainIngredient ~= nil then
    ctx.mainIngredient = nil
    getSlot():setItemIcon(nil)
    ctx:resetListDataSource()
    redraw()
  end
end


local function ingredientIconClicked(sender)
  ctx.ingredientList:removeItem(sender)
  local clickedIngredient = sender.itemData

  local slot = getSlot()

  if ctx.mainIngredient == nil then
    slot:setItemIcon(sender)
    ctx.mainIngredient = clickedIngredient
  else
    -- print(string.format("Trying %s with %s", ctx.mainIngredient.name, clickedIngredient.name))
    local common = utilsCore.getCommonEffects(ctx.mainIngredient.record, clickedIngredient.record)
    if common ~= nil then
      ambient.playSound('potion success')

    -- TODO display result
      for key, eff in pairs(common) do
        print(string.format("%s", key))
      end
    else
      ambient.playSound('potion fail')
      ui.showMessage("No reaction")
    -- TODO display result
    end

    -- TODO store the attempt in 'known' table
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
      utilsUI.spacerRow,
    }
  }
end

--------------------------------------------------------------

local module = {}

module.create = function()
  assert(ctx == nil, "Attempting to create a tab when its data still exists")

  ctx = {
    alchemyItems = utilsCore.getAvailableItems(self),
    tabElement = ui.create(newTabLayout()),
    mainIngredient = nil,
  }

  for i, v in ipairs(ctx.alchemyItems.ingredients) do
    v.record = utilsCore.ingredientsData[v.id]
    v.icon = v.record.icon
  end

  local newDataSource = function()
    local result = {}
    for i, v in ipairs(ctx.alchemyItems.ingredients) do
      if v.count > 0 then
        table.insert(result, v)
      end
    end
    return result
  end

  ctx.resetListDataSource = function(self)
    self.ingredientList:setDataSource(newDataSource())
  end

  ctx.ingredientList = utilsUI.newItemList {
    width = 12,
    height = 8,
    dataSource = newDataSource(),
    fnItemClicked = ingredientIconClicked,
  }

  ctx.tabElement.layout.content:add(ctx.ingredientList)
  return ctx.tabElement
end

module.destroy = function()
  assert(ctx ~= nil, "Attempting to destroy a tab when it doesn't exist")
  ctx.tabElement:destroy()
  ctx = nil
end

return module
