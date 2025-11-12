local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local async = require('openmw.async')
local util = require('openmw.util')

local v2 = util.vector2

local itemIconSize = 40

local module = {}


module.spacerRow = {
  type = ui.TYPE.Widget,
  template = I.MWUI.templates.interval,
  props = {
    size = v2(1, 20)
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
          textColor = util.color.rgb(0.769, 0.69, 0.545),
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


-- dataSource: { icon = ..., count = ..., anythingElse = ... }
local function setItemListDataSource(self, dataSource)
  local arg = self.creationArgs
  arg.dataSource = dataSource
  self.content[2].content = ui.content {}
  
  local columnsCount = 0
  local curColumn = nil
  local curColumnLen = arg.height

  -- TODO: limit the total amount <= width*height
  for i, itemData in ipairs(arg.dataSource) do
    if curColumnLen % arg.height == 0 then
      columnsCount = columnsCount + 1
      if columnsCount > arg.width then
        return
      end
      
      curColumnLen = 0
      curColumn = newItemColumn()
      self.content[2].content:add(curColumn)
    end

    curColumnLen = curColumnLen + 1

    local itemIcon = module.newItemIcon(itemData.icon, itemData.count)
    itemIcon.idx = i
    itemIcon.itemData = itemData
    itemIcon.events.mouseClick = async:callback(function(e, senderIcon)
      arg.fnItemClicked(senderIcon)
    end)
    curColumn.content:add(itemIcon)
  end
end


local function removeFromItemList(self, itemIcon)
  local arg = self.creationArgs

  local columnStart = math.floor((itemIcon.idx - 1) / arg.height) + 1
  local rowStart = ((itemIcon.idx - 1) % arg.height) + 1
  -- print(string.format("Removing %i(%i %i) %s from the list", itemIcon.idx, columnStart, rowStart, itemIcon.itemData.record.name))

  local columnsCount = #self.content[2].content
  
  for i = columnStart, columnsCount do
    local column = self.content[2].content[i].content
    for j = rowStart, #column do
      -- local s1 = string.format("moving %i, %i (%s)", i, j, column[j].idx)
      if j < #column then
        -- print(s1 .. ": normal")
        column[j] = column[j + 1]
        column[j].idx = column[j].idx - 1
      elseif i < columnsCount then -- last item in non-final column
        -- print(s1 .. ": last non-final")
        column[j] = self.content[2].content[i + 1].content[1]
        column[j].idx = column[j].idx - 1
      else -- last item in final column
        -- print(s1 .. ": last final")
        column[j] = nil
      end
    end
    rowStart = 1
  end

  local lastColumn =  self.content[2].content[columnsCount]
  if #lastColumn.content == 0 then
    -- print("trimming empty column")
    self.content[2].content[columnsCount] = nil
  end

end


---------------------------------------
-- arg must contain:
-- * height
-- * width
-- * dataSource: { icon = ..., count = ..., anythingElse = ... }
-- * fnItemClicked(clickedItemIcon)
---------------------------------------
module.newItemList = function(arg)
  local itemList = {
    type = ui.TYPE.Container,
    template = I.MWUI.templates.boxTransparent,
    content = ui.content {
      {
        type = ui.TYPE.Widget,
        props = {
          autoSize = false,
          size = v2(arg.width * itemIconSize, arg.height * itemIconSize),
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
    creationArgs = arg,
    setDataSource = setItemListDataSource,
    removeItem = removeFromItemList,
  }

  itemList:setDataSource(arg.dataSource)

  return itemList
end

return module
