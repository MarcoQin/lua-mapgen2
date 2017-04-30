local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local LR = require(folderOfThisFile.."/LR")
local Vertex = require(folderOfThisFile.."/Vertex")

local EdgeReorderer = class("EdgeReorderer")

function EdgeReorderer:get_edges()
    return self._edges
end

function EdgeReorderer:get_edgeOrientations()
    return self._edgeOrientations
end

function EdgeReorderer:init(origEdges, criterion)
    self._edges = {}
    self._edgeOrientations = {}
    if #origEdges > 0 then
        self._edges = self:reorderEdges(origEdges, criterion)
    end
end

function EdgeReorderer:dispose()
    self._edges = nil
    self._edgeOrientations = nil
end

function EdgeReorderer:reorderEdges(origEdges, criterion)
    print("EdgeReorderer:reorderEdges")
    print(criterion == Vertex)
    print(criterion)
    local i, j
    local n = #origEdges
    local edge
    local done = {}
    local nDone = 0
    for k = 1, n do
        table.insert(done, false)
    end
    local newEdges = {}

    i = 1
    edge = origEdges[i]
    table.insert(newEdges, edge)
    table.insert(self._edgeOrientations, LR.LEFT)
    -- local firstPoint = criterion == Vertex and edge:get_leftVertex() or edge:get_leftSite()
    -- local lastPoint = criterion == Vertex and edge:get_rightVertex() or edge:get_rightSite()
    local firstPoint, lastPoint
    print("fist edge", edge)
    if criterion == "Vertex" then
        firstPoint = edge:get_leftVertex()
    else
        firstPoint = edge:get_leftSite()
    end
    if criterion == "Vertex" then
        lastPoint = edge:get_rightVertex()
    else
        lastPoint = edge:get_rightSite()
    end
    print(firstPoint, lastPoint)


    if (firstPoint == Vertex.VERTEX_AT_INFINITY or lastPoint == Vertex.VERTEX_AT_INFINITY) then
        return {}
    end
    if (firstPoint == nil or lastPoint == nil) then
        return {}
    end
    done[i] = true
    nDone = nDone + 1

    while nDone < n do
    -- while nDone <= 0 do
        for i = 2, n do
            -- print(i, n)
            if not done[i] then
                -- print('i: ', i, 'done[i]', done[i])
                edge = origEdges[i]
                local leftPoint, rightPoint
                if criterion == "Vertex" then
                    leftPoint = edge:get_leftVertex()
                else
                    leftPoint = edge:get_leftSite()
                end
                if criterion == "Vertex" then
                    rightPoint = edge:get_rightVertex()
                else
                    rightPoint = edge:get_rightSite()
                end
                -- local leftPoint = criterion == Vertex and edge:get_leftVertex() or edge:get_leftSite()
                -- local rightPoint = criterion == Vertex and edge:get_rightVertex() or edge:get_rightSite()
                if leftPoint == Vertex.VERTEX_AT_INFINITY or rightPoint == Vertex.VERTEX_AT_INFINITY then
                    return {}
                end
                if leftPoint == nil or rightPoint == nil then
                    return {}
                end
                print("----")
                print(leftPoint, rightPoint, firstPoint, lastPoint)
                print(leftPoint == firstPoint)
                print(leftPoint == lastPoint)
                print(rightPoint == firstPoint)
                print(rightPoint == lastPoint)
                print("----")
                if leftPoint == lastPoint then
                    lastPoint = rightPoint
                    table.insert(self._edgeOrientations, LR.LEFT)
                    table.insert(newEdges, edge)
                    done[i] = true
                elseif rightPoint == firstPoint then
                    firstPoint = leftPoint;
                    table.insert(self._edgeOrientations, 1, LR.LEFT)
                    table.insert(newEdges, 1, edge)
                    done[i] = true
                elseif leftPoint == firstPoint then
                    firstPoint = rightPoint;
                    table.insert(self._edgeOrientations, 1, LR.RIGHT)
                    table.insert(newEdges, 1, edge)
                    done[i] = true
                elseif rightPoint == lastPoint then
                    lastPoint = leftPoint;
                    table.insert(self._edgeOrientations, LR.RIGHT)
                    table.insert(newEdges, edge)
                    done[i] = true
                end
                if done[i] then
                    print(nDone, n)
                    nDone = nDone + 1
                end
            end
        end
    end
    print("finish wile loop")

    return newEdges
end

return EdgeReorderer
