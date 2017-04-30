local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")

local Circle = class("Circle")

function Circle:init(centerX, centerY, radius)
    self.center = Point(centerX, centerY)
    self.radius = radius
end

function Circle:__tostring()
    return "Circle (center: "..tostring(self.center).."; radius: "..tostring(self.radius)..")"
end

return Circle
