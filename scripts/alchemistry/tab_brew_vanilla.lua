local I = require('openmw.interfaces')
local ambient = require('openmw.ambient')
local ui = require('openmw.ui')
local v2 = require('openmw.util').vector2
local utilsUI = require('scripts.alchemistry.utils_ui')


local ctx = nil


local function brewPotionsClick()
  ambient.playSound('potion success')
end


local function noop()
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
  local ingredientSlots = {
    type = ui.TYPE.Flex,
    props = { horizontal = true },
    content = ui.content {
      utilsUI.newItemSlot('slot_ingredient_1', noop, noop),
      utilsUI.spacerColumn20,
      utilsUI.newItemSlot('slot_ingredient_2', noop, noop),
      utilsUI.spacerColumn20,
      utilsUI.newItemSlot('slot_ingredient_3', noop, noop),
      utilsUI.spacerColumn20,
      utilsUI.newItemSlot('slot_ingredient_4', noop, noop),
    }
  }

  local apparatusSlots = {
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
    fnItemClicked = noop,
    fnItemMouseMoved = noop,
    redraw = noop,
  }

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
              apparatusSlots,
              makeHeader("Ingredients:"),
              ingredientSlots,
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
      -- potion name
      -- batch size
      -- utilsUI.newButton('Brew', brewPotionsClick, true),
    }
  }
end


local function createTab(tooltip, alchemyItems)
  assert(ctx == nil, "Attempting to create a tab when its context still exists, this should never happen")

  ctx = {
    alchemyItems = alchemyItems,
    tabElement = ui.create(newTabLayout()),
  }

  ctx.tooltip = tooltip

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
