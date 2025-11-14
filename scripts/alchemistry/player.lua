local I = require('openmw.interfaces')
local mainWindow = require('scripts.alchemistry.main_window')

local function fnShow()
  mainWindow.show()
end

local function fnHide()
  mainWindow.hide()
end

I.UI.registerWindow('Alchemy', fnShow, fnHide)

return {
}
