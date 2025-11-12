local core = require('openmw.core')
local self = require('openmw.self')
local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local v2 = require('openmw.util').vector2
local utilsCore = require('scripts.alchemistry.utils_core')
local utilsUi = require('scripts.alchemistry.utils_ui')

local mainWindow, mainWindowLayout
local tabHeaders, activeTabIdx

-- Each must have create() and destroy() functions
local tabModules = {
  require('scripts.alchemistry.tab_brew'),
  require('scripts.alchemistry.tab_experiment'),
}


local function setActiveTab(newTabIdx)
  if newTabIdx == activeTabIdx then
    return
  end

  if activeTabIdx ~= nil then
    tabModules[activeTabIdx].destroy()

    tabHeaders.content[activeTabIdx].template = nil  
    tabHeaders.content[activeTabIdx].content[1].template:setPadding(10, 4)
  end

  local newTab

  if newTabIdx ~= nil then
    newTab = tabModules[newTabIdx].create()

    tabHeaders.content[newTabIdx].template = utilsUi.buttonStyles[1]  
    tabHeaders.content[newTabIdx].content[1].template:setPadding(8, 2)
  else
    newTab = {}
  end

  activeTabIdx = newTabIdx
  mainWindowLayout.content[2].content[1].content[3] = newTab

  mainWindow:update()
end

tabHeaders = {
  type = ui.TYPE.Flex,
  props = {horizontal = true},
  content = ui.content {
    utilsUi.newButton(0, 'alchemyBtnTab1', 'Brew potions', function() setActiveTab(1) end),
    utilsUi.newButton(0, 'alchemyBtnTab2', 'Experiment', function() setActiveTab(2) end),
  }
}

mainWindowLayout = {
  layer = 'Windows',
  name = 'alchemyRoot',
  type = ui.TYPE.Container,
  template = I.MWUI.templates.boxSolidThick,
  props = {
    anchor = v2(0.5, 0.5),
    relativePosition = v2(0.5, 0.5)
  },
  content = ui.content {
    {
      type = ui.TYPE.Widget,
      props = {
        autoSize = false,
        size = v2(600, 550)
      }
    },
    {
      type = ui.TYPE.Container,
      template = utilsUi.newPadding(8, 8),
      content = ui.content {{
        type = ui.TYPE.Flex,
        props = {horizontal = false},
        content = ui.content {
          tabHeaders,
          utilsUi.spacerRow,
          {}, -- place for a tab content
          utilsUi.spacerRow,
          utilsUi.newButton(1, 'alchemyBtnClose', 'Close', function(e, d)
            I.UI.removeMode(I.UI.getMode())
          end)
        }
      },
    }
  }}
}


local function hideMainWindow()
  -- ui.showMessage("Alchemy end")
  setActiveTab(nil)
  mainWindow:destroy()
end


local function createMainWindow()
  -- ui.showMessage("Alchemy start")

  -- print('HOLLY')
  -- local i = ALCO.ingredientsData['ingred_holly_01']
  -- for j, w in pairs(i.effects) do
  --   print('  ' .. tostring(j) .. ': ' .. tostring(w.known))
  -- end

  mainWindow = ui.create(mainWindowLayout)
  setActiveTab(1)
end

return {
  show = createMainWindow,
  hide = hideMainWindow
}
