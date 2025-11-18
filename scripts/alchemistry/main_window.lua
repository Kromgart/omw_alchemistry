local async = require('openmw.async')
local core = require('openmw.core')
local self = require('openmw.self')
local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local v2 = require('openmw.util').vector2
local utilsCore = require('scripts.alchemistry.utils_core')
local utilsUI = require('scripts.alchemistry.utils_ui')


local tabModules = {
  -- Each must have create() and destroy() functions
  require('scripts.alchemistry.tab_brew_vanilla'),
  require('scripts.alchemistry.tab_experiment'),
  {
    create = function() return {} end,
    destroy = function() end,
  }
}


local ctx = nil
local lastOpenTabIdx


local function setActiveTabContent(newTabIdx)
  -- print("setActiveTabContent " .. tostring(newTabIdx))

  if ctx.activeTabIdx ~= nil then
    tabModules[ctx.activeTabIdx].destroy()
  end

  local newTab

  if newTabIdx ~= nil then
    local ingredientsShallowClone = {}
    for i, v in ipairs(ctx.alchemyItems.ingredients) do
      if v.count > 0 then
        table.insert(ingredientsShallowClone, v)
      end
    end

    local tabAlchemyItems = {
      apparatus = ctx.alchemyItems.apparatus,
      ingredients = ingredientsShallowClone,
    }

    newTab = tabModules[newTabIdx].create(ctx.tooltip, tabAlchemyItems)
  else
    newTab = {}
  end

  ctx.activeTabIdx = newTabIdx

  if ctx.mainWindow ~= nil then
    ctx.mainWindow.layout.content[1].content[1].content[2].content[1] = newTab
    ctx.mainWindow:update()
  end
end


local function onMouseMove(mouseEvent, sender)
  assert(ctx.tooltip ~= nil)
  ctx.tooltip.layout:update(nil)
end


local function newMainWindowLayout(tabHeaders)
  local btnClose = utilsUI.newButton('Close', function(e, d) I.UI.removeMode(I.UI.getMode()) end)
  btnClose.props.position = v2(20, 500)

  local result = {
    layer = 'Windows',
    name = 'alchemyRoot',
    type = ui.TYPE.Container,
    template = I.MWUI.templates.boxSolidThick,
    events = { mouseMove = async:callback(onMouseMove) },
    props = {
      anchor = v2(0.5, 0.5),
      relativePosition = v2(0.5, 0.5),
    },
    content = ui.content {{
      type = ui.TYPE.Widget,
      props = {
        size = v2(600, 550),
      },
      content = ui.content {
        {
          type = ui.TYPE.Flex,
          props = {
            horizontal = false,
            autoSize = false,
            relativeSize = v2(1, 1),
          },
          content = ui.content {
            tabHeaders,
            {
              type = ui.TYPE.Container,
              template = utilsUI.newPaddingVH(20, 20),
              content = ui.content {{}}, -- place for a tab content
            },
          }
        },
        btnClose,
      }
    }}
  }

  return result
end

local function hideMainWindow()
  -- ui.showMessage("Alchemy end")
  lastOpenTabIdx = ctx.activeTabIdx
  setActiveTabContent(nil)
  ctx.mainWindow:destroy()
  ctx.tooltip:destroy()
  ctx = nil
end


local function createMainWindow()
  -- ui.showMessage("Alchemy start")
  local tabHeaders = utilsUI.newTabHeaders({ "Make potions", "Experiment", "Known ingredients" }, setActiveTabContent)

  ctx = {
    tooltip = utilsUI.createTooltipElement(),
    mainWindow = ui.create(newMainWindowLayout(tabHeaders)),
    alchemyItems = utilsCore.getAvailableItems(self),
  }

  if lastOpenTabIdx == nil then
    tabHeaders.setActiveTab(1)
  else
    tabHeaders.setActiveTab(lastOpenTabIdx)
  end
end


return {
  show = createMainWindow,
  hide = hideMainWindow
}
