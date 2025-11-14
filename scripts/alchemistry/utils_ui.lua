local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local async = require('openmw.async')
local util = require('openmw.util')

local v2 = util.vector2

local stdTextColor = util.color.rgb(0.769, 0.69, 0.545)
local itemIconSize = 40


local module = {}


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

module.spacerRow10 = newSpacer(10, false)
module.spacerRow20 = newSpacer(20, false)
module.spacerColumn10 = newSpacer(10, true)


module.spacerRow10 = {
  type = ui.TYPE.Widget,
  template = I.MWUI.templates.interval,
  props = {
    size = v2(1, 10)
  }
}

local function setPadding(tPadding, w, h)
  tPadding.content[1].props.size = v2(w, h)
  tPadding.content[2].props.position = v2(w, h)
  tPadding.content[3].props.size = v2(w, h)
  tPadding.content[3].props.position = v2(w, h)
end


module.newPadding = function(w, h)
  return {
    type = ui.TYPE.Container,
    content = ui.content {
      {
        props = {
          size = v2(w, h),
        },
      },
      {
        external = { slot = true },
        props = {
          position = v2(w, h),
          relativeSize = v2(1, 1),
        },
      },
      {
        props = {
          position = v2(w, h),
          relativePosition = v2(1, 1),
          size = v2(w, h),
        },
      },
    },
    setPadding = setPadding,
  }
end


module.buttonStyles = {
  I.MWUI.templates.boxTransparent,
  I.MWUI.templates.boxTransparentThick,
}


module.newButton = function(style, id, title, onClick)
  local tmpl = module.buttonStyles[style]
  local pad = (2 - style) * 2

  return {
    name = id,
    type = ui.TYPE.Container,
    template = tmpl,
    events = {
      mouseClick = async:callback(onClick)
    },
    content = ui.content {{
      type = ui.TYPE.Container,
      template = module.newPadding(8 + pad, 2 + pad),
      content = ui.content {{
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textNormal,
        props = { text = title }
      }}
    }}
  }
end


-------------------- itemSlot --------------------

local function setItemSlotItemIcon(slot, itemIcon)
  slot.content[2] = itemIcon
  if itemIcon ~= nil then
    itemIcon.events.mouseClick = nil
  end
end


module.newItemSlot = function(id, onClick)
  return {
    name = id,
    type = ui.TYPE.Container,
    template = I.MWUI.templates.boxSolid,
    events = {
      mouseClick = async:callback(onClick)
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


local function newItemListItemIcon(itemData, idx, onClick)
  local itemIcon = module.newItemIcon(itemData.icon, itemData.count)
  itemIcon.idx = idx
  itemIcon.itemData = itemData
  itemIcon.events.mouseClick = onClick
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
  local onClick = async:callback(function(e, senderIcon)
    arg.fnItemClicked(senderIcon)
  end)

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

    local itemIcon = newItemListItemIcon(itemData, i, onClick)
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
    nextPageFirstIcon = newItemListItemIcon(itemData, idx, itemIcon.events.mouseClick)
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
-- * fnItemClicked(clickedItemIcon)
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
      module.newButton(1, "btnPageBack", "<", prevPage),
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
      module.newButton(1, "btnPageForward", ">", nextPage),
    },
  }

  itemList.content:add(pager)
  itemList:setDataSource(arg.dataSource)

  return itemList
end


return module
