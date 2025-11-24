local I = require('openmw.interfaces')
local ambient = require('openmw.ambient')
local async = require('openmw.async')
local ui = require('openmw.ui')
local util = require('openmw.util')

local v2 = util.vector2

local stdTextColor = util.color.rgb(0.769, 0.69, 0.545)


local module = {}




--------------------------------- Spacers --------------------------------------


local function newSpacer(size, isHorizontal)
  if isHorizontal then
    size = v2(size, 1)
  else
    size = v2(1, size)
  end

  return {
    type = ui.TYPE.Widget,
    template = I.MWUI.templates.interval,
    props = { size = size }
  }
end

module.spacerRow5 = newSpacer(5, false)
module.spacerRow10 = newSpacer(10, false)
module.spacerRow20 = newSpacer(20, false)
module.spacerColumn3 = newSpacer(3, true)
module.spacerColumn10 = newSpacer(10, true)
module.spacerColumn20 = newSpacer(20, true)




--------------------------------- Paddings --------------------------------------


local function setPaddingTRBL(padding, t, r, b, l)
  padding.content[1].props.size = v2(l, t)
  padding.content[2].props.position = v2(l, t)
  padding.content[3].props.size = v2(r, b)
  padding.content[3].props.position = v2(l, t)
end

local function setPaddingBottom(padding, newValue)
  local old = padding.content[3].props.size
  padding.content[3].props.size = v2(old.x, newValue)
end

module.newPaddingTRBL = function(t, r, b, l)
  return {
    type = ui.TYPE.Container,
    content = ui.content {
      {
        props = {
          size = v2(l, t),
        },
      },
      {
        external = { slot = true },
        props = {
          position = v2(l, t),
          relativeSize = v2(1, 1),
        },
      },
      {
        props = {
          position = v2(l, t),
          relativePosition = v2(1, 1),
          size = v2(r, b),
        },
      },
    },
    setPaddingTRBL = setPaddingTRBL,
    setPaddingBottom = setPaddingBottom,
  }
end

module.newPaddingVH = function(vertical, horizontal)
  return module.newPaddingTRBL(vertical, horizontal, vertical, horizontal)
end


------------------------------- Bordered Containers ---------------------------------


local borderTexturesThin = {
  ui.texture { size = v2(512, 2), path = "textures/menu_thin_border_top.dds" },
  ui.texture { size = v2(2, 2),   path = "textures/menu_thin_border_top_right_corner.dds" },
  ui.texture { size = v2(2, 512), path = "textures/menu_thin_border_right.dds" },
  ui.texture { size = v2(2, 2),   path = "textures/menu_thin_border_bottom_right_corner.dds" },
  ui.texture { size = v2(512, 2), path = "textures/menu_thin_border_bottom.dds" },
  ui.texture { size = v2(2, 2),   path = "textures/menu_thin_border_bottom_left_corner.dds" },
  ui.texture { size = v2(2, 512), path = "textures/menu_thin_border_left.dds" },
  ui.texture { size = v2(2, 2),   path = "textures/menu_thin_border_top_left_corner.dds" },
  2,
}


local borderTexturesThick = {
  ui.texture { size = v2(512, 4), path = "textures/menu_thick_border_top.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_thick_border_top_right_corner.dds" },
  ui.texture { size = v2(4, 512), path = "textures/menu_thick_border_right.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_thick_border_bottom_right_corner.dds" },
  ui.texture { size = v2(512, 4), path = "textures/menu_thick_border_bottom.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_thick_border_bottom_left_corner.dds" },
  ui.texture { size = v2(4, 512), path = "textures/menu_thick_border_left.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_thick_border_top_left_corner.dds" },
  4,
}


local borderTexturesButton = {
  ui.texture { size = v2(128, 4), path = "textures/menu_button_frame_top.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_button_frame_top_right_corner.dds" },
  ui.texture { size = v2(4, 16),  path = "textures/menu_button_frame_right.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_button_frame_bottom_right_corner.dds" },
  ui.texture { size = v2(128, 4), path = "textures/menu_button_frame_bottom.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_button_frame_bottom_left_corner.dds" },
  ui.texture { size = v2(4, 16),  path = "textures/menu_button_frame_left.dds" },
  ui.texture { size = v2(4, 4),   path = "textures/menu_button_frame_top_left_corner.dds" },
  4,
}


