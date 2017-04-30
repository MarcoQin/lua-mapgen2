local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
require(folderOfThisFile.."/PM_PRNG")
require(folderOfThisFile.."/graph")
local class = require(folderOfThisFile.."/as3delaunay/middleclass")
local Voronoi = require(folderOfThisFile.."/as3delaunay/Voronoi")
local LineSegment = require(folderOfThisFile.."/as3delaunay/LineSegment")

local IslandShape = class("IslandShape")
--[[
   This class has factory functions for generating islands of
   different shapes. The factory returns a function that takes a
   normalized point (x and y are -1 to +1) and returns true if the
   point should be on the island, and false if it should be water
   (lake or ocean).
--]]

-- The radial island radius is based on overlapping sine waves
IslandShape.ISLAND_FACTOR = 1.07  -- 1.0 means no small islands; 2.0 leads to a lot

function IslandShape.makeRadial(seed)
    local islandRandom = PM_PRNG()
    islandRandom.seed = seed
    local bumps = islandRandom:nextIntRange(1, 6)
    local startAngle = islandRandom:nextDoubleRange(0, 2*math.pi)
    local dipAngle = islandRandom:nextDoubleRange(0, 2*math.pi)
    local dipWidth = islandRandom:nextDoubleRange(0.2, 0,7)

    local function inside(q)
        local angle = math.atan2(q.y, q.x)
        local length = 0.5 * (math.max(math.abs(q.x), math.abs(q.y)) + q:length())

        local r1 = 0.5 + 0.4*math.sin(startAngle + bumps *angle + math.cos((bumps+3)*angle))
        local r2 = 0.7 - 0.4*math.sin(startAngle + bumps *angle - math.sin((bumps+2)*angle))
        if (math.abs(angle - dipAngle) < dipWidth) or
            (math.abs(angle - dipAngle + 2*math.pi) < dipWidth) or
            (math.abs(angle - dipAngle - 2*math.pi) < dipWidth) then
            r1 = 0.2
            r2 = r1
        end
        return length < r1 or (length > r1*IslandShape.ISLAND_FACTOR and length < r2)
    end

    return inside
end

function IslandShape.makePerlin(seed)
end

function IslandShape.makeSquare(seed)
    local function inside(q)
        return true
    end

    return inside
end

function IslandShape.makeBlob(seed)
    local function inside(q)
        local eye1 = Point(q.x-0.2, q.y/2+0.2):length() < 0.05
        local eye2 = Point(q.x+0.2, q.y/2+0.2):length() < 0.05
        local body = q:length() < (0.8 - 0.18*math.sin(5*math.atan2(q.y, q.x)))
        return body and (not eye1) and (not eye2)
    end

    return inside
end


--Factory class to choose points for the graph
local PointSelector = class("PointSelector")

PointSelector.NUM_LLOYD_RELAXATIONS = 2

--[[
 The square and hex grid point selection remove randomness from
 where the points are; we need to inject more randomness elsewhere
 to make the maps look better. I do this in the corner
 elevations. However I think more experimentation is needed.
]]--
function PointSelector.needsMoreRandomness(_type)
    return _type == 'Square' or _type == 'Hexagon'
end

-- Generate points at random locations
function PointSelector.generateRandom(size, seed)
    local function f(numPoints)
        local mapRandom = PM_PRNG()
        mapRandom.seed = seed
        local p, i
        local points = {}
        for i = 1, numPoints do
            p = Point(mapRandom:nextDoubleRange(10, size-10), mapRandom:nextDoubleRange(10, size-10))
            table.insert(points, p)
        end
        return points
    end
    return f
end

