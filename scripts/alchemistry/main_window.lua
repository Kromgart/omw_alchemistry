local async = require('openmw.async')
local core = require('openmw.core')
local self = require('openmw.self')
local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local v2 = require('openmw.util').vector2
local utilsCore = require('scripts.alchemistry.utils_core')
local utilsUI = require('scripts.alchemistry.utils_ui')

local mainWindow, mainWindowLayout, tooltip
local activeTabIdx, lastOpenTabIdx

-- Each must have create() and destroy() functions
local tabModules = {
  require('scripts.alchemistry.tab_brew'),
  require('scripts.alchemistry.tab_experiment'),
  {
    create = function() return {} end,
    destroy = function() end,
  }
}

local function setActiveTabContent(newTabIdx)
  print("setActiveTabContent " .. tostring(newTabIdx))

  if activeTabIdx ~= nil then
    tabModules[activeTabIdx].destroy()
  end

  local newTab

  if newTabIdx ~= nil then
    newTab = tabModules[newTabIdx].create(tooltip)
  else
    newTab = {}
  end

  activeTabIdx = newTabIdx

  if mainWindow ~= nil then
    mainWindow.layout.content[1].content[1].content[2].content[1] = newTab
    mainWindow:update()
  end
end


local tabHeaders = utilsUI.newTabHeaders({ "Make potions", "Experiment", "Known ingredients" }, setActiveTabContent)

local function newMainWindowLayout()
  local btnClose = utilsUI.newButton('Close', function(e, d) I.UI.removeMode(I.UI.getMode()) end)
  btnClose.props.position = v2(20, 500)

  local result = {
    layer = 'Windows',
    name = 'alchemyRoot',
    type = ui.TYPE.Container,
    template = I.MWUI.templates.boxSolidThick,
    events = {
      mouseMove = async:callback(function(e, sender)
        tooltip.layout:update(nil)
      end)
    },
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
  lastOpenTabIdx = activeTabIdx
  setActiveTabContent(nil)
  tooltip:destroy()
  tooltip = nil
  mainWindow:destroy()
  mainWindow = nil
end


local function createMainWindow()
  -- ui.showMessage("Alchemy start")
  tooltip = utilsUI.createTooltipElement()
  mainWindow = ui.create(newMainWindowLayout())

  if lastOpenTabIdx == nil then
    setActiveTabContent(1)
  else
    setActiveTabContent(lastOpenTabIdx)
  end
end

return {
  show = createMainWindow,
  hide = hideMainWindow
}
