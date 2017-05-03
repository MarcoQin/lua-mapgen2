local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Stack = require(folderOfThisFile.."/Stack")
local LineSegment = require(folderOfThisFile.."/LineSegment")
local LR = require(folderOfThisFile.."/LR")

local Edge = class("Edge")

-- static members
local _pool = Stack()
local _nedges = 0
Edge.DELETED = Edge()

-- static method
function Edge.createBisectingEdge(site0, site1)
    local dx, dy, absdx, absdy
    local a, b, c

    dx = site1:get_x() - site0:get_x()
    dy = site1:get_y() - site0:get_y()
    absdx = math.abs(dx)
    absdy = math.abs(dy)
    c = site0:get_x() * dx + site0:get_y() * dy + (dx * dx + dy * dy) * 0.5
    if absdx > absdy then
        a = 1.0
        b = dy / dx
        c = c / dx
    else
        b = 1.0
        a = dx / dy
        c = c / dy
    end

    local edge = Edge.create()

    edge:set_leftSite(site0)
    edge:set_rightSite(site1)
    site0:addEdge(edge)
    site1:addEdge(edge)

    edge._leftVertex = nil
    edge._rightVertex = nil

    edge.a = a
    edge.b = b
    edge.c = c

    return edge
end

-- static method
function Edge.create()
    local edge = nil
    if _pool:size() > 0 then
        edge = _pool:pop()
        edge:setup()
    else
        edge = Edge()
    end
    return edge
end

function Edge:delaunayLine()
    return LineSegment(self:get_leftSite():get_coord(), self:get_rightSite():get_coord())
end

function Edge:voronoiEdge()
    if not self:get_visible() then
        return LineSegment(nil, nil)
    end
    return LineSegment(self._clippedVertices[LR.LEFT], self._clippedVertices[LR.RIGHT])
end

function Edge:get_leftVertex()
    return self._leftVertex
end

function Edge:get_rightVertex()
    return self._rightVertex
end

function Edge:vertex(leftRight)
    if leftRight == LR.LEFT then return self._leftVertex else return self._rightVertex end
end

function Edge:setVertex(leftRight, v)
    if leftRight == LR.LEFT then
        self._leftVertex = v
    else
        self._rightVertex = v
    end
end

function Edge:isPartOfConvexHull()
    return self._leftVertex == nil or self._rightVertex == nil
end

function Edge:sitesDistance()
    return Point.distance(self:get_leftSite():get_coord(), self:get_rightSite():get_coord())
end

-- static method
function Edge.compareSitesDistances_MAX(edge0, edge1)
    local len0 = edge0:sitesDistance()
    local len1 = edge1:sitesDistance()
    if len0 < len1 then return 1 end
    if len0 > len1 then return -1 end
    return 0
end

-- static method
function Edge.compareSitesDistances(edge0, edge1)
    return Edge.compareSitesDistances_MAX(edge0, edge1)
end

function Edge:get_clippedEnds()
    return self._clippedVertices
end

function Edge:get_visible()
    return self._clippedVertices ~= nil
end

function Edge:set_leftSite(s)
    self._sites[LR.LEFT] = s
end

function Edge:get_leftSite()
    return self._sites[LR.LEFT]
end

function Edge:set_rightSite(s)
    self._sites[LR.RIGHT] = s
end

function Edge:get_rightSite()
    return self._sites[LR.RIGHT]
end

function Edge:site(leftRight)
    return self._sites[leftRight]
end

function Edge:dispose()
    self._leftVertex = nil
    self._rightVertex = nil
    self._clippedVertices = nil
    self._sites = nil

    _pool:push(self)
end

function Edge:init()
    self._clippedVertices = nil  -- table
    self._sites = nil  -- table
    self.a = 0.0
    self.b = 0.0
    self.c = 0.0
    self._leftVertex = nil
    self._rightVertex = nil
    self._edgeIndex = _nedges
    _nedges = _nedges + 1

    self:setup()
end

function Edge:setup()
    self._sites = {}
end

function Edge:__tostring()
    local s = "Edge "..tostring(self._edgeIndex).."; sites "..tostring(self._sites[LR.LEFT])..", "..tostring(self._sites[LR.RIGHT])
    s = s.."; endVertices "..tostring(self._leftVertex ~= nil and self._leftVertex:get_vertexIndex() or "null")..", "
    s = s..tostring(self._rightVertex ~= nil and self._rightVertex:get_vertexIndex() or "null").."::"
    return s
end

function Edge:clipVertices(bounds)
    -- bounds: type(Rectangle)
    local xmin = bounds.x
    local ymin = bounds.y
    local xmax = bounds.right
    local ymax = bounds.bottom

    local vertex0, vertex1
    local x0, x1, y0, y1

    if self.a == 1.0 and self.b >= 0.0 then
        vertex0 = self._rightVertex
        vertex1 = self._leftVertex
    else
        vertex0 = self._leftVertex
        vertex1 = self._rightVertex
    end

    if self.a == 1.0 then
        y0 = ymin
        if vertex0 ~= nil and vertex0:get_y() > ymin then
            y0 = vertex0:get_y()
        end
        if y0 > ymax then
            return
        end
        x0 = self.c - self.b * y0

        y1 = ymax
        if vertex1 ~= nil and vertex1:get_y() < ymax then
            y1 = vertex1:get_y()
        end
        if y1 < ymin then
            return
        end
        x1 = self.c - self.b * y1

        if (x0 > xmax and x1 > xmax) or (x0 < xmin and x1 < xmin) then
            return
        end

        if x0 > xmax then
            x0 = xmax
            y0 = (self.c - x0) / self.b
        elseif x0 < xmin then
            x0 = xmin
            y0 = (self.c - x0) / self.b
        end

        if x1 > xmax then
            x1 = xmax
            y1 = (self.c - x1) / self.b
        elseif x1 < xmin then
            x1 = xmin
            y1 = (self.c - x1) / self.b
        end
    else -- if a == 1.0 then
        x0 = xmin
        if vertex0 ~= nil and vertex0:get_x() > xmin then
            x0 = vertex0:get_x()
        end
        if x0 > xmax then
            return
        end
        y0 = self.c - self.a * x0

        x1 = xmax
        if vertex1 ~= nil and vertex1:get_x() < xmax then
            x1 = vertex1:get_x()
        end
        if x1 < xmin then
            return
        end
        y1 = self.c - self.a * x1

        if (y0 > ymax and y1 > ymax) or (y0 < ymin and y1 < ymin) then
            return
        end

        if y0 > ymax then
            y0 = ymax
            x0 = (self.c - y0) / self.a
        elseif y0 < ymin then
            y0 = ymin
            x0 = (self.c - y0) / self.a
        end

        if y1 > ymax then
            y1 = ymax
            x1 = (self.c - y1) / self.a
        elseif y1 < ymin then
            y1 = ymin
            x1 = (self.c - y1) / self.a
        end
    end  -- if a == 1.0 then

    self._clippedVertices = {}
    if vertex0 == self._leftVertex then
        self._clippedVertices[LR.LEFT] = Point(x0, y0)
        self._clippedVertices[LR.RIGHT] = Point(x1, y1)
    else
        self._clippedVertices[LR.RIGHT] = Point(x0, y0)
        self._clippedVertices[LR.LEFT] = Point(x1, y1)
    end
end


return Edge