-- Improve the random set of points with Lloyd Relaxation
function PointSelector.generateRelaxed(size, seed)
    local function f(numPoints)
        local i, p, q, voronoi, region
        local points = PointSelector.generateRandom(size, seed)(numPoints)
        for i = 1, PointSelector.NUM_LLOYD_RELAXATIONS do
            voronoi = Voronoi(points, nil, Rectangle(0, 0, size, size))
            for _, p in pairs(points) do
                region = voronoi:region(p)
                p.x = 0.0
                p.y = 0.0
                for _, q in pairs(region) do
                    p.x = p.x + q.x
                    p.y = p.y + q.y
                end
                p.x = p.x / #region
                p.y = p.y / #region
                region = nil
            end
            voronoi:dispose()
        end
        return points
    end
    return f
end

function PointSelector.generateSquare(size, seed)
    local function f(numPoints)
        local points = {}
        local N = math.sqrt(numPoints)
        for x=0, N-1 do
            for y = 0, N-1 do
                table.insert(points, Point((0.5 + x)/N * size, (0.5 + y)/N * size))
            end
        end
        return points
    end
    return f
end

function PointSelector.generateHexagon(size, seed)
    local function f(numPoints)
        local points = {}
        local N = math.sqrt(numPoints)
        for x = 0, N-1 do
            for y = 0, N-1 do
                table.insert(points, Point((0.5+x)/N * size, (0.25 + 0.5 * x%2 +y)/N *size))
            end
        end
        return points
    end
    return f
end


------------------------------------------

local Map = class("Map")

local LAKE_THRESHOLD = 0.3  -- 0 to 1, fraction of water corners for water polygon
local SIZE = 0

function Map:init(size)
    SIZE = size
    self.numPoints = 1
    self.islandShape = nil
    self.mapRandom = PM_PRNG()
    self.needsMoreRandomness = false
    self.pointSelector = nil
    self.points = nil
    self.centers = nil
    self.corners = nil
    self.edges = nil
    self:reset()
end

function Map:newIsland(islandType, pointType, numPoints_, seed, variant)
    self.islandShape = IslandShape['make'..islandType](seed)
    self.pointSelector = PointSelector['generate'..pointType](SIZE, seed)
    self.needsMoreRandomness = PointSelector.needsMoreRandomness(pointType)
    self.numPoints = numPoints_
    self.mapRandom.seed = variant
end

function Map:reset()
    self.points = {}
    self.edges = {}
    self.centers = {}
    self.corners = {}
end

