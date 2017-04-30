local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Halfedge = require(folderOfThisFile.."/Halfedge")

local HalfedgePriorityQueue = class("HalfedgePriorityQueue")

function HalfedgePriorityQueue:init(ymin, deltay, sqrt_nsites)
    self._count = 0
    self._minBucket = 1
    self._ymin = ymin
    self._deltay = deltay
    self._hashsize = 4 * sqrt_nsites
    self._hash = nil

    self:initialize()
end

function HalfedgePriorityQueue:dispose()
    for i = 1, self._hashsize do
        self._hash[i]:dispose()
    end
    self._hash = nil
end

function HalfedgePriorityQueue:initialize()
    local i
    self._count = 0
    self._minBucket = 1
    self._hash = {}

    for i = 1, self._hashsize do
        self._hash[i] = Halfedge.createDummy()
        self._hash[i].nextInPriorityQueue = nil
    end
end

function HalfedgePriorityQueue:insert(halfEdge)
    local previous, _next
    local insertionBucket = self:bucket(halfEdge)
    if insertionBucket < self._minBucket then
        self._minBucket = insertionBucket
    end
    previous = self._hash[insertionBucket]
    _next = previous.nextInPriorityQueue
    while _next ~= nil and (halfEdge.ystar > _next.ystar or (halfEdge.ystar == _next.ystar and halfEdge.vertex:get_x() > _next.vertex:get_x())) do
        previous = _next
        _next = previous.nextInPriorityQueue
    end
    halfEdge.nextInPriorityQueue = previous.nextInPriorityQueue
    previous.nextInPriorityQueue = halfEdge
    self._count = self._count + 1
end

function HalfedgePriorityQueue:remove(halfEdge)
    local previous
    local removalBucket = self:bucket(halfEdge)

    if halfEdge.vertex ~= nil then
        previous = self._hash[removalBucket]
        while previous.nextInPriorityQueue ~= halfEdge do
                previous = previous.nextInPriorityQueue
        end
        previous.nextInPriorityQueue = halfEdge.nextInPriorityQueue
        self._count = self._count - 1
        halfEdge.vertex = nil
        halfEdge.nextInPriorityQueue = nil
        halfEdge:dispose()
    end
end

function HalfedgePriorityQueue:bucket(halfEdge)
    local theBucket = math.floor((halfEdge.ystar - self._ymin) / self._deltay * self._hashsize)
    if (theBucket < 1) then
        theBucket = 1
    end
    if (theBucket > self._hashsize) then
        theBucket = self._hashsize
    end
    return theBucket;
end

function HalfedgePriorityQueue:isEmpty(bucket)
    return self._hash[bucket].nextInPriorityQueue == nil
end

-- move _minBucket until it contains an actual Halfedge (not just the dummy
--      * at the top);
function HalfedgePriorityQueue:adjustMinBucket()
     while self._minBucket < self._hashsize and self:isEmpty(self._minBucket) do
        self._minBucket = self._minBucket + 1
    end
end

function HalfedgePriorityQueue:empty()
    return self._count == 0
end

--  @return coordinates of the Halfedge's vertex in V*, the transformed
--       * Voronoi diagram
function HalfedgePriorityQueue:min()
    self:adjustMinBucket()
    local answer = self._hash[self._minBucket].nextInPriorityQueue
    return Point(answer.vertex:get_x(), answer.ystar)
end

-- remove and return the min Halfedge
function HalfedgePriorityQueue:extractMin()
    local answer
    answer = self._hash[self._minBucket].nextInPriorityQueue
    self._hash[self._minBucket].nextInPriorityQueue = answer.nextInPriorityQueue
    self._count = self._count - 1
    answer.nextInPriorityQueue = nil

    return answer
end


return HalfedgePriorityQueue

