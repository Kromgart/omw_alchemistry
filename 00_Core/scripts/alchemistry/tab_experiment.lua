local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local types = require('openmw.types')
local utilsUI = require('scripts.alchemistry.utils_ui')
local utilsCore = require('scripts.alchemistry.utils_core')

local playSound = require('openmw.ambient').playSound
local v2 = require('openmw.util').vector2
local getGMST = require('openmw.core').getGMST



------------------------------------------------------
-- SAFETYget: Always keep alive, don't delete
local hasMortar = false
local maxPossibleExperiments = nil
local untestedCombinations = nil
------------------------------------------------------


------------------------------------------ ---------------------------------
-- SAFETY: Is alive while the tab is active. Set to nil in module.destroy.
local tabElement = nil
local updateTooltip = nil
local ingredientList = nil
local mainIngredient = nil
local ingredients = nil
local experiments = nil
local lastClickedIngredient = nil
local lastTooltipActivator = nil
local tooltipContent = nil
------------------------------------------ ---------------------------------






local function updateUntestedCombinations()
  local firstRun = untestedCombinations == nil
  if firstRun then
    print("untestedCombinations: init")
    untestedCombinations = {}
  end

  for i, ingredient in ipairs(ingredients) do
    local id = ingredient.record.id

    local myUnknowns = untestedCombinations[id]
    if myUnknowns ~= nil then
      -- don't touch cached ones, they will be updated by newcomers
      goto next_ingredient
    end

    -- A newcomer in the cache: check for done experiments with ALL CACHED entries

    local myExperiments = experiments[id]
    if myExperiments == nil then
      -- completely new, no test data at all
      myUnknowns = {}
      for cacheKey, cacheValue in pairs(untestedCombinations) do
        cacheValue[id] = true
        myUnknowns[cacheKey] = true
      end
    else
      if myExperiments.tableLength == maxPossibleExperiments then
        -- tested with ALL ingredients, skip this one
        goto next_ingredient
      end

      myUnknowns = {}
      for cacheKey, cacheValue in pairs(untestedCombinations) do
        if myExperiments[cacheKey] == nil then
          cacheValue[id] = true
          myUnknowns[cacheKey] = true
        end
      end
    end
    untestedCombinations[id] = myUnknowns

    ::next_ingredient::
  end

end


local function removeFromUntestedCache(id1, id2)
  local c = untestedCombinations[id1]
  if c ~= nil then
    c[id2] = nil
  end

  c = untestedCombinations[id2]
  if c ~= nil then
    c[id1] = nil
  end
end


local function redraw()
  tabElement:update()
end


local function getSlot()
  return tabElement.layout.content[1].content[1]
end


local function setResultHeader(txt1, txt2)
  local container = tabElement.layout.content[1].content[3]
  local equals = tabElement.layout.content[1].content[5]
  if txt1 == nil then
    container.props.visible = false
    equals.props.visible = false
  else
    container.props.visible = true
    equals.props.visible = true
    container.content[1].props.text = txt1
    container.content[3].props.text = txt2
  end
end


local function setResultEffects(effectPairs)
  local content = ui.content {}
  if effectPairs ~= nil then
    -- they are coming in pairs, taking just odd ones
    for i = 1, 100, 2 do
      local eff = effectPairs[i]
      if eff == nil then
        break
      end

      local wx = utilsUI.newMagicEffectWidget(eff)
      content:add(wx)
    end
  end
  tabElement.layout.content[1].content[7].content = content
end