function Map:go()
    -- Place points
    self:reset()
    self.points = self.pointSelector(self.numPoints)


    --[[
    Create a graph structure from the Voronoi edge list. The
    methods in the Voronoi object are somewhat inconvenient for
    my needs, so I transform that data into the data I actually
    need: edges connected to the Delaunay triangles and the
    Voronoi polygons, a reverse map from those four points back
    to the edge, a map from these four points to the points
    they connect to (both along the edge and crosswise).
    ]]--
    -- Build graph
    local voronoi = Voronoi(self.points, nil, Rectangle(0, 0, SIZE, SIZE))
    print('before buildGraph: points:'..tostring(#self.points))
    self:buildGraph(self.points, voronoi)
    print('finish buildGraph ')
    self:improveCorners()
    print('finish improve Corners')
    voronoi:dispose()
    self.points = nil


    -- Assign elevations..
    -- Determine the elevations and water at Voronoi corners.
    print('Assign elevations..')
    self:assignCornerElevations()
    -- Determine polygon and corner type: ocean, coast, land.
    self:assignOceanCoastAndLand()
    -- Rescale elevations so that the highest is 1.0, and they're
    -- distributed well. We want lower elevations to be more common
    -- than higher elevations, in proportions approximately matching
    -- concentric rings. That is, the lowest elevation is the
    -- largest ring around the island, and therefore should more
    -- land area than the highest elevation, which is the very
    -- center of a perfectly circular island.
    self:redistributeElevations(self:landCorners(self.corners))
    -- Assign elevations to non-land corners
    for _, q in pairs(self.corners) do
        if q.ocean or q.coast then
            q.elevation = 0.0
        end
    end
    -- Polygon elevations are the average of their corner
    self:assignPolygonElevations()
    print('Finish Assign elevations..')


    -- Assign moisture
    -- Determine downslope paths.
    self:calculateDownslopes()
    -- Determine watersheds: for every corner, where does it flow
    -- out into the ocean?
    self:calculateWatersheds()


    -- Create rivers.
    -- self:createRivers()



    -- Determine moisture at corners, starting at rivers
    -- and lakes, but not oceans. Then redistribute
    -- moisture to cover the entire range evenly from 0.0
    -- to 1.0. Then assign polygon moisture as the average
    -- of the corner moisture.
    self:assignCornerMoisture()
    self:redistributeMoisture(self:landCorners(self.corners))
    self:assignPolygonMoisture()


    --Decorate map
    self:assignBiomes()
end

-- Although Lloyd relaxation improves the uniformity of polygon
-- sizes, it doesn't help with the edge lengths. Short edges can
-- be bad for some games, and lead to weird artifacts on
-- rivers. We can easily lengthen short edges by moving the
-- corners, but **we lose the Voronoi property**.  The corners are
-- moved to the average of the polygon centers around them. Short
-- edges become longer. Long edges tend to become shorter. The
-- polygons tend to be more uniform after this step.
function Map:improveCorners()
    local newCorners = {}
    local q, r, point, i, edge;

    -- First we compute the average of the centers next to each corner.
    for _, q in pairs(self.corners) do
        if (q.border) then
            newCorners[q.index] = q.point
        else
            point = Point(0.0, 0.0)
            for _, r in pairs(q.touches) do
                point.x = point.x + r.point.x
                point.y = point.y + r.point.y
            end
            point.x = point.x / #q.touches
            point.y = point.y / #q.touches
            newCorners[q.index] = point
        end
    end

    -- Move the corners to the new locations.
    for i = 1,#self.corners do
        self.corners[i].point = newCorners[i]
    end

    -- The edge midpoints were computed for the old corners and need
    -- to be recomputed.
    for _, edge in pairs(self.edges) do
        if edge.v0 and edge.v1 then
            edge.midpoint = Point.interpolate(edge.v0.point, edge.v1.point, 0.5)
        end
    end
end

-- Create an array of corners that are on land only, for use by
-- algorithms that work only on land.  We return an array instead
-- of a vector because the redistribution algorithms want to sort
-- this array using Array.sortOn.
function Map:landCorners(corners)
    local locations = {}
    for _, q in pairs(corners) do
        if not q.ocean and not q.coast then
            table.insert(locations, q)
        end
    end
    return locations
end

-- Build graph data structure in 'edges', 'centers', 'corners',
-- based on information in the Voronoi results: point.neighbors
-- will be a list of neighboring points of the same type (corner
-- or center); point.edges will be a list of edges that include
-- that point. Each edge connects to four points: the Voronoi edge
-- edge.{v0,v1} and its dual Delaunay triangle edge edge.{d0,d1}.
-- For boundary polygons, the Delaunay edge will have one null
-- point, and the Voronoi edge may be null.
function Map:buildGraph(points, voronoi)
    local p, q, point, other
    local libedges = voronoi:edges()
    print('libedges: ', #libedges)
    local centerLookup = {}  -- dict

    -- Build Center objects for each of the points, and a lookup map
    -- to find those Center objects again as we build the graph
    for _, point in pairs(points) do
        p = Center()
        p.index = #self.centers + 1
        p.point = point
        p.neighbors = {}
        p.borders = {}
        p.corners = {}
        table.insert(self.centers, p)
        centerLookup[point] = p
    end
    print('finish add points')

    -- Workaround for Voronoi lib bug: we need to call region()
    -- before Edges or neighboringSites are available
    for _, p in pairs(self.centers) do
        print("==voronoi:region:", p.point)
        voronoi:region(p.point)
        print("==finish voronoi:region:", p.point)
    end
    print('==== finish region')

    -- The Voronoi library generates multiple Point objects for
    -- corners, and we need to canonicalize to one Corner object.
    -- To make lookup fast, we keep an array of Points, bucketed by
    -- x value, and then we only have to look at other Points in
    -- nearby buckets. When we fail to find one, we'll create a new
    -- Corner object.
    local _cornerMap = {}
    local function makeCorner(point)
        if point == nil then return nil end
        local bucket
        local q
        for bucket = math.floor(point.x) - 1, math.floor(point.x) do
            local ps = _cornerMap[bucket]
            if ps ~= nil then
                for _, q in pairs(_cornerMap[bucket]) do
                    local dx = point.x - q.point.x
                    local dy = point.y - q.point.y
                    if (dx*dx + dy*dy) < 1e-6 then
                        return q
                    end
                end
            end
        end
        bucket = math.floor(point.x)
        if not _cornerMap[bucket] then _cornerMap[bucket] = {} end
        q = Corner()
        q.index = #self.corners + 1
        table.insert(self.corners, q)
        q.point = point
        q.border = (point.x == 0 or point.x == SIZE or point.y == 0 or point.y == SIZE)
        q.touches = {}
        q.protrudes = {}
        q.adjacent = {}
        table.insert(_cornerMap[bucket], q)
        return q
    end

    -- Helper functions for the following for loop; ideally these
    -- would be inlined
    local function addToList(v, x)
        if x ~= nil then
            for i, el in ipairs(v) do
                if el == x then
                    return
                end
            end
            table.insert(v, x)
        end
    end

    print('before add corners')
    for _, libedge in pairs(libedges) do
        local dedge = libedge:delaunayLine()
        local vedge = libedge:voronoiEdge()

        -- // Fill the graph data. Make an Edge object corresponding to
        -- // the edge from the voronoi library.
        local edge = Edge()
        edge.index = #self.edges
        edge.river = 0
        table.insert(self.edges, edge)
        edge.midpoint = vedge.p0 and vedge.p1 and Point.interpolate(vedge.p0, vedge.p1, 0.5)

        -- // Edges point to corners. Edges point to centers.
        edge.v0 = makeCorner(vedge.p0)
        edge.v1 = makeCorner(vedge.p1)
        edge.d0 = centerLookup[dedge.p0]
        edge.d1 = centerLookup[dedge.p1]

        -- // Centers point to edges. Corners point to edges.
        if (edge.d0 ~= nil) then
            table.insert(edge.d0.borders, edge)
        end
        if (edge.d1 ~= nil) then
            table.insert(edge.d1.borders, edge)
        end
        if (edge.v0 ~= nil) then
            table.insert(edge.v0.protrudes, edge)
        end
        if (edge.v1 ~= nil) then
            table.insert(edge.v1.protrudes, edge)
        end

        -- // Centers point to centers.
        if (edge.d0 ~= nil and edge.d1 ~= nil) then
            addToList(edge.d0.neighbors, edge.d1)
            addToList(edge.d1.neighbors, edge.d0)
        end

        -- // Corners point to corners
        if (edge.v0 ~= nil and edge.v1 ~= nil) then
            addToList(edge.v0.adjacent, edge.v1)
            addToList(edge.v1.adjacent, edge.v0)
        end

        -- // Centers point to corners
        if (edge.d0 ~= nil) then
            addToList(edge.d0.corners, edge.v0)
            addToList(edge.d0.corners, edge.v1)
        end
        if (edge.d1 ~= nil) then
            addToList(edge.d1.corners, edge.v0)
            addToList(edge.d1.corners, edge.v1)
        end

        -- // Corners point to centers
        if (edge.v0 ~= nil) then
            addToList(edge.v0.touches, edge.d0)
            addToList(edge.v0.touches, edge.d1)
        end
        if (edge.v1 ~= nil) then
            addToList(edge.v1.touches, edge.d0)
            addToList(edge.v1.touches, edge.d1)
        end
    end -- for _, libedge in pairs(libedges) do
    print('finish add corners')
end


-- Determine elevations and water at Voronoi corners. By
-- construction, we have no local minima. This is important for
-- the downslope vectors later, which are used in the river
-- construction algorithm. Also by construction, inlets/bays
-- push low elevation areas inland, which means many rivers end
-- up flowing out through them. Also by construction, lakes
-- often end up on river paths because they don't raise the
-- elevation as much as other terrain does.
function Map:assignCornerElevations()
    local q, s
    local queue = {}

    for _, q in pairs(self.corners) do
        q.water = not self:inside(q.point)
    end

    for _, q in pairs(self.corners) do
        -- // The edges of the map are elevation 0
        if (q.border) then
            q.elevation = 0.0
            table.insert(queue, q)
        else
            q.elevation = math.huge
        end
    end
    -- // Traverse the graph and assign elevations to each point. As we
    -- // move away from the map border, increase the elevations. This
    -- // guarantees that rivers always have a way down to the coast by
    -- // going downhill (no local minima).
    local queue_count = #queue
    local first_corner = 1
    while queue_count > 0 do
        q = queue[first_corner]

        for _, s in pairs(q.adjacent) do
            local newElevation = 0.01 + q.elevation
            if (not q.water and not s.water) then
                newElevation = newElevation + 1
                if (self.needsMoreRandomness) then
                    newElevation = newElevation + self.mapRandom:nextDouble()
                end
            end
            if (newElevation < s.elevation) then
                s.elevation = newElevation
                table.insert(queue, s)
                queue_count = queue_count + 1
            end
        end
        first_corner = first_corner + 1
        queue_count = queue_count - 1
    end
end


-- Change the overall distribution of elevations so that lower
-- elevations are more common than higher
-- elevations. Specifically, we want elevation X to have frequency
-- (1-X).  To do this we will sort the corners, then set each
-- corner to its desired elevation.
function Map:redistributeElevations(locations)
    -- // SCALE_FACTOR increases the mountain area. At 1.0 the maximum
    -- // elevation barely shows up on the map, so we set it to 1.1.
    local SCALE_FACTOR = 1.1
    local i, y, x

    table.sort(locations, function(o1, o2)
        if o1.elevation > o2.elevation then return false end
        if o1.elevation < o2.elevation then return true end
        return false
    end)
    for i = 1, #locations do
        y = i/#locations
        x = math.sqrt(SCALE_FACTOR) - math.sqrt(SCALE_FACTOR*(1-y))
        if (x > 1.0) then x = 1.0 end  --// TODO: does this break downslopes?
        locations[i].elevation = x
    end
end


-- Change the overall distribution of moisture to be evenly distributed.
function Map:redistributeMoisture(locations)
    local i
    table.sort(locations, function(o1, o2)
        if o1.moisture > o2.moisture then return false end
        if o1.moisture < o2.moisture then return true end
        return false
    end)
    for i = 1, #locations do
        locations[i].moisture = i/#locations
    end
end


-- Determine polygon and corner types: ocean, coast, land.
function Map:assignOceanCoastAndLand()
    local queue = {}
    local p, q, r, numWater

    for _, p in pairs(self.centers) do
        numWater = 0;
        for _, q in pairs(p.corners) do
            if (q.border) then
                p.border = true
                p.ocean = true
                q.water = true
                table.insert(queue, p)
            end
            if (q.water) then
                numWater = numWater + 1
            end
        end
        p.water = p.ocean or numWater >= #p.corners * LAKE_THRESHOLD
    end
    local queue_count = #queue
    local first = 1
    while queue_count > 0 do
        p = queue[first]
        for _, r in pairs(p.neighbors) do
            if (r.water and not r.ocean) then
                r.ocean = true;
                table.insert(queue, r)
                queue_count = queue_count + 1
            end
        end
        queue_count = queue_count - 1
        first = first + 1
    end

    for _, p in pairs(self.centers) do
        local numOcean = 0
        local numLand = 0
        for _, r in pairs(p.neighbors) do
            numOcean = numOcean + (r.ocean and 1 or 0)
            numLand = numLand + (not r.water and 1 or 0)
        end
        p.coast = (numOcean > 0) and (numLand > 0)
    end

    for _, q in pairs(self.corners) do
        local numOcean = 0
        local numLand = 0
        for _, p in pairs(q.touches) do
            numOcean = numOcean + (p.ocean and 1 or 0)
            numLand = numLand + (not p.water and 1 or 0)
        end
        q.ocean = (numOcean == #q.touches)
        q.coast = (numOcean > 0) and (numLand > 0)
        q.water = q.border or ((numLand ~= #q.touches) and not q.coast)
    end
end


-- Polygon elevations are the average of the elevations of their corners.
function Map:assignPolygonElevations()
    local p, q, sumElevation
    for _, p in pairs(self.centers) do
        sumElevation = 0.0
        for _, q in pairs(p.corners) do
            sumElevation = sumElevation + q.elevation
        end
        p.elevation = sumElevation / #p.corners
    end
end


-- Calculate downslope pointers.  At every point, we point to the
-- point downstream from it, or to itself.  This is used for
-- generating rivers and watersheds.
function Map:calculateDownslopes()
    local q, s, r
    for _, q in pairs(self.corners) do
        r = q
        for _,s in pairs(q.adjacent) do
            if (s.elevation <= r.elevation) then
                r = s
            end
        end
        q.downslope = r
    end
end


-- Calculate the watershed of every land point. The watershed is
-- the last downstream land point in the downslope graph. TODO:
-- watersheds are currently calculated on corners, but it'd be
-- more useful to compute them on polygon centers so that every
-- polygon can be marked as being in one watershed.
function Map:calculateWatersheds()
    local q, r, i, changed

    -- // Initially the watershed pointer points downslope one step.
    for _, q in pairs(self.corners) do
        q.watershed = q
        if (not q.ocean and not q.coast) then
            q.watershed = q.downslope
        end
    end

    for i = 1, 100 do
        changed = false;
        for _, q in pairs(self.corners) do
            if (not q.ocean and not q.coast and not q.watershed.coast) then
                r = q.downslope.watershed
                if (not r.ocean) then
                    q.watershed = r
                    changed = true
                end
            end
        end
        if (not changed) then break end
    end
    -- // How big is each watershed?
    for _, q in pairs(self.corners) do
        r = q.watershed
        r.watershed_size = 1 + (r.watershed_size > 0 and r.watershed_size or 0)
    end
end


-- Create rivers along edges. Pick a random corner point, then
-- move downslope. Mark the edges and corners as rivers.
function Map:createRivers()
    local i, q, edge

    for i = 1, SIZE/2 do
        local r = self.mapRandom:nextIntRange(1, #self.corners)
        q = self.corners[r]
        if (q.ocean or q.elevation < 0.3 or q.elevation > 0.9) then
            -- continue
        else
            -- // Bias rivers to go west: if (q.downslope.x > q.x) continue;
            while (not q.coast) do
                if (q == q.downslope) then break end
                edge = self:lookupEdgeFromCorner(q, q.downslope)
                edge.river = edge.river + 1
                q.river = (q.river > 0 and q.river or 0) + 1;
                q.downslope.river = (q.downslope.river > 0 and q.downslope.river or 0) + 1
                q = q.downslope
            end
        end
    end
end


-- Calculate moisture. Freshwater sources spread moisture: rivers
-- and lakes (not oceans). Saltwater sources have moisture but do
-- not spread it (we set it at the end, after propagation).
function Map:assignCornerMoisture()
    local q, r, newMoisture
    local queue = {}
    -- // Fresh water
    for _, q in pairs(self.corners) do
        if ((q.water or q.river > 0) and not q.ocean) then
            q.moisture = q.river > 0 and math.min(3.0, (0.2 * q.river)) or 1.0
            table.insert(queue, q)
        else
            q.moisture = 0.0
        end
    end
    local queue_count = #queue
    local first = 1
    while queue_count > 0 do
        q = queue[first]

        for _, r in pairs(q.adjacent) do
            newMoisture = q.moisture * 0.9
            if (newMoisture > r.moisture) then
                r.moisture = newMoisture
                table.insert(queue, r)
                queue_count = queue_count + 1
            end
        end
        queue_count = queue_count - 1
        first = first + 1
    end
    -- // Salt water
    for _, q in pairs(self.corners) do
        if (q.ocean or q.coast) then
            q.moisture = 1.0;
        end
    end
end


-- Polygon moisture is the average of the moisture at corners
function Map:assignPolygonMoisture()
    local p, q, sumMoisture
    for _, p in pairs(self.centers) do
        sumMoisture = 0.0
        for _, q in pairs(p.corners) do
            if (q.moisture > 1.0) then q.moisture = 1.0 end
            sumMoisture =sumMoisture + q.moisture
        end
        p.moisture = sumMoisture / #p.corners
    end
end


-- Assign a biome type to each polygon. If it has
-- ocean/coast/water, then that's the biome; otherwise it depends
-- on low/high elevation and low/medium/high moisture. This is
-- roughly based on the Whittaker diagram but adapted to fit the
-- needs of the island map generator.
function Map:getBiome(p)
    if (p.ocean) then
        return 'OCEAN';
    elseif (p.water) then
        if (p.elevation < 0.1) then return 'MARSH' end
        if (p.elevation > 0.8) then return 'ICE' end
        return 'LAKE'
    elseif (p.coast) then
        return 'BEACH'
    elseif (p.elevation > 0.8) then
        if (p.moisture > 0.50) then return 'SNOW'
        elseif (p.moisture > 0.33) then return 'TUNDRA'
        elseif (p.moisture > 0.16) then return 'BARE'
        else return 'SCORCHED'
        end
    elseif (p.elevation > 0.6) then
        if (p.moisture > 0.66) then return 'TAIGA'
        elseif (p.moisture > 0.33) then return 'SHRUBLAND'
        else return 'TEMPERATE_DESERT'
        end
    elseif (p.elevation > 0.3) then
        if (p.moisture > 0.83) then return 'TEMPERATE_RAIN_FOREST'
        elseif (p.moisture > 0.50) then return 'TEMPERATE_DECIDUOUS_FOREST'
        elseif (p.moisture > 0.16) then return 'GRASSLAND'
        else return 'TEMPERATE_DESERT'
        end
    else
        if (p.moisture > 0.66) then return 'TROPICAL_RAIN_FOREST'
        elseif (p.moisture > 0.33) then return 'TROPICAL_SEASONAL_FOREST'
        elseif (p.moisture > 0.16) then return 'GRASSLAND'
        else return 'SUBTROPICAL_DESERT'
        end
    end
end


function Map:assignBiomes()
    for _, p in pairs(self.centers) do
        p.biome = self:getBiome(p)
    end
end


-- Look up a Voronoi Edge object given two adjacent Voronoi
-- polygons, or two adjacent Voronoi corners
function Map:lookupEdgeFromCenter(p, r)
    for _, edge in pairs(p.borders) do
        if (edge.d0 == r or edge.d1 == r) then return edge end
    end
    return nil
end

function Map:lookupEdgeFromCorner(q, s)
    for _, edge in pairs(q.protrudes) do
        if (edge.v0 == s or edge.v1 == s) then return edge end
    end
    return nil
end


-- Determine whether a given point should be on the island or in the water.
function Map:inside(p)
    return self.islandShape(Point(2*(p.x/SIZE - 0.5), 2*(p.y/SIZE - 0.5)))
end

return Map
