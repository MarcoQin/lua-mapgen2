local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")

local Stack = class("Stack")

function Stack:init()
    self._s = {}
end

function Stack:size()
    return #self._s
end

function Stack:pop()
    return table.remove(self._s, self:size())
end

function Stack:push(item)
    table.insert(self._s, item)
end

return Stack
