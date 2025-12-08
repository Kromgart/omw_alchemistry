local ui = require('openmw.ui')

local utilsUI = require('scripts.alchemistry.utils_ui')
local utilsCore = require('scripts.alchemistry.utils_core')


---------------------------------------
-- SAFETY: call destroy() on elements
-- Set all to nil in module.destroy(), 
local tabElement = nil
local ingredientsList = nil
local autocompleteElement = nil
local updateTooltip = nil
local lastTooltipActivator = nil
local tooltipContent = nil
local knownIngredients = nil
local wordsList = nil
local lastFilter = nil
-----------------------------------


local function noop() end


local function redraw()
  tabElement:update()
end


local function filterFired(strValue)
  if strValue == lastFilter then
    return
  end

  lastFilter = strValue
  
  -- print('Matched ', strValue)
  local newDataSource = nil

  if strValue == nil then
    newDataSource = knownIngredients
  else
    newDataSource = {}
    local added = 0
    for i, item in ipairs(knownIngredients) do
      if item.name == strValue then
        added = added + 1
        newDataSource[added] = item
      else
        for j, e in ipairs(item.effects) do
          if e.name == strValue then
            added = added + 1
            newDataSource[added] = item
            break
          end
        end
      end
    end
  end

  ingredientsList:setDataSource(newDataSource)
  redraw()
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



local function setupData()
  wordsList = {}
  knownIngredients = {}
  local added = 0

  for k, ingredient in pairs(utilsCore.ingredientsData) do

    local notAdded = true
    for i, effect in ipairs(ingredient.effects) do
      if effect.known then
        local name = effect.name
        wordsList[string.lower(name)] = name

        if notAdded then
          notAdded = false

          local name = ingredient.name
          wordsList[string.lower(name)] = name
          
          added = added + 1
          knownIngredients[added] = {
            icon = ingredient.icon,
            count = 1,
            name = ingredient.name,
            effects = ingredient.effects,
          }
        end
      end
    end
  end

  table.sort(knownIngredients, function(x, y) return x.name < y.name end)
end


local function newTabLayout()
  
  ingredientsList = utilsUI.newItemList {
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
      autocompleteElement,
      utilsUI.spacerRow20,
      ingredientsList,
    }
  }
end



-------------------------------------------------------------------------------

local module = {}


module.create = function(fnUpdateTooltip)
  assert(tabElement == nil, "Attempting to create a tab when its element  still exists, this should never happen")

  setupData()
  autocompleteElement = utilsUI.newAutocomplete(250, filterFired, wordsList)
  tabElement = ui.create(newTabLayout())
  updateTooltip = fnUpdateTooltip

  return tabElement
end


module.destroy = function()
  assert(tabElement ~= nil, "Attempting to destroy a tab when it doesn't exist")

  autocompleteElement:destroy()
  tabElement:destroy()

  tabElement = nil
  ingredientsList = nil
  autocompleteElement = nil
  updateTooltip = nil
  lastTooltipActivator = nil
  tooltipContent = nil
  knownIngredients = nil
  wordsList = nil
  lastFilter = nil
end


return module
