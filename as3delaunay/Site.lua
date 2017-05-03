local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Stack = require(folderOfThisFile.."/Stack")
local Polygon = require(folderOfThisFile.."/Polygon")
local Winding = require(folderOfThisFile.."/Winding")
local EdgeReorderer = require(folderOfThisFile.."/EdgeReorderer")
local Vertex = require(folderOfThisFile.."/Vertex")
local LR = require(folderOfThisFile.."/LR")
local BIT = require(folderOfThisFile.."/numberlua")

local Site = class("Site")

local _pool = Stack()

-- static function
function Site.create(p, index, weight, color)
    if _pool:size() > 0 then
        return _pool:pop():setup(p, index, weight, color)
    else
        return Site(p, index, weight, color)
    end
end

-- static method
function Site.sortSites(sites)
    table.sort(sites, function(o1, o2)
        local r = Site.compare(o1, o2)
        return r < 0 and true or false
    end)
end

local function compareByYThenX(s1, s2)
    -- s1, s2: type(Site)
    if s1:get_y() < s2:get_y() then return -1 end
    if s1:get_y() > s2:get_y() then return 1 end
    if s1:get_x() < s2:get_x() then return -1 end
    if s1:get_x() > s2:get_x() then return 1 end
    return 0
end
--sort sites on y, then x, coord also change each site's _siteIndex to
-- * match its new position in the list so the _siteIndex can be used to
-- * identify the site for nearest-neighbor queries
-- *
-- * haha "also" - means more than one responsibility...
-- static method
function Site.compare(s1, s2)
    local r = compareByYThenX(s1, s2)

    -- swap _siteIndex values if necessary to match new ordering:
    local tempIndex = 0
    if (r == -1) then
        if (s1._siteIndex > s2._siteIndex) then
            tempIndex = s1._siteIndex;
            s1._siteIndex = s2._siteIndex;
            s2._siteIndex = tempIndex;
        end
    elseif (r == 1) then
        if (s2._siteIndex > s1._siteIndex) then
            tempIndex = s2._siteIndex;
            s2._siteIndex = s1._siteIndex;
            s1._siteIndex = tempIndex;
        end
    end

    return r
end

Site.EPSILON = 0.005

-- static method
function Site.closeEnough(p0, p1)
    return Point.distance(p0, p1) < Site.EPSILON
end

function Site:get_coord()
    return self._coord
end

function Site:init(p, index, weight, color)
    self._coord = nil
    self.color = nil
    self.weight = 0.0
    self._siteIndex = 0
    self._edges = nil
    self._edgeOrientations = nil
    self._region = nil

    self:setup(p, index, weight, color)
end

function Site:setup(p, index, weight, color)
    self._coord = p
    self._siteIndex = index
    self.weight = weight
    self.color = color
    self._edges = {}
    self._region = nil

    return self
end

function Site:__tostring()
    return "Site "..tostring(self._siteIndex)..": "..tostring(self:get_coord())
end

function Site:move(p)
    self:clear()
    self._coord = p
end

function Site:dispose()
    self._coord = nil
    self:clear()
    _pool:push(self)
end

function Site:clear()
    self._edges = nil
    self._edgeOrientations = nil
    self._region = nil
end

function Site:addEdge(edge)
    table.insert(self._edges, edge)
end

function Site:nearestEdge()
    table.sort(self._edges, function(o1, o2)
        local r = Edge.compareSitesDistances(o1, o2)
        return r < 0 and true or false
    end)
    return self._edges[1]
end

function Site:neighborSites()
    if self._edges == nil or #self._edges == 0 then
        return {}
    end
    if self._edgeOrientations == nil then
        self:reorderEdges()
    end
    local list = {}
    for _, edge in pairs(self._edges) do
        table.insert(list, self:neighborSite(edge))
    end
    return list
end

function Site:neighborSite(edge)
    if self == edge:get_leftSite() then
        return edge:get_rightSite()
    end
    if self == edge:get_rightSite() then
        return edge:get_leftSite()
    end
    return nil
end

local function Reverse (arr)
	local i, j = 1, #arr

	while i < j do
		arr[i], arr[j] = arr[j], arr[i]

		i = i + 1
		j = j - 1
	end
end

function Site:region(clippingBounds)
    -- clippingBounds: type(Rectangle)
    if self._edges == nil or #self._edges == 0 then
        return {}
    end
    if self._edgeOrientations == nil then
        self:reorderEdges()
        self._region = self:clipToBounds(clippingBounds)
    end
    if Polygon(self._region):winding() == Winding.CLOCKWISE then
        Reverse(self._region)
    end
    return self._region
end

function Site:reorderEdges()
    local reorderer = EdgeReorderer(self._edges, "Vertex")
    self._edges = reorderer:get_edges()
    self._edgeOrientations = reorderer:get_edgeOrientations()
    reorderer:dispose()
end

