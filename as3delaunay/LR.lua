local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")

local LR = class("LR")

function LR:init(name)
    self._name = name
end

-- static method
function LR.other(leftRight)
    return leftRight == LR.LEFT and LR.RIGHT or LR.LEFT
end

LR.LEFT = "left"
LR.RIGHT = "right"

function LR:__tostring()
    return self._name
end

return LR
