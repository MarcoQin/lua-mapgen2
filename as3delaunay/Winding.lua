local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")

local Winding = class("Winding")

function Winding:init(name)
    -- name: type(string)
    self._name = name
end

function Winding:__tostring()
    return self._name
end

Winding.CLOCKWISE = Winding("clockwise")
Winding.COUNTERCLOCKWISE = Winding("counterclockwise")
Winding.NONE = Winding("none")

return Winding