function Site:clipToBounds(bounds)
    -- bounds: type(Rectangle)
    local points = {}
    local n = #self._edges
    local i = 1
    local edge
    while i <= n and (self._edges[i]:get_visible() == false) do
        i = i + 1
    end

    if i > n then
        return {}
    end

    edge = self._edges[i]
    local orientation = self._edgeOrientations[i]
    table.insert(points, edge:get_clippedEnds()[orientation])
    table.insert(points, edge:get_clippedEnds()[LR.other(orientation)])

    local j
    for j = i + 1, n do
        edge = self._edges[j]
        if edge:get_visible() == true then
            self:connect(points, j, bounds, false)
        end
    end
    -- close up the polygon by adding another corner point of the bounds if needed
    self:connect(points, i, bounds, true)

    return points
end

local BoundsCheck = class("BoundsCheck")

BoundsCheck.TOP = 1
BoundsCheck.BOTTOM = 2
BoundsCheck.LEFT = 4
BoundsCheck.RIGHT = 8

function BoundsCheck.check(point, bounds)
    local value = 0
    if point.x == bounds.left then
        value = BIT.bor(value, BoundsCheck.LEFT)
    end
    if point.x == bounds.right then
        value = BIT.bor(value, BoundsCheck.RIGHT)
    end
    if point.y == bounds.top then
        value = BIT.bor(value, BoundsCheck.TOP)
    end
    if point.y == bounds.bottom then
        value = BIT.bor(value, BoundsCheck.BOTTOM)
    end
    return value
end

function Site:connect(points, j, bounds, closingUp)
    -- points: listof type(Point), j: int, bounds: type(Rectangle), closingUp: type(bool)
    local rightPoint = points[#points]
    local newEdge = self._edges[j]
    local newOrientation = self._edgeOrientations[j]
    -- the point that  must be connected to rightPoint:
    local newPoint = newEdge:get_clippedEnds()[newOrientation]
    if not Site.closeEnough(rightPoint, newPoint) then
        if rightPoint.x ~= newPoint.x and rightPoint.y ~= newPoint.y then
            local rightCheck = BoundsCheck.check(rightPoint, bounds)
            local newCheck = BoundsCheck.check(newPoint, bounds)
            local px, py
            if BIT.band(rightCheck, BoundsCheck.RIGHT) ~= 0 then

                px = bounds.right
                if BIT.band(newCheck, BoundsCheck.BOTTOM) ~= 0 then
                    py = bounds.bottom
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.TOP) ~= 0 then
                    py = bounds.top
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.LEFT) ~= 0 then
                    if rightPoint.y - bounds.y + newPoint.y - bounds.y < bounds.height then
                        py = bounds.top
                    else
                        py = bounds.bottom
                    end
                    table.insert(points, Point(px, py))
                    table.insert(points, Point(bounds.left, py))
                end -- if BIT.band(newCheck, BoundsCheck.BOTTOM) ~= 0 then

            elseif BIT.band(rightCheck, BoundsCheck.LEFT) ~= 0 then

                px = bounds.left
                if BIT.band(newCheck, BoundsCheck.BOTTOM) ~= 0 then
                    py = bounds.bottom
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.TOP) ~= 0 then
                    py = bounds.top
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.RIGHT) ~= 0 then
                    if rightPoint.y - bounds.y + newPoint.y - bounds.y < bounds.height then
                        py = bounds.top
                    else
                        py = bounds.bottom
                    end
                    table.insert(points, Point(px, py))
                    table.insert(points, Point(bounds.right, py))
                end

            elseif BIT.band(rightCheck, BoundsCheck.TOP) ~= 0 then

                py = bounds.top
                if BIT.band(newCheck, BoundsCheck.RIGHT) ~= 0 then
                    px = bounds.right
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.LEFT) ~= 0 then
                    px = bounds.left
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.BOTTOM) ~= 0 then
                    if rightPoint.x - bounds.x + newPoint.x - bounds.x < bounds.width then
                        px = bounds.left
                    else
                        px = bounds.right
                    end
                    table.insert(points, Point(px, py))
                    table.insert(points, Point(px, bounds.bottom))
                end

            elseif BIT.band(rightCheck, BoundsCheck.BOTTOM) ~= 0 then

                py = bounds.bottom
                if BIT.band(rightCheck, BoundsCheck.RIGHT) ~= 0 then
                    px = bounds.right
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.LEFT) ~= 0 then
                    px = bounds.left
                    table.insert(points, Point(px, py))
                elseif BIT.band(newCheck, BoundsCheck.TOP) ~= 0 then
                    if rightPoint.x - bounds.x + newPoint.x - bounds.x < bounds.width then
                        px = bounds.left
                    else
                        px = bounds.right
                    end
                    table.insert(points, Point(px, py))
                    table.insert(points, Point(px, bounds.top))
                end

            end -- if BIT.band(rightCheck, BoundsCheck.RIGHT) ~= 0 then
        end -- if rightPoint.x ~= newPoint.x and rightPoint.y ~= newPoint.y then
        if closeEnough then
            return
        end
        table.insert(points, newPoint)
    end  -- if not self.closeEnough(rightPoint, newPoint) then
    local newRightPoint = newEdge:get_clippedEnds()[LR.other(newOrientation)]
    if not Site.closeEnough(points[1], newRightPoint) then
        table.insert(points, newRightPoint)
    end
end

function Site:get_x()
    return self._coord.x
end

function Site:get_y()
    return self._coord.y
end

function Site:dist(p)
    return Point.distance(p:get_coord(), self._coord)
end

return Site
