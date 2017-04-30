local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/as3delaunay/middleclass")

Point = class("Point")

function Point:init(x, y)
    -- self.x = math.floor(x)
    -- self.y = math.floor(y)
    self.x = x
    self.y = y
end

function Point.interpolate(a, b, strength)
    -- type a, b = type Point
    -- type strength = type number
    strength = strength or 0.5
    return Point((a.x + b.x) * strength, (a.y + b.y) * strength)
end

function Point.distance(coord, coord0)
    return math.sqrt((coord.x - coord0.x) * (coord.x - coord0.x) + (coord.y - coord0.y) * (coord.y - coord0.y))
end

function Point:l2()
    return self.x * self.x + self.y * self.y
end

function Point:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

function Point:__eq(lhs, rhs)
    if (lhs and not rhs) or (rhs and not lhs) then return false end
    return lhs.x == rhs.x and lhs.y == rhs.y
end

function Point:__tostring()
    return "Point("..tostring(self.x)..", "..tostring(self.y)..")"
end

function Point:get_x()
    return self.x
end

function Point:get_y()
    return self.y
end


Rectangle = class("Rectangle")

function Rectangle:init(x, y, width, height)
    self.left = x
    self.x = x
    self.top = y
    self.y = y
    self.width = width
    self.height = height
    self.right = x + width
    self.bottom = y + height
end


Center = class("Center")

function Center:init()
    self.index = 1

    self.point = nil  -- location
    self.water = false  -- lake or ocean
    self.ocean = false  -- ocean
    self.coast = false  -- land polygon touching an ocean
    self.border = false  -- at the edge of the map
    self.biome = ""  -- biome type (see article)
    self.elevation = 0.0  -- 0.0 - 1.0
    self.moisture = 0.0 -- 0.0 - 1.0

    self.neighbors = {}  -- list of Center
    self.borders = {}  -- list of Edge
    self.corners = {}  -- list of Corner
end

function Center:__tostring()
    return "Center: "..self.biome.."  "..tostring(self.point)
end


Corner = class("Corner")

function Corner:init()
    self.index = 1

    self.point = nil  -- location
    self.ocean = false
    self.water = false
    self.coast = false
    self.border = false
    self.elevation = 0.0
    self.moisture = 0.0

    self.touches = {}  -- list of Center
    self.protrudes = {}  -- list of Edge
    self.adjacent = {}  -- list of Corner

    self.river = 0  -- 0 if no river, or volume of water in river
    self.downslope = nil  -- Corner, pointer to adjacent corner most downhill
    self.watershed = nil  -- Corner, pointer to coastal corner or null
    self.watershed_size = 0
end


Edge = class("Edge")

function Edge:init()
    self.index = 1
    self.d0 = nil  -- Center, Delaunay edge
    self.d1 = nil  -- Center, Delaunay edge

    self.v0 = nil  -- Corner, Voronoi edge
    self.v1 = nil  -- Corner, Voronoi edge

    self.midpoint = nil  -- Point, halfway between v0, v1
    self.river = 0  -- volume of water, or 0
end
