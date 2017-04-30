local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Halfedge = require(folderOfThisFile.."/Halfedge")
local Edge = require(folderOfThisFile.."/Edge")

local EdgeList = class("EdgeList")

function EdgeList:dispose()
    local halfEdge = self.leftEnd
    local prevHe = nil
    while halfEdge ~= self.rightEnd do
        prevHe =  halfEdge
        halfEdge = halfEdge.edgeListRightNeighbor
        prevHe:dispose()
    end
    self.leftEnd = nil
    self.rightEnd:dispose()
    self.rightEnd = nil

    self._hash = nil
end

function EdgeList:init(xmin, deltax, sqrt_nsites)
    self._xmin = xmin
    self._deltax = deltax
    self._hashsize = 2 * sqrt_nsites
    self._hash = {}

    self.leftEnd = Halfedge.createDummy()
    self.rightEnd = Halfedge.createDummy()
    self.leftEnd.edgeListLeftNeighbor = nil
    self.leftEnd.edgeListRightNeighbor = self.rightEnd
    self.rightEnd.edgeListLeftNeighbor = self.leftEnd
    self.rightEnd.edgeListRightNeighbor = nil

    self._hash[1] = self.leftEnd
    self._hash[self._hashsize] = self.rightEnd
end

-- Insert newHalfedge to the right of lb
function EdgeList:insert(lb, newHalfedge)
    newHalfedge.edgeListLeftNeighbor = lb
    newHalfedge.edgeListRightNeighbor = lb.edgeListRightNeighbor
    lb.edgeListRightNeighbor.edgeListLeftNeighbor = newHalfedge
    lb.edgeListRightNeighbor = newHalfedge
end

-- This function only removes the Halfedge from the left-right list. We
-- cannot dispose it yet because we are still using it.
function EdgeList:remove(halfEdge)
    halfEdge.edgeListLeftNeighbor.edgeListRightNeighbor = halfEdge.edgeListRightNeighbor
    halfEdge.edgeListRightNeighbor.edgeListLeftNeighbor = halfEdge.edgeListLeftNeighbor
    halfEdge.edge = Edge.DELETED
    halfEdge.edgeListLeftNeighbor = nil
    halfEdge.edgeListRightNeighbor = nil
end

-- Find the rightmost Halfedge that is still left of p
function EdgeList:edgeListLeftNeighbor(p)
    local i, bucket
    local halfEdge

    -- /* Use hash table to get close to desired halfedge */
    bucket = math.floor((p.x - self._xmin) / self._deltax * self._hashsize)
    if bucket < 1 then bucket = 1 end
    if bucket > self._hashsize then
        bucket = self._hashsize
    end

    halfEdge = self:getHash(bucket)
    if halfEdge == nil then
        -- TODO: fuc
        -- for i = 2, self._hashsize do
        for i = 1, self._hashsize do
            halfEdge = self:getHash(bucket - i)
            if halfEdge ~= nil then break end
            halfEdge = self:getHash(bucket + i)
            if halfEdge ~= nil then break end
        end
    end
    -- * Now search linear list of halfedges for the correct one */
    if halfEdge == self.leftEnd or (halfEdge ~= self.rightEnd and halfEdge:isLeftOf(p)) then
        print(halfEdge.edgeListRightNeighbor ~= self.rightEnd)
        halfEdge = halfEdge.edgeListRightNeighbor
        while halfEdge ~= self.rightEnd and halfEdge:isLeftOf(p) do
            halfEdge = halfEdge.edgeListRightNeighbor
        end
        -- repeat
            -- halfEdge = halfEdge.edgeListRightNeighbor
        -- until(halfEdge ~= self.rightEnd and halfEdge:isLeftOf(p))
        halfEdge = halfEdge.edgeListLeftNeighbor
    else
        halfEdge = halfEdge.edgeListLeftNeighbor
        while(halfEdge ~= self.leftEnd and halfEdge:isLeftOf(p)) do
            halfEdge = halfEdge.edgeListLeftNeighbor
        end
        -- repeat
            -- halfEdge = halfEdge.edgeListLeftNeighbor
        -- until(halfEdge ~= self.leftEnd and halfEdge:isLeftOf(p))
    end

    -- Update hash table and reference counts
    if bucket > 1 and bucket < self._hashsize then
        self._hash[bucket] = halfEdge
    end
    return halfEdge
end

function EdgeList:getHash(b)
    local halfEdge

    if b < 1 or b > self._hashsize then
        return nil
    end
    halfEdge = self._hash[b]
    if halfEdge ~= nil and halfEdge.edge == Edge.DELETED then
        self._hash[b] = nil
        return nil
    else
        return halfEdge
    end
end

return EdgeList