local setBorderedTemplateColorMult = function(template, color)
  for i = 2, #template.content do
    template.content[i].props.color = color
  end
end


local function newBorderedTemplate(widgetType, borderTx, hasTop, hasRight, hasBottom, hasLeft)
  local lineWidth = borderTx[9]

  local content = ui.content {{
    external = { slot = true },
    props = { relativeSize = v2(1, 1) },
  }}

  local added = 1

  if hasLeft then
    content:add({
      type = ui.TYPE.Image,
      props = {
        resource = borderTx[7],
        size = v2(lineWidth, 0),
        relativeSize = v2(0, 1),
        tileV = true,
      }
    })
    added = added + 1
  end

  if hasRight then
    content:add({
      type = ui.TYPE.Image,
      props = {
        resource = borderTx[7],
        size = v2(lineWidth, 0),
        relativeSize = v2(0, 1),
        position = v2(-lineWidth, 0),
        relativePosition = v2(1, 0),
        tileV = true,
      }
    })
    added = added + 1
  end

  if hasTop then
    content:add({
      type = ui.TYPE.Image,
      props = {
        resource = borderTx[1],
        size = v2(0, lineWidth),
        relativeSize = v2(1, 0),
        tileH = true,
      }
    })
    added = added + 1

    if hasLeft then
      content:add({
        type = ui.TYPE.Image,
        props = {
          resource = borderTx[8],
          size = v2(lineWidth, lineWidth),
        }
      })
      added = added + 1
    end

    if hasRight then
      content:add({
        type = ui.TYPE.Image,
        props = {
          resource = borderTx[2],
          size = v2(lineWidth, lineWidth),
          position = v2(-lineWidth, 0),
          relativePosition = v2(1, 0),
        }
      })
      added = added + 1
    end
  end

  if hasBottom then
    content:add({
      type = ui.TYPE.Image,
      props = {
        resource = borderTx[5],
        size = v2(0, lineWidth),
        relativeSize = v2(1, 0),
        position = v2(0, -lineWidth),
        relativePosition = v2(0, 1),
        tileH = true,
      }
    })
    added = added + 1

    if hasLeft then
      content:add({
        type = ui.TYPE.Image,
        props = {
          resource = borderTx[6],
          size = v2(lineWidth, lineWidth),
          position = v2(0, -lineWidth),
          relativePosition = v2(0, 1),
        }
      })
      added = added + 1
    end

    if hasRight then
      content:add({
        type = ui.TYPE.Image,
        props = {
          resource = borderTx[4],
          size = v2(lineWidth, lineWidth),
          position = v2(-lineWidth, -lineWidth),
          relativePosition = v2(1, 1),
        }
      })
      added = added + 1
    end
  end


  return {
    type = widgetType,
    content = content,
    setBorderColorMult = setBorderedTemplateColorMult
  }
end


----------------------- Tooltip ----------------------------


module.createTooltipElement = function()
  local layout = {
    type = ui.TYPE.Container,
    layer = 'Notification',
    template = I.MWUI.templates.boxSolid,
    props = {
      visible = false,
      anchor = v2(0.5, 0),
    },
    content = ui.content {{
      type = ui.TYPE.Container,
      template = module.newPaddingVH(6, 6),
      content = ui.content {}
    }},

    update = function(self, newContent, newPosition)
      if not (self.content[1].content[1] == nil and newContent == nil) then
        self.props.visible = (newContent ~= nil)
        self.content[1].content[1] = newContent
        if newPosition ~= nil then
          self.props.position = newPosition
        end
        -- print("Update: ", tostring(newPosition))
        self.parentElement:update()
      end
    end,
  }

  local result = ui.create(layout)
  layout.parentElement = result

  return result
end



----------------------- Buttons ----------------------------


module.newButton = function(title, onClick, isSilent)
  local mouseClick = function(e, s)
    if not isSilent then
      ambient.playSound('Menu Click')
    end
    onClick(e, s)
  end

  return {
    type = ui.TYPE.Container,
    template = newBorderedTemplate(ui.TYPE.Container, borderTexturesButton, true, true, true, true),
    events = { mouseClick = async:callback(mouseClick) },
    props = {},
    content = ui.content {{
      type = ui.TYPE.Container,
      template = module.newPaddingVH(6, 10),
      content = ui.content {{
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textNormal,
        props = { text = title }
      }}
    }}
  }
