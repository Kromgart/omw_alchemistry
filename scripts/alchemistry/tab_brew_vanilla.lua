local ambient = require('openmw.ambient')
local ui = require('openmw.ui')
local v2 = require('openmw.util').vector2
local utilsUi = require('scripts.alchemistry.utils_ui')


local ctx = nil


local function newTabLayout()
  return {
    type = ui.TYPE.Flex,
    props = {horizontal = false},
    content = ui.content {
      utilsUi.newButton('Brew', function(e, d)
        ambient.playSound('potion success')
      end,
      true)
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
