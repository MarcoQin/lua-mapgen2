local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")

local LineSegment = class("LineSegment")

function LineSegment:init(p0, p1)
    -- p0, p1: type(Point)
    self.p0 = p0
    self.p1 = p1
end

function LineSegment.compareLengths_MAX(segment0, segment1)
    -- segment0, segment1: type(LineSegment)
    local len0 = Point.distance(segment0.p0, segment0.p1)
    local len1 = Point.distance(segment1.p0, segment1.p1)
    if len0 < len1 then
        return 1
    end
    if len0 > len1 then
        return -1
    end
    return 0
end

function LineSegment.compareLengths(edge0, edge1)
    -- edge0, edge1: type(LineSegment)
    return -LineSegment.compareLengths_MAX(edge0, edge1)
end

return LineSegment