end




local itemIconSize = 40


-------------------- itemSlot --------------------

local function setItemSlotItemIcon(slot, itemIcon)
  slot.content[2] = itemIcon
  if itemIcon ~= nil then
    itemIcon.events = nil
  end
end


module.newItemSlot = function(id, onClick, onMouseMove)
  local function itemSlotMouseMoved(mouseEvents, slot)
    onMouseMove(mouseEvents, slot, slot.content[2])
  end

  return {
    name = id,
    type = ui.TYPE.Container,
    template = I.MWUI.templates.boxSolid,
    events = {
      mouseClick = async:callback(onClick),
      mouseMove = async:callback(itemSlotMouseMoved),
    },
    content = ui.content {{
      type = ui.TYPE.Widget,
      props = {
        autoSize = false,
        size = v2(itemIconSize + 2, itemIconSize + 2),
      }
    }},
    setItemIcon = setItemSlotItemIcon,
    setCount = function(self, count) self.content[2]:setCount(count) end
  }
end


-------------------- itemIcon --------------------

local function setItemIconCount(itemIcon, count)
  local strCount = nil
  if count ~= nil and count > 1 then
    strCount = tostring(count)
  end
  itemIcon.content[2].props.text = strCount
end


module.newItemIcon = function(iconPath, count)
  local textSize = 18
  local iconSize = 32
  local iconOffset = (itemIconSize - iconSize) / 2

  local itemIcon = {
    type = ui.TYPE.Container,
    events = {},
    content = ui.content {
      {
        type = ui.TYPE.Image,
        props = {
          size = v2(iconSize, iconSize),
          position = v2(iconOffset,  iconOffset),
          resource = ui.texture { path = iconPath }
        },
      },
      {
        type = ui.TYPE.Text,
        props = {
          size = v2(itemIconSize, textSize),
          position = v2(0, itemIconSize - textSize),
          textSize = textSize,
          text = strCount,
          autoSize = false,
          textColor = stdTextColor,
          textAlignH = ui.ALIGNMENT.End,
        }
      }
    },
    setCount = setItemIconCount,
  }

  itemIcon:setCount(count)
  return itemIcon
end


-------------------- itemList --------------------


local newItemColumn = function()
  return {
    type = ui.TYPE.Flex,
    props = { horizontal = false },
    content = ui.content {}
  }
end


local function getItemListColumns(itemList)
  return itemList.content[1].content[2].content
end


local function setItemListColumns(itemList, columns)
  itemList.content[1].content[2].content = columns
end


local function newItemListItemIcon(itemData, idx, onClick, onMouseMove)
  local itemIcon = module.newItemIcon(itemData.icon, itemData.count)
  itemIcon.idx = idx
  itemIcon.itemData = itemData
  itemIcon.events.mouseClick = onClick
  itemIcon.events.mouseMove = onMouseMove
  return itemIcon
end


local function setItemListPager(itemList, currentPage, pagesTotal)
  local pager = itemList.content[3]
  if pagesTotal < 2 then
    pager.props.visible = false
  else
    pager.props.visible = true
    pager.content[3].props.text = string.format("%i / %i", currentPage, pagesTotal)
  end
end


local setItemListDataSource


local function setItemListPage(itemList, page)
  setItemListDataSource(itemList, itemList.creationArgs.dataSource, page)
end