local newDataSource = function()
  assert(mainIngredient == nil) -- otherwise should just filter the existing

  local ingrCount = #ingredients
  local result = {}
  -- using array of indices allows to skip sorting at the end
  local indices = {}

  for i = 1, ingrCount do
    local ingredient = ingredients[i]
    if ingredient.count < 1 then
      result[i] = false
      goto next_ingredient
    end

    local id = ingredient.record.id

    local exp = experiments[id]
    if exp ~= nil and exp.tableLength == maxPossibleExperiments then
      -- tested with EVERYTHING
      result[i] = false
      goto next_ingredient
    end

    local needMe = indices[id]
    if needMe ~= nil then
      -- INVARIANT: needMe is a table. It is overwritten by number only here below, when we process "ourself"
      for j, index in ipairs(needMe) do
        result[index] = ingredients[index]
      end
      result[i] = ingredient
    else
      -- Nobody needs us yet, put a hole in results for now
      result[i] = false
    end

    -- Mark that we have been already encountered
    -- Following subscribers will be able to immediatly add us by this index
    -- This potentially drops the subscription table, which is fine
    indices[id] = i

    for weNeed, b in pairs(untestedCombinations[id]) do
      local subs = indices[weNeed]
      -- INVARIANT: subs is one of:
      -- * nil => 'weNeed' has not been seen yet and we are the first to subscribe
      -- * table => actual subscriptions table, awaiting for 'weNeed' to process it
      -- * number => indicates that 'weNeed' has been seen on previous iterations by this index
      if subs == nil then
        -- this weNeed was not seen yet, subscribe
        indices[weNeed] = { i }
      elseif 'table' == type(subs) then
        table.insert(subs, i)
      else
        -- DEBUG: testing the invariant
        assert('number' == type(subs))
        result[subs] = ingredients[subs]
        result[i] = ingredient
      end
    end

    ::next_ingredient::
  end

  local holes = 0
  -- compact
  for i = 1, ingrCount do
    local x = result[i]
    result[i - holes] = x
    ingredients[i - holes] = x
    if x == false then
      holes = holes + 1
    end
  end
  -- vacuum
  for i = ingrCount - holes + 1, ingrCount do
    result[i] = nil
    ingredients[i] = nil
  end

  assert(#result + holes == ingrCount)

  return result
end


local function resetListDataSource()
  ingredientList:setDataSource(newDataSource())
end


local function filterListDataSource(mainRecord)
  local exp = experiments[mainRecord.id]
  ingredientList:filterDataSource(function(x)
    local xRecord = x.record
    if xRecord ~= mainRecord then
      return exp == nil or exp[xRecord.id] == nil
    else
      -- skip the one we are filtering for
      return false
    end
  end)

  ------------------------------------------------
  --                  DEBUG

  -- if ingredientList:getItemsCount() == 0 then
  --   print("ERROR: Filtered for zero results")
  --   for i, v in ipairs(ingredients) do
  --     local rec = v.record
  --     print(rec.name, " experiments:")
  --     local exp = experiments[rec.id]
  --     if exp == nil then
  --       print("  nil")
  --     else
  --       for e, b in pairs(exp) do
  --         print("  ", e)
  --       end
  --     end
  --     print(rec.name, " unknowns:")
  --     local unk = untestedCombinations[rec.id]
  --     if unk == nil then
  --       print("  nil")
  --     else
  --       for e, b in pairs(unk) do
  --         print("  ", e)
  --       end
  --     end
  --   end
  --   error("halt")
  -- end
  ------------------------------------------------
end








local function slotClicked(e, sender)
  lastClickedIngredient = sender
  if mainIngredient ~= nil then
    playSound('Item Ingredient Down')
    mainIngredient = nil
    getSlot():setItemIcon(nil)
    resetListDataSource()
    setResultHeader(nil)
    setResultEffects(nil)
    updateTooltip(nil)
    redraw()
  end
end


local function ingredientIconMouseMoved(mouseEvent, sender)
  if lastTooltipActivator ~= sender then
    if sender ~= nil then
      tooltipContent = utilsUI.newIngredientTooltipContent(sender.itemData.record)
    end
    lastTooltipActivator = sender
  end
  updateTooltip(tooltipContent, mouseEvent.position)
end


local function slotMouseMoved(mouseEvent, slot, itemIcon)
  if itemIcon ~= nil then
    ingredientIconMouseMoved(mouseEvent, itemIcon)
  end
end


local function ingredientIconClicked(mouseEvent, sender)
  if hasMortar == false then
    -- can't do alchemy without mortar-and-pestle
    ui.showMessage(string.format('%s %s', getGMST('sNotifyMessage45'), getGMST('sSkillAlchemy')))
    return
  end

  lastClickedIngredient = sender
  updateTooltip(nil)

  local clickedIngredient = sender.itemData

  local slot = getSlot()

  if mainIngredient == nil then
    playSound('Item Ingredient Down')
    slot:setItemIcon(sender)
    setResultHeader(nil)
    setResultEffects(nil)
    mainIngredient = clickedIngredient
    filterListDataSource(clickedIngredient.record)
  else
    local mainRecord = mainIngredient.record
    local clickedRecord = clickedIngredient.record
    local common = utilsCore.getCommonEffects(mainRecord, clickedRecord)
    if common ~= nil then
      playSound('potion success')
      local discovered = 0
      for i, e in ipairs(common) do
        if not e.known then
          discovered = discovered + 1
          e.known = true
        end
      end
      setResultHeader(mainRecord.name, clickedRecord.name)
      setResultEffects(common)
      I.SkillProgression.skillUsed('alchemy', {
        useType = I.SkillProgression.SKILL_USE_TYPES.Alchemy_CreatePotion,
        scale = discovered,
      })
    else
      playSound('potion fail')
      setResultHeader(nil)
      setResultEffects(nil)
      ui.showMessage("No reaction")
    end

    local mainId = mainRecord.id
    local clickedId = clickedRecord.id

    utilsCore.markExperiment(mainId, clickedId)
    clickedIngredient:spend(1)
    mainIngredient:spend(1)

    if mainIngredient.count == 0 or ingredientList:getItemsCount() == 1 then
      -- Either the main one was spent, or we clicked the last icon in the ingredientsList (it will become empty now)
      -- can remove the mainIngredient from the ingredients

      local count = #ingredients
      local idx = 0
      for i = 1, count do
        if ingredients[i] == mainIngredient then
          idx = i
          break
        end
      end
      for i = idx, count do
        ingredients[i] = ingredients[i + 1]
      end

      slot:setItemIcon(nil)
      mainIngredient = nil
      resetListDataSource()
    else
      ingredientList:removeItem(sender)
      slot:setCount(mainIngredient.count)
    end
  end

  redraw()
end


local function newTabLayout()
  return {
    type = ui.TYPE.Flex,
    props = { horizontal = false },
    content = ui.content {
      {
        type = ui.TYPE.Flex,
        props = {
          horizontal = true,
          arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
          utilsUI.newItemSlot('tab2_slot', slotClicked, slotMouseMoved),
          utilsUI.spacerColumn10,
          {
            type = ui.TYPE.Flex,
            props = {
              horizontal = false,
              arrange = ui.ALIGNMENT.Center,
              visible = false,
            },
            content = ui.content {
              {
                type = ui.TYPE.Text,
                template = I.MWUI.templates.textNormal,
                props = {}
              },
              {
                type = ui.TYPE.Text,
                template = I.MWUI.templates.textNormal,
                props = { text = "+" }
              },
              {
                type = ui.TYPE.Text,
                template = I.MWUI.templates.textNormal,
                props = {}
              },
            },
          },
          utilsUI.spacerColumn10,
          {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = { text = "=", visible = false }
          },
          utilsUI.spacerColumn10,
          {
            type = ui.TYPE.Flex,
            props = { horizontal = false }
          }
        }
      },
      utilsUI.spacerRow20,
    }
  }
end





--------------------------------------------------------------------------------------------------------
--                                             DEBUG


-- local function DEBUG_testCaches(msg)
--   if untestedCombinations == nil then
--     return
--   end

--   local isError = false
--   for k1, v in pairs(untestedCombinations) do
--     local exp1 = experiments[k1]
--     if exp1 ~= nil then
--       for k2, b in pairs(v) do
--         local k1k2 = exp1[k2]
--         if k1k2 == true then
--           print(string.format("%s: %s untested (%s) AND experimented(%s)", msg, k1, k2, k2))
--           isError = true
--         end

--         local exp2 = experiments[k2]
--         if exp2 ~= nil then
--           local k2k1 = exp2[k1]
--           if k2k1 ~= k1k2 then
--             print(string.format("%s: Experiments don't match: %s+%s=%s, %s+%s=%s", msg, k1, k2, k1k2, k2, k1, k2k1))
--             isError = true
--           end
--         end

--         if untestedCombinations[k2][k1] == nil then
--           print(string.format("%s: untested mismatch, %s<-%s is missing", msg, k1, k2))
--           isError = true
--         end
--       end
--     end
--   end

--   assert(not isError)
-- end


-- local function DEBUG_testInclusion()
--   local isError = false
--   for i, item in ipairs(ingredients) do
--     local id = item.record.id
--     local unknowns = untestedCombinations[id]
--     if unknowns == nil then
--       print(id .. " is missing from untestedCombinations cache")
--       isError = true
--     end
--   end
--   assert(not isError)
-- end



--------------------------------------------------------------------------------------------------------


local module = {}

module.create = function(fnUpdateTooltip, alchemyItems)
  assert(tabElement == nil, "Attempting to create a tab when it still exists, this should never happen")

  maxPossibleExperiments = utilsCore.ingredientsCount - 1 -- all the others minus self
  experiments = utilsCore.experimentsTable

  updateTooltip = fnUpdateTooltip
  hasMortar = alchemyItems.apparatus[types.Apparatus.TYPE.MortarPestle] ~= nil

  -- we need our own copy to mutate
  ingredients = {}
  local added = 0
  for i, v in ipairs(alchemyItems.ingredients) do
    if v.count > 0 then
      added = added + 1
      ingredients[added] = v
    end
  end

  tabElement = ui.create(newTabLayout())

  -- DEBUG_testCaches('pre')

  updateUntestedCombinations()

  -- DEBUG_testInclusion()
  -- DEBUG_testCaches('post')

  utilsCore.onExperimentAdded = removeFromUntestedCache

  ingredientList = utilsUI.newItemList {
    width = 12,
    height = 7,
    dataSource = newDataSource(),
    fnItemClicked = ingredientIconClicked,
    fnItemMouseMoved = function(mouseEvent, sender)
      -- HACK: when clicking there are 2 events sent: mouseClick and then mouseMove (which should be ignored)
      if lastClickedIngredient ~= sender then
        ingredientIconMouseMoved(mouseEvent, sender)
      end
    end,
    redraw = redraw, -- the list uses this when paging
  }

  tabElement.layout.content:add(ingredientList)

  return tabElement
end

module.destroy = function()
  assert(tabElement ~= nil, "Attempting to destroy a tab when it doesn't exist")
  tabElement:destroy()

  tabElement = nil
  ingredientList = nil
  updateTooltip = nil
  mainIngredient = nil
  ingredients = nil
  experiments = nil
  lastClickedIngredient = nil
  lastTooltipActivator = nil
  tooltipContent = nil
end

return module
