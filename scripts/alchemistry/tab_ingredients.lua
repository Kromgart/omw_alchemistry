local ui = require('openmw.ui')

local utilsUI = require('scripts.alchemistry.utils_ui')
local utilsCore = require('scripts.alchemistry.utils_core')


local tabElement = nil
local updateTooltip = nil
local lastTooltipActivator = nil
local tooltipContent = nil


local function noop() end


local function redraw()
  tabElement:update()
end



local function ingredientIconMouseMoved(mouseEvent, sender)
  if lastTooltipActivator ~= sender then
    if sender ~= nil then
      tooltipContent = utilsUI.newIngredientTooltipContent(sender.itemData)
    end
    lastTooltipActivator = sender
  end
  updateTooltip(tooltipContent, mouseEvent.position)
end



local function newTabLayout()
  local knownIngredients = {}
  local added = 0

  for k, ingredient in pairs(utilsCore.ingredientsData) do
    for i, effect in ipairs(ingredient.effects) do
      if effect.known then
        added = added + 1
        knownIngredients[added] = {
          icon = ingredient.icon,
          count = 1,
          name = ingredient.name,
          effects = ingredient.effects,
        }
        break
      end
    end
  end

  table.sort(knownIngredients, function(x, y) return x.name < y.name end)
  
  local ingredientList = utilsUI.newItemList {
    width = 12,
    height = 7,
    dataSource = knownIngredients,
    fnItemClicked = noop,
    fnItemMouseMoved = ingredientIconMouseMoved,
    redraw = redraw, -- the list uses this when paging
  }

  return {
    type = ui.TYPE.Flex,
    props = { horizontal = false },
    content = ui.content {
      {}, -- TODO: filter box
      utilsUI.spacerRow20,
      ingredientList,
    }
  }
end


-------------------------------------------------------------------------------

local module = {}


module.create = function(fnUpdateTooltip)
  assert(tabElement == nil, "Attempting to create a tab when its element  still exists, this should never happen")

  tabElement = ui.create(newTabLayout())
  updateTooltip = fnUpdateTooltip

  return tabElement
end


module.destroy = function()
  assert(tabElement ~= nil, "Attempting to destroy a tab when it doesn't exist")
  tabElement:destroy()

  tabElement = nil
  updateTooltip = nil
  lastTooltipActivator = nil
  tooltipContent = nil
end


return module