-- dataSource: { icon = ..., count = ..., anythingElse = ... }
setItemListDataSource = function(self, dataSource, page)
  if page ~= nil then
    self.currentPage = page
  elseif self.currentPage == nil then
    self.currentPage = 1
  end

  local arg = self.creationArgs
  arg.dataSource = dataSource

  newColumns = ui.content {}

  local columnsCount = 0
  local curColumn = nil
  local curColumnLen = arg.height
  local onClick = async:callback(arg.fnItemClicked)
  local onMouseMove = async:callback(arg.fnItemMouseMoved)

  local pageCapacity = arg.height * arg.width
  local dataSourceLen = #dataSource
  local pagesCount = math.ceil(dataSourceLen / pageCapacity)

  if pagesCount < self.currentPage then
    self.currentPage = pagesCount
  end

  local viewStart = (self.currentPage - 1) * pageCapacity + 1
  local viewEnd = viewStart + math.min(pageCapacity - 1, dataSourceLen - viewStart)

  -- print(string.format("items: %i, pages: %i", dataSourceLen, pagesCount))
  -- print(string.format("viewStart: %i, viewEnd: %i", viewStart, viewEnd))

  for i = viewStart, viewEnd do
    local itemData = dataSource[i]

    if curColumnLen % arg.height == 0 then
      columnsCount = columnsCount + 1
      if columnsCount > arg.width then
        return
      end

      curColumnLen = 0
      curColumn = newItemColumn()
      newColumns:add(curColumn)
    end

    curColumnLen = curColumnLen + 1

    local itemIcon = newItemListItemIcon(itemData, i, onClick, onMouseMove)
    curColumn.content:add(itemIcon)
  end

  setItemListColumns(self, newColumns)
  setItemListPager(self, self.currentPage, pagesCount)

end


local function filterItemListDataSource(self, filter)
  local removed = 0
  local dataSource = self.creationArgs.dataSource
  local last = #dataSource

  for i = 1, last do
    local x = dataSource[i]
    dataSource[i - removed] = dataSource[i]
    if not (filter(x)) then
      print(string.format("filter out %s", x.record.name))
      removed = removed + 1
    end
  end

  if removed > 0 then
    for i = last - removed + 1, last do
      dataSource[i] = nil
    end

    setItemListDataSource(self, dataSource)
  end
end


local function removeFromItemList(self, itemIcon)
  local arg = self.creationArgs

  local pageCapacity = arg.width * arg.height
  local viewIdx = (itemIcon.idx - 1) % pageCapacity + 1
  -- print("viewIdx: " .. tostring(viewIdx))
  local dataSourceLen = #arg.dataSource

  if self.currentPage > 1 and itemIcon.idx == dataSourceLen and viewIdx == 1 then
    -- last page, first and only item
    arg.dataSource[dataSourceLen] = nil
    setItemListPage(self, self.currentPage - 1)
    return
  end

  local pagesCount = math.ceil(dataSourceLen / pageCapacity)

  local nextPageFirstIcon = nil
  if self.currentPage < pagesCount then
    -- pull the first item from the next page, make a new icon
    local idx = pageCapacity * self.currentPage
    local itemData = arg.dataSource[idx + 1]
    nextPageFirstIcon = newItemListItemIcon(itemData, idx, itemIcon.events.mouseClick, itemIcon.events.mouseMove)
  end

  -- Remove the cliked one from the datasource
  for i = itemIcon.idx, dataSourceLen do
    arg.dataSource[i] = arg.dataSource[i + 1]
  end
  dataSourceLen = dataSourceLen - 1

  pagesCount = math.max(1, math.ceil(dataSourceLen / pageCapacity))
  setItemListPager(self, self.currentPage, pagesCount)

  -- print(string.format("items: %i, pager: %i/%i", dataSourceLen, self.currentPage, pagesCount))

  local columnStart = math.floor((viewIdx - 1) / arg.height) + 1
  local rowStart = ((viewIdx - 1) % arg.height) + 1
  -- print(string.format("Removing %i(%i %i) %s from the list", itemIcon.idx, columnStart, rowStart, itemIcon.itemData.record.name))

  local columns = getItemListColumns(self)
  local columnsCount = #columns

  for i = columnStart, columnsCount do
    local columnItems = columns[i].content
    for j = rowStart, #columnItems do
      -- local s1 = string.format("moving %i, %i (%s)", i, j, column[j].idx)
      if j < #columnItems then
        -- print(s1 .. ": normal")
        columnItems[j] = columnItems[j + 1]
        columnItems[j].idx = columnItems[j].idx - 1
      elseif i < columnsCount then -- last item in non-final column
        -- print(s1 .. ": last non-final")
        columnItems[j] = columns[i + 1].content[1]
        columnItems[j].idx = columnItems[j].idx - 1
      else -- last item in final column
        -- print(s1 .. ": last final")
        columnItems[j] = nextPageFirstIcon
      end
    end
    rowStart = 1
  end

  local lastColumn =  columns[columnsCount]
  if #lastColumn.content == 0 then
    -- print("trimming empty column")
    columns[columnsCount] = nil
  end
end


