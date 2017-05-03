--[[
 * Lua implementaition by Marco Qin(marcoqin.github.io). Pretty much a 1:1
 * translation of a wonderful map generating algorthim by Amit Patel of Red Blob Games,
 * which can be found here (http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/)
 * Hopefully it's of use to someone out there who needed it in Lua like I did!
 * Note, the only island mode implemented is Radial. Implementing more is something for another day.
 *
 * FORTUNE'S ALGORTIHIM
 *
 * This is a Lua implementation of an AS3 (Flash) implementation of an algorthim
 * originally created in C++. Pretty much a 1:1 translation from as3 to Lua, save
 * for some necessary workarounds. Original as3 implementation by Alan Shaw (of nodename)
 * can be found here (https://github.com/nodename/as3delaunay). Original algorthim
 * by Steven Fortune (see lisence for c++ implementation below)
 *
 * The author of this software is Steven Fortune.  Copyright (c) 1994 by AT&T
 * Bell Laboratories.
 * Permission to use, copy, modify, and distribute this software for any
 * purpose without fee is hereby granted, provided that this entire notice
 * is included in all copies of any software which is or includes a copy
 * or modification of this software and in all copies of the supporting
 * documentation for such software.
 * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
 * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
 * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
--]]
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Edge = require(folderOfThisFile.."/Edge")
local EdgeList = require(folderOfThisFile.."/EdgeList")
local EdgeReorderer = require(folderOfThisFile.."/EdgeReorderer")
local Halfedge = require(folderOfThisFile.."/Halfedge")
local HalfedgePriorityQueue = require(folderOfThisFile.."/HalfedgePriorityQueue")
local LineSegment = require(folderOfThisFile.."/LineSegment")
local LR = require(folderOfThisFile.."/LR")
local Polygon = require(folderOfThisFile.."/Polygon")
local Site = require(folderOfThisFile.."/Site")
local SiteList = require(folderOfThisFile.."/SiteList")
local Vertex = require(folderOfThisFile.."/Vertex")
local Winding = require(folderOfThisFile.."/Winding")

local Voronoi = class("Voronoi")
math.random()
math.random()
math.random()

function Voronoi:get_plotBounds()
    return self._plotBounds
end

function Voronoi:dispose()
    if self._sites ~= nil then
        self._sites:dispose()
        self._sites = nil
    end
    if self._triangles ~= nil then
        for _, v in pairs(self._triangles) do
            v:dispose()
        end
        self._triangles = nil
    end
    if self._edges ~= nil then
        for _, v in pairs(self._edges) do
            v:dispose()
        end
        self._edges = nil
    end
    self._plotBounds = nil
    self._sitesIndexedByLocation = nil
end

function Voronoi:init(points, colors, plotBounds)
    self._sites = nil
    self._sitesIndexedByLocation = nil
    self._triangles = nil
    self._edges = nil
    self._plotBounds = nil
    self:setup(points, colors, plotBounds)
    self:fortunesAlgorithm()
end

function Voronoi:setup(points, colors, plotBounds)
    self._sites = SiteList()
    self._sitesIndexedByLocation = {}
    self:addSites(points, colors)
    self._plotBounds = plotBounds
    self._triangles = {}
    self._edges = {}
end

function Voronoi:addSites(points, colors)
    local length = #points
    for i = 1, length do
        self:addSite(points[i], colors ~= nil and colors[i] or 0, i)
    end
end

function Voronoi:addSite(p, color, index)
    local weight = math.random() * 100
    local site = Site.create(p, index, weight, color)
    self._sites:push(site)
    self._sitesIndexedByLocation[p] = site
end

function Voronoi:edges()
    return self._edges
end

function Voronoi:region(p)
    local site = self._sitesIndexedByLocation[p]
    if site == nil then
        return {}
    end
    return site:region(self._plotBounds)
end

function Voronoi:neighborSitesForSite(coord)
    local points = {}
    local site = self._sitesIndexedByLocation[coord]
    if site == nil then
        return points
    end
    local sites = site:neighborSites()
    for _, neighbor in pairs(sites) do
        table.insert(points, neighbor:get_coord())
    end
    return points
end

function Voronoi:circles()
    return self._sites:circles()
end

function Voronoi:selectEdgesForSitePoint(coord, edgesToTest)
    local filtered = {}
    for _, e in pairs(edgesToTest) do
        if (e:get_leftSite() ~= nil and e:get_leftSite():get_coord() == coord) or (e:get_rightSite() ~= nil and e:get_rightSite():get_coord() == coord) then
            table.insert(filtered, e)
        end
    end
    return filtered
end

function Voronoi:visibleLineSegments(edges)
    local segments = {}
    for _, edge in pairs(edges) do
        if edge:get_visible() then
            local p1 = edge:get_clippedEnds()[LR.LEFT]
            local p2 = edge:get_clippedEnds()[LR.RIGHT]
            table.insert(segments, LineSegment(p1, p2))
        end
    end
    return segments
end

function Voronoi:delaunayLinesForEdges(edges)
    local segments = {}
    for _, edge in pairs(edges) do
        table.insert(segments, edge:delaunayLine())
    end
    return segments
end

function Voronoi:voronoiBoundaryForSite(coord)
    return self:visibleLineSegments(self:selectEdgesForSitePoint(coord, self._edges))
end

function Voronoi:delaunayLinesForSite(coord)
    return self:delaunayLinesForEdges(self:selectEdgesForSitePoint(coord, self._edges))
end

function Voronoi:voronoiDiagram()
    return self:visibleLineSegments(self._edges)
end

function Voronoi:hull()
    return self:delaunayLinesForEdges(self:hullEdges())
end

function Voronoi:hullEdges()
    local filtered = {}
    for _, e in pairs(self._edges) do
        if e:isPartOfConvexHull() then
            table.insert(filtered, e)
        end
    end
    return filtered
end

function Voronoi:hullPointsInOrder()
    local hullEdges = self:hullEdges()
    local points = {}
    if #hullEdges == 0 then
        return points
    end

    local reorderer = EdgeReorderer(hullEdges, "Site")
    hullEdges = reorderer:get_edges()
    local orientations = reorderer:get_edgeOrientations()
    reorderer:dispose()

    local orientation
    local n = #hullEdges
    for i = 1, n do
        local edge = hullEdges[i]
        orientation = orientations[i]
        table.insert(points, edge:site(orientation):get_coord())
    end
    return points
end

function Voronoi:regions()
    return self._sites:regions(self._plotBounds)
end

function Voronoi:siteCoords()
    return self._sites:siteCoords()
end

function Voronoi:fortunesAlgorithm()
    local newSite, bottomSite, topSite, tempSite
    local v, vertex
    local newintstar = nil
    local leftRight
    local lbnd, rbnd, llbnd, rrbnd, bisector
    local edge

    local dataBounds = self._sites:getSitesBounds()

    local sqrt_nsites = math.floor(math.sqrt(self._sites:get_length() + 4))
    local heap = HalfedgePriorityQueue(dataBounds.y, dataBounds.height, sqrt_nsites)
    local edgeList = EdgeList(dataBounds.x, dataBounds.width, sqrt_nsites)
    local halfEdges = {}
    local vertices = {}

    local bottomMostSite = self._sites:next()
    newSite = self._sites:next()
    while true do
        if heap:empty() == false then
            newintstar = heap:min()
        end

        if newSite ~= nil and (heap:empty() or Voronoi.compareByYThenX(newSite, newintstar) < 0) then
            -- /* new site is smallest */

            -- // Step 8:
            lbnd = edgeList:edgeListLeftNeighbor(newSite:get_coord()) --	// the Halfedge just to the left of newSite
            rbnd = lbnd.edgeListRightNeighbor --		// the Halfedge just to the right
            bottomSite = self:rightRegion(lbnd, bottomMostSite)  --	// this is the same as leftRegion(rbnd)
            -- // this Site determines the region containing the new site

            -- // Step 9:
            edge = Edge.createBisectingEdge(bottomSite, newSite)
            table.insert(self._edges, edge)

            bisector = Halfedge.create(edge, LR.LEFT)
            table.insert(halfEdges, bisector)
            -- // inserting two Halfedges into edgeList constitutes Step 10:
            --// insert bisector to the right of lbnd:
            edgeList:insert(lbnd, bisector)

            -- // first half of Step 11:
            vertex = Vertex.intersect(lbnd, bisector)
            if vertex ~= nil then
                table.insert(vertices, vertex)
                heap:remove(lbnd)
                lbnd.vertex = vertex
                lbnd.ystar = vertex:get_y() + newSite:dist(vertex)
                heap:insert(lbnd)
            end

            lbnd = bisector
            bisector = Halfedge.create(edge, LR.RIGHT)
            table.insert(halfEdges, bisector)
            --// second Halfedge for Step 10:
            --// insert bisector to the right of lbnd:
            edgeList:insert(lbnd, bisector)

            --// second half of Step 11:
            vertex = Vertex.intersect(bisector, rbnd)
            if vertex ~= nil then
                table.insert(vertices, vertex)
                bisector.vertex = vertex
                bisector.ystar = vertex:get_y() + newSite:dist(vertex)
                heap:insert(bisector)
            end

            newSite = self._sites:next()


        elseif heap:empty() == false then
            -- /* intersection is smallest */
            lbnd = heap:extractMin()
            llbnd = lbnd.edgeListLeftNeighbor
            rbnd = lbnd.edgeListRightNeighbor
            rrbnd = rbnd.edgeListRightNeighbor
            bottomSite = self:leftRegion(lbnd, bottomMostSite)
            topSite = self:rightRegion(rbnd, bottomMostSite)
            --// these three sites define a Delaunay triangle
            --// (not actually using these for anything...)
            -- //_triangles.push(new Triangle(bottomSite, topSite, rightRegion(lbnd)));

            v = lbnd.vertex
            v:setIndex();
            lbnd.edge:setVertex(lbnd.leftRight, v)
            rbnd.edge:setVertex(rbnd.leftRight, v)
            edgeList:remove(lbnd)
            heap:remove(rbnd)
            edgeList:remove(rbnd)
            leftRight = LR.LEFT
            if bottomSite:get_y() > topSite:get_y() then
                tempSite = bottomSite
                bottomSite = topSite
                topSite = tempSite
                leftRight = LR.RIGHT
            end
            edge = Edge.createBisectingEdge(bottomSite, topSite)
            table.insert(self._edges, edge)
            bisector = Halfedge.create(edge, leftRight)
            table.insert(halfEdges, bisector)
            edgeList:insert(llbnd, bisector)
            edge:setVertex(LR.other(leftRight), v)
            vertex = Vertex.intersect(llbnd, bisector)
            if vertex ~= nil then
                table.insert(vertices, vertex)
                heap:remove(llbnd)
                llbnd.vertex = vertex
                llbnd.ystar = vertex:get_y() + bottomSite:dist(vertex)
                heap:insert(llbnd)
            end
            vertex = Vertex.intersect(bisector, rrbnd)
            if vertex ~= nil then
                table.insert(vertices, vertex)
                bisector.vertex = vertex
                bisector.ystar = vertex:get_y() + bottomSite:dist(vertex)
                heap:insert(bisector)
            end

        else
            break
        end -- if (newSite ~= nil and (heap:empty() or Voronoi.compareByYThenX(newSite, newintstar) < 0)) then
    end -- while true do

    heap:dispose()
    edgeList:dispose()

    for _, halfEdge in pairs(halfEdges) do
        halfEdge:reallyDispose()
    end
    halfEdges = {}

    --// we need the vertices to clip the edges
    for _, e in pairs(self._edges) do
        e:clipVertices(self._plotBounds)
    end
    --// but we don't actually ever use them again!
    for _, v0 in pairs(vertices) do
        v0:dispose()
    end
    vertices = {}
end

function Voronoi:leftRegion(he, bottomMostSite)
    local edge = he.edge
    if edge == nil then
        return bottomMostSite
    end
    return edge:site(he.leftRight)
end

function Voronoi:rightRegion(he, bottomMostSite)
    local edge = he.edge
    if edge == nil then
        return bottomMostSite
    end
    return edge:site(LR.other(he.leftRight))
end

-- static methods
function Voronoi.compareByYThenX(s1, s2)
    -- s1, s2: type(Site)
    if s1:get_y() < s2:get_y() then return -1 end
    if s1:get_y() > s2:get_y() then return 1 end
    if s1:get_x() < s2:get_x() then return -1 end
    if s1:get_x() > s2:get_x() then return 1 end
    return 0
end

function Voronoi.compareByYThenX_withPoint(s1, s2)
    -- s1: type(Site), s2: type(Point)
    if s1:get_y() < s2.y then return -1 end
    if s1:get_y() > s2.y then return 1 end
    if s1:get_x() < s2.x then return -1 end
    if s1:get_x() > s2.x then return 1 end
    return 0
end

return Voronoi
