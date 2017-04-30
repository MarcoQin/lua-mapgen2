local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Stack = require(folderOfThisFile.."/Stack")
local LR = require(folderOfThisFile.."/LR")

local Halfedge = class("Halfedge")

local _pool = Stack()

-- static method
function Halfedge.create(edge, lr)
    if _pool:size() > 0 then
        return _pool:pop():setup(edge, lr)
    else
        return Halfedge(edge, lr)
    end
end

-- static method
function Halfedge.createDummy()
    return Halfedge.create(nil, nil)
end

function Halfedge:init(edge, lr)
    self.edgeListLeftNeighbor = nil
    self.edgeListRightNeighbor = nil
    self.nextInPriorityQueue = nil
    self.edge = nil
    self.leftRight = nil
    self.vertex = nil

    -- the vertex's y-coordinate in the transformed Voronoi space V*
    self.ystar = 0

    self:setup(edge, lr)
end

function Halfedge:setup(edge, lr)
    self.edge = edge
    self.leftRight = lr
    self.nextInPriorityQueue = nil
    self.vertex = nil
    return self
end

function Halfedge:__tostring()
    return "Halfedge (leftRight: "..tostring(leftRight).."; vertex: "..tostring(vertex)..")"
end

function Halfedge:dispose()
    if self.edgeListLeftNeighbor ~= nil or self.edgeListRightNeighbor ~= nil then return end
    if self.nextInPriorityQueue ~= nil then return end
    self.edge = nil
    self.leftRight = nil
    self.vertex = nil
    _pool:push(self)
end

function Halfedge:reallyDispose()
    self.edgeListLeftNeighbor = nil
    self.edgeListRightNeighbor = nil
    self.nextInPriorityQueue = nil
    self.edge = nil
    self.leftRight = nil
    self.vertex = nil
    _pool:push(self)
end

function Halfedge:isLeftOf(p)
    -- p: type(Point)
    local topSite = nil  -- type(Site)
    local rightOfSite = false
    local above = false
    local fast = false
    local dxp, dyp, dxs, t1, t2, t3, yl

    topSite = self.edge:get_rightSite()
    rightOfSite = p.x > topSite:get_x()
    if rightOfSite and self.leftRight == LR.LEFT then
        return true
    end
    if not rightOfSite and self.leftRight == LR.RIGHT then
        return false
    end

    if self.edge.a == 1.0 then
        dyp = p.y - topSite:get_y()
        dxp = p.x - topSite:get_x()
        fast = false
        if (not rightOfSite and self.edge.b < 0.0) or (rightOfSite and self.edge.b >= 0.0) then
            above = dyp >= self.edge.b * dxp
            fast = above
        else
            above = (p.x + p.y * self.edge.b) > self.edge.c
            if self.edge.b < 0.0 then
                above = not above
            end
            if not above then
                fast = true
            end
        end
        if not fast then
            dxs = topSite:get_x() - self.edge:get_leftSite():get_x()
            above = self.edge.b * (dxp * dxp - dyp * dyp) < dxs * dyp * (1.0 + 2.0 * dxp / dxs + self.edge.b * self.edge.b)
            if self.edge.b < 0.0 then
                above = not above
            end
        end
    else  -- self.edge.b == 1.0
        yl = self.edge.c - self.edge.a * p.x
        t1 = p.y - yl
        t2 = p.x - topSite:get_x()
        t3 = yl - topSite:get_y()
        above = t1 * t1 > t2 * t2 + t3 * t3
    end
    if self.leftRight ~= LR.LEFT then
        above = not above
    end
    return above
end

return Halfedge
