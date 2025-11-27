local I = require('openmw.interfaces')
local ambient = require('openmw.ambient')
local ui = require('openmw.ui')
local v2 = require('openmw.util').vector2
local utilsUI = require('scripts.alchemistry.utils_ui')


local ctx = nil

local function noop()
end


local function redrawTab()
  ctx.tabElement:update()
end


local function brewPotionsClick()
  ambient.playSound('potion success')
end


local function ingredientSlotClicked(mouseEvent, slot)
  local itemIcon = slot:getItemIcon()
  if itemIcon == nil then
    return
  end

  local shifting = false
  for i, islot in ipairs(ctx.ingredientSlots) do
    if shifting then
      ctx.ingredientSlots[i - 1]:setItemIcon(islot:getItemIcon())
    elseif islot == slot then
      shifting = true
    end
  end

  ctx.ingredientSlots[#ctx.ingredientSlots]:setItemIcon(nil)
  
  -- TODO
  -- 
  -- * re-filter ingrediens list
  -- * update potion effects
  redrawTab()
end

local function ingredientClicked(mouseEvent, sender)
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

  ambient.playSound('Item Ingredient Down')
  freeSlot:setItemIcon(sender)
  -- TODO:
  -- * re-filter ingrediens list
  -- * update potion effects

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


local function slotMouseMoved(mouseEvent, slot, itemIcon)
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


local function newTabLayout()
  -- TODO: mouseMoves
  ctx.ingredientSlots[1] = utilsUI.newItemSlot('slot_ingredient_1', ingredientSlotClicked, slotMouseMoved)
  ctx.ingredientSlots[2] = utilsUI.newItemSlot('slot_ingredient_2', ingredientSlotClicked, slotMouseMoved)
  ctx.ingredientSlots[3] = utilsUI.newItemSlot('slot_ingredient_3', ingredientSlotClicked, slotMouseMoved)
  ctx.ingredientSlots[4] = utilsUI.newItemSlot('slot_ingredient_4', ingredientSlotClicked, slotMouseMoved)

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

  local apparatusSlotsRow = {
    type = ui.TYPE.Flex,
    props = { horizontal = true },
    content = ui.content {
      utilsUI.newItemSlot('slot_apparatus_1', noop, noop),
      utilsUI.spacerColumn20,
      utilsUI.newItemSlot('slot_apparatus_2', noop, noop),
      utilsUI.spacerColumn20,
      utilsUI.newItemSlot('slot_apparatus_3', noop, noop),
      utilsUI.spacerColumn20,
      utilsUI.newItemSlot('slot_apparatus_4', noop, noop),
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

  local textbox = {
    type = ui.TYPE.Widget,
    template = I.MWUI.templates.borders,
    props = {
      size = v2(245, 25),
    },
    content = ui.content {} --put textEdit here
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
              makeHeader("Effect filter:"),
              textbox,
            }
          },
          utilsUI.spacerColumn40,
          {
            type = ui.TYPE.Flex,
            props = { horizontal = false },
            content = ui.content {
              makeHeader("Potion effects:"),
              {
                type = ui.TYPE.Widget,
                template = I.MWUI.templates.borders,
                props = {
                  size = v2(204, 187),
                },
                content = ui.content {{
                  type = ui.TYPE.Flex,
                  props = { horizontal = false },
                  content = ui.content {
                    -- list of potion effects
                  }
                }}
              },
            }
          }
        }
      },
      utilsUI.spacerRow20,
      ingredientsList,
      -- TODO:
      -- * potion name
      -- * batch size
      -- * utilsUI.newButton('Brew', brewPotionsClick, true),
    }
  }
end

local newDataSource = function()
  -- TODO
  -- assert( all ingredient slots are empty ) -- otherwise should just filter the existing datasource

  local result = {}
  for i, ingredient in ipairs(ctx.alchemyItems.ingredients) do
    if ingredient.count > 0 then
      for j, effect in ipairs(ingredient.record.effects) do
        if effect.known then
          table.insert(result, ingredient)
          break
        end
      end
    end
  end

  -- print("New datasource: " .. tostring(#result))
  return result
end

local function createTab(fnUpdateTooltip, alchemyItems)
  assert(ctx == nil, "Attempting to create a tab when its context still exists, this should never happen")

  ctx = {
    alchemyItems = alchemyItems,
    updateTooltip = fnUpdateTooltip,
    ingredientSlots = {},
  }

  ctx.tabElement = ui.create(newTabLayout()),
  ctx.ingredientsList:setDataSource(newDataSource())

  return ctx.tabElement
end

local function destroyTab()
  assert(ctx ~= nil, "Attempting to destroy a tab when it doesn't exist")
  ctx.tabElement:destroy()
  ctx = nil
end

return {
  create = createTab,
  destroy = destroyTab,
}
