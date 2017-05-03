local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Winding = require(folderOfThisFile.."/Winding")

local Polygon = class("Polygon")

function Polygon:init(vertices)
    -- vertices: type(list(Point))
    self._vertices = vertices or {}
end

function Polygon:area()
    return math.abs(self:signedDoubleArea() * 0.5)
end

function Polygon:winding()
    local _signedDoubleArea = self:signedDoubleArea()
    if _signedDoubleArea < 0 then
        return Winding.CLOCKWISE
    end
    if _signedDoubleArea > 0 then
        return Winding.COUNTERCLOCKWISE
    end
    return Winding.NONE
end

function Polygon:signedDoubleArea()
    local index, nextIndex
    local n = #self._vertices
    local point, _next  -- type(Point)
    local _signedDoubleArea = 0
    index = 0
    while index < n do
        nextIndex = (index + 1) % n;
        point = self._vertices[index + 1]
        _next = self._vertices[nextIndex + 1]
        _signedDoubleArea = _signedDoubleArea + (point.x * _next.y - _next.x * point.y)
        index = index + 1
    end
    return _signedDoubleArea
end

return Polygon