---------------------------------------
-- arg must contain:
-- * height
-- * width
-- * dataSource: { icon = ..., count = ..., anythingElse = ... }
-- * fnItemClicked(mouseEvent, clickedItemIcon)
-- * fnItemMouseMoved(mouseEvent, movedItemIcon)
-- * redraw() -- used on paging to reflect the page changes
---------------------------------------
module.newItemList = function(arg)
  local itemListInner = {
    type = ui.TYPE.Container,
    template = I.MWUI.templates.boxTransparent,
    content = ui.content {
      {
        type = ui.TYPE.Widget,
        props = {
          autoSize = false,
          size = v2(arg.width * itemIconSize + 5, arg.height * itemIconSize + 5),
        },
      },
      {
        type = ui.TYPE.Flex,
        props = {
          horizontal = true,
          autoSize = true,
        },
      },
    },
  }

  local itemList = {
    type = ui.TYPE.Flex,
    props = { horizontal = false },
    content = ui.content {
      itemListInner,
      module.spacerRow10,
    },
    creationArgs = arg,
    setDataSource = setItemListDataSource,
    filterDataSource = filterItemListDataSource,
    removeItem = removeFromItemList,
  }

  local nextPage = function()
    local args = itemList.creationArgs
    local pagesCount = math.ceil(#args.dataSource / (args.width * args.height))
    if itemList.currentPage < pagesCount then
      setItemListPage(itemList, itemList.currentPage + 1)
      -- manual paging is done internally, so we call the redraw() ourselves here
      arg.redraw()
    end
  end

  local prevPage = function()
    if itemList.currentPage > 1 then
      setItemListPage(itemList, itemList.currentPage - 1)
      -- manual paging is done internally, so we call the redraw() ourselves here
      arg.redraw()
    end
  end


  local pager = {
    type = ui.TYPE.Flex,
    props = { horizontal = true },
    content = ui.content {
      module.newButton("<", prevPage),
      module.spacerColumn10,
      {
        type = ui.TYPE.Text,
        props = {
          autoSize = false,
          size = v2(40, 24),
          textColor = stdTextColor,
          textAlignH = ui.ALIGNMENT.Center,
          textAlignV = ui.ALIGNMENT.Center,
          textSize = 18,
        },
      },
      module.spacerColumn10,
      module.newButton(">", nextPage),
    },
  }

  itemList.content:add(pager)
  itemList:setDataSource(arg.dataSource)

  return itemList
end




------------------------------- Tab headers ---------------------------------


local tabHeaderSpacerInactive = {
  type = ui.TYPE.Widget,
  props = {
    size = v2(1, 2)
  }
}

local tabHeaderSpacerActive = {
  type = ui.TYPE.Widget,
  props = {
    size = v2(0, 2),
    relativeSize = v2(1, 0),
  },
  content = ui.content {
    {
      type = ui.TYPE.Image,
      props = {
        resource = ui.texture { path = 'white' },
        color = util.color.rgb(0, 0, 0),
        relativeSize = v2(1, 1),
      }
    },
    {
      type = ui.TYPE.Image,
      props = {
        size = v2(2, 2),
        resource = borderTexturesThin[4],
      }
    },
    {
      type = ui.TYPE.Image,
      props = {
        size = v2(2, 2),
        relativePosition = v2(1, 0),
        position = v2(-2, 0),
        resource = borderTexturesThin[6],
      }
    },
  }
}

local tabHeaderBorderColorInactive = util.color.rgb(0.8, 0.8, 0.8)
local tabHeaderTextColorInactive
do
  local c = I.MWUI.templates.textNormal.props.textColor
  tabHeaderTextColorInactive = util.color.rgb(c.r * 0.85, c.g * 0.85, c.b * 0.85) 
end 

local function setTabHeaderActive(self, isActive)
  if isActive then
    self.content[1].template:setBorderColorMult(nil)
    self.content[1].content[1].content[1].props.textColor = nil
    self.content[1].content[1].template:setPaddingBottom(6)
    self.content[2] = tabHeaderSpacerActive
  else
    self.content[1].template:setBorderColorMult(tabHeaderBorderColorInactive)
    self.content[1].content[1].content[1].props.textColor = tabHeaderTextColorInactive
    self.content[1].content[1].template:setPaddingBottom(3)
    self.content[2] = tabHeaderSpacerInactive
  end
end


local newTabHeader = function(title, onClickCallback)
  local result = {
    type = ui.TYPE.Flex,
    props = {
      horizontal = false,
      align = ui.ALIGNMENT.End,
    },
    events = { mouseClick = onClickCallback },
    setActive = setTabHeaderActive,
    content = ui.content {
      {
        type = ui.TYPE.Container,
        template = newBorderedTemplate(ui.TYPE.Container, borderTexturesThin, true, true, false, true),
        content = ui.content{{
          type = ui.TYPE.Container,
          template = module.newPaddingTRBL(6, 10, 3, 10),
          content = ui.content {{
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = { text = title }
          }}
        }}
      },
      tabHeaderSpacerInactive
    }
  }

  setTabHeaderActive(result, false)
  return result
end


module.newTabHeaders = function(titles, onTabChanged)
  local result = {
    type = ui.TYPE.Widget,
    props = {
      size = v2(0, 50),
      relativeSize = v2(1, 0),
    },
  }

  local function setActiveTab(tab)
    if result.activeTab == tab then
      return
    end

    -- print("Activating tab " .. tab.title)

    if result.activeTab ~= nil then
      result.activeTab:setActive(false)
    end
    result.activeTab = tab
    tab:setActive(true)
    onTabChanged(tab.tabIdx)
  end

  local tabHeaderClicked = async:callback(function (e, sender)
    ambient.playSound('Menu Click')
    setActiveTab(sender)
  end)

  local tbsContent = ui.content {
    module.spacerColumn20,
  }

  for i, v in ipairs(titles) do
    local newTab = newTabHeader(v, tabHeaderClicked)
    newTab.title = v
    newTab.tabIdx = i
    tbsContent:add(newTab)
    tbsContent:add(module.spacerColumn3)
  end

  result.setActiveTab = function(idx) setActiveTab(tbsContent[idx * 2]) end

  result.content = ui.content {
    {
      type = ui.TYPE.Image,
      template = I.MWUI.templates.horizontalLine,
      props = {
        relativePosition = v2(0, 1),
        position = v2(0, -2),
        size = v2(0, 2),
        relativeSize = v2(1, 0),
      }
    },
    {
      type = ui.TYPE.Flex,
      props = {
        horizontal = true,
        position = v2(0, 20),
        arrange = ui.ALIGNMENT.End,
      },
      content = tbsContent,
    }
  }

  return result
end




-------------------------------- MagicEffectWidget-----------------------------------

local magicEffectIcons = {}

module.newMagicEffectWidget = function(magicEffect, magnitude, duration)
  local label = nil

  if magnitude == nil then
    if duration == nil then
      label = magicEffect.name
    else
      label = string.format('%s for %i secs', magicEffect.name, duration)
    end
  else
    -- TODO: could be 'ft' or smth (telekinesis)
    local magnitudeSuffix = 'pts'

    if duration == nil then
      label = string.format('%s %i %s', magicEffect.name, magnitude, magnitudeSuffix)
    else
      label = string.format('%s %i %s for %i secs', magicEffect.name, magnitude, magnitudeSuffix, duration)
    end
  end

  local iconResource = magicEffectIcons[magicEffect.icon]
  if iconResource == nil then
    iconResource = ui.texture { path = magicEffect.icon }
    magicEffectIcons[magicEffect.icon] = iconResource
  end

  return {
    type = ui.TYPE.Flex,
    props = { horizontal = true },
    content = ui.content {
      {
        type = ui.TYPE.Image,
        props = {
          size = v2(16, 16),
          resource = iconResource,
        },
      },
      module.spacerColumn3,
      {
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textNormal,
        props = { text = label }
      }
    }
  }
end

-------------------------------- LogBox -----------------------------------

-- module.newLogBox = function(props)
--   if props == nil then
--     props = {}
--   end

--   props.multiline = true
--   props.readOnly = true
--   props.wordWrap = true
--   props.textSize = 18
--   props.textColor = stdTextColor

--   return {
--     type = ui.TYPE.Container,
--     template = newBorderedTemplate(ui.TYPE.Container, borderTexturesThin, true, true, true, true),
--     content = ui.content {{
--       type = ui.TYPE.TextEdit,
--       props = props,
--     }}
--   }
-- end




-------------------------------- END  -----------------------------------



return module
