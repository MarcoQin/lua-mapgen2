local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Stack = require(folderOfThisFile.."/Stack")
local LR = require(folderOfThisFile.."/LR")

local Vertex = class("Vertex")

local NaN = 0/0

local _pool = Stack()
local _nvertices = 1


local function compareByYThenX(s1, s2)
    -- s1, s2: type(Site)
    if s1:get_y() < s2:get_y() then return -1 end
    if s1:get_y() > s2:get_y() then return 1 end
    if s1:get_x() < s2:get_x() then return -1 end
    if s1:get_x() > s2:get_x() then return 1 end
    return 0
end

local function isNaN(x)
    return x ~= x
end

-- static method
function Vertex.create(x, y)
    if isNaN(x) or isNaN(y) then
        return Vertex.VERTEX_AT_INFINITY
    end
    if _pool:size() > 0 then
        return _pool:pop():setup(x, y)
    else
        return Vertex(x, y)
    end
end

function Vertex:get_coord()
    return self._coord
end

function Vertex:get_vertexIndex()
    return self._vertexIndex
end

function Vertex:init(x, y)
    self._vertexIndex = 1
    self:setup(x, y)
end

function Vertex:setup(x, y)
    self._coord = Point(x, y)
    return self
end

function Vertex:dispose()
    self._coord = nil
    _pool:push(self)
end

function Vertex:setIndex()
    self._vertexIndex = _nvertices
    _nvertices = _nvertices + 1
end

function Vertex:__tostring()
    return "Vertex ("..tostring(self._vertexIndex)..")"
end

--[[
     * This is the only way to make a Vertex
     *
     * @param halfedge0
     * @param halfedge1
     * @return
     *
--]]
-- static method
function Vertex.intersect(halfedge0, halfedge1)
    local edge0, edge1, edge
    local halfedge
    local determinant = 0.0
    local intersectionX = 0.0
    local intersectionY = 0.0
    local rightOfSite = false

    edge0 = halfedge0.edge
    edge1 = halfedge1.edge
    if edge0 == nil or edge1 == nil then
        return nil
    end
    if edge0:get_rightSite() == edge1:get_rightSite() then
        return nil
    end

    determinant = edge0.a * edge1.b - edge0.b * edge1.a
    if (-1.0e-10 < determinant) and (determinant < 1.0e-10) then
        -- the edges are parallel
        return nil
    end

    intersectionX = (edge0.c * edge1.b - edge1.c * edge0.b) / determinant
    intersectionY = (edge1.c * edge0.a - edge0.c * edge1.a) / determinant

    if (compareByYThenX(edge0:get_rightSite(), edge1:get_rightSite()) < 0) then
        halfedge = halfedge0
        edge = edge0
    else
        halfedge = halfedge1
        edge = edge1
    end
    rightOfSite = intersectionX >= edge:get_rightSite():get_x()
    if (rightOfSite and halfedge.leftRight == LR.LEFT) or (not rightOfSite and halfedge.leftRight == LR.RIGHT) then
        return nil
    end

    return Vertex.create(intersectionX, intersectionY)
end

function Vertex:get_x()
    return self._coord.x
end

function Vertex:get_y()
    return self._coord.y
end

Vertex.VERTEX_AT_INFINITY = Vertex(NaN, NaN)

return Vertex
