local I = require('openmw.interfaces')
local mainWindow = require('scripts.alchemistry.main_window')
local utilsCore = require('scripts.alchemistry.utils_core')


local function fnShow()
  mainWindow.show()
end


local function fnHide()
  mainWindow.hide()
end


I.UI.registerWindow('Alchemy', fnShow, fnHide)


local function saveData()
  local result = {
    knownEffects = {},
    madeExperiments = utilsCore.experimentsTable,
  }

  for ingredientId, ingredientRecord in pairs(utilsCore.ingredientsData) do
    if ingredientId ~= 'tableLength' then
    -- print(string.format("%s %s", ingredientId, ingredientRecord))
      local knownIngredientEffects = nil
      for i, eff in ipairs(ingredientRecord.effects) do
        if eff.known then
          if knownIngredientEffects == nil then
            knownIngredientEffects = {}
          end
          knownIngredientEffects[eff.key] = true
        end
      end

      if knownIngredientEffects ~= nil then
        result.knownEffects[ingredientId] = knownIngredientEffects
      end
    end
  end

  return result
end


local function loadData(data)
  if data == nil then
    -- print("loadData: nil")
    data = {
      knownEffects = {},
      madeExperiments = {},
    }
  else
    -- print("loadData")
  end

  utilsCore.initIngredients(data.knownEffects, data.madeExperiments)
end

local function initData()
  -- print("initData")
  loadData(nil)
end

return {
  engineHandlers = {
    onSave = saveData,
    onLoad = loadData,
    onInit = initData,
  }
}
