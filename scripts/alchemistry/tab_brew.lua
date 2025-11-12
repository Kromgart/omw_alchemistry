local ambient = require('openmw.ambient')
local ui = require('openmw.ui')
local v2 = require('openmw.util').vector2
local utilsUi = require('scripts.alchemistry.utils_ui')

local tabLayout = {
  type = ui.TYPE.Flex,
  props = {horizontal = false},
  content = ui.content {
    utilsUi.newButton(1, 'alchemyBtnBrew', 'Brew', function(e, d)
      ambient.playSound('potion success')
    end)
  }
}

local tab = nil

local function createTab()
  if tab ~= nil then
    error("Attempting to create a tab when it already exists")
    return nil
  else
    tab = ui.create(tabLayout)
    return tab
  end
end

local function destroyTab()
  if tab == nil then
    error("Attempting to destroy a tab when it doesn't exist")
  else
    tab:destroy()
    tab = nil
  end
end

return {
  create = createTab,
  destroy = destroyTab,
}
