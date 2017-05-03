math.random()
math.random()
math.random()
math.random()
math.random()
math.random()
local Map = require("Map")

local SIZE = 600
local islandType = 'Radial'
-- local islandType = 'Square'
-- local islandType = 'ROT'
local pointType = 'Square'
-- local pointType = 'Hexagon'
local numPoints = 500
local mapMode = 'Polygons'
local map
love.math.random()
love.math.random()
love.math.random()
love.math.random()

local maploader = require("maploader")

-- function interpolateColor(color0, color1, f)
    -- local r = math.floor((1-f)*(color0 >> 16) + f*(color1 >> 16))
    -- local g = math.floor((1-f)*((color0 >> 8) & 0xff) + f*((color1 >> 8) & 0xff))
    -- local b = math.floor((1-f)*(color0 & 0xff) + f*(color1 & 0xff))
    -- if (r > 255) then r = 255 end
    -- if (g > 255) then g = 255 end
    -- if (b > 255) then b = 255 end
    -- return (r << 16) | (g << 8) | b
-- end
--
local colors = {
    OCEAN = {68, 68, 122},
    COAST = {51, 51, 90},
    LAKESHORE = {34, 85, 136},
    LAKE = {51, 102, 153},
    MARSH = {47, 102, 102},
    ICE = {153, 255, 255},
    BEACH = {160, 144, 119},
    SNOW = {255, 255, 255},
    TUNDRA = {187, 187, 170},
    BARE = {136, 136, 136},
    SCORCHED = {85, 85, 85},
    TAIGA = {153, 170, 119},
    SHRUBLAND = {136, 153, 119},
    TEMPERATE_DESERT = {201, 210, 155},
    TEMPERATE_RAIN_FOREST = {68, 136, 85},
    TEMPERATE_DECIDUOUS_FOREST = {103, 148, 89},
    GRASSLAND = {136, 170, 85},
    SUBTROPICAL_DESERT = {210, 185, 139},
    TROPICAL_RAIN_FOREST = {51, 119, 85},
    TROPICAL_SEASONAL_FOREST = {85, 153, 68}
}

local generated = false


local nm = {}
local process = 0
local nextProcess = 1

function love.load()
    local seed = math.floor(love.math.random() * 10000000)
    local variant = 1+math.floor(9*love.math.random())
        -- map = Map(SIZE)
        print('=======before build newIsland')
        -- map:newIsland(islandType, pointType, numPoints, seed, variant)
        print('=======after build newIsland')
        print('=======before map:go')
        -- map:go()
        maploader.newMap(nm, SIZE, islandType, pointType, numPoints, seed, variant)
        local function allDone()
            generated = true 
            print("all done")
            print("nm.data", #nm.data) 
            -- for _, v in pairs(nm.data) do
                -- print(unpack(v))
            -- end
        end
        local function oneDone(process_)
            print("process:", process_)
            if not generated then
                process = process_
                nextProcess = process_ + 1
            end
        end
        maploader.start(allDone, oneDone)
        -- generated = true
        print('=======after map:go')
    print(seed)
    print(variant)
end

local n = SIZE / math.sqrt(numPoints) * 0.5

local line = false
local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
function love.draw()
    if not generated then
        love.graphics.setColor(255, 255, 255)
        love.graphics.print("Loading...", 100, 100)

        local separation = 30
        local w = screenWidth - 2*separation
        local h = 50;
        local x,y = separation, screenHeight - separation - h;
        love.graphics.rectangle("line", x, y, w, h)
        x, y = x + 3, y + 3
        w, h = w - 6, h - 7
        w = w * (process / 8)
        love.graphics.rectangle("fill", x, y, w, h)
        return
    end
    -- for _, p in pairs(map.centers) do

        -- local color = colors[p.biome]
        -- if not color then
            -- color = {255, 255, 255}
        -- end
        -- love.graphics.setColor(color)
        -- love.graphics.rectangle('fill', p.point.x-n, p.point.y-n, n*2, n*2)

        -- if line then
            -- love.graphics.setColor(255, 255, 255)
            -- love.graphics.rectangle('line', p.point.x-n, p.point.y-n, n*2, n*2)
        -- end
    -- end
    for _, p in pairs(nm.data) do
        -- p {x, y, biome}
        local color = colors[p[3]]
        if not color then
            color = {255, 255, 255}
        end
        love.graphics.setColor(color)
        -- print(unpack(p))
        love.graphics.rectangle('fill', p[1] - n, p[2]-n, n*2, n*2)

        if line then
            love.graphics.setColor(255, 255, 255)
            love.graphics.rectangle('line', p[1]-n, p[2]-n, n*2, n*2)
        end
    end
end

function love.update(dt)
    maploader.update()
    if process < nextProcess then
        process = process + 200.0 / numPoints
    end
end

function love.keypressed(k)
    if k == "k" then
        print("=========")
        print(process)
        process = 0
        nextProcess = 1
        print(process)
        print("=========")
        generated = false
        nm.data = {}
        local seed = math.floor(love.math.random() * 10000000)
        local variant = 1+math.floor(9*love.math.random())
        -- map = Map(SIZE)
            -- map:newIsland(islandType, pointType, numPoints, seed, variant)
            -- map:go()
            -- generated = true
        maploader.newMap(nm, SIZE, islandType, pointType, numPoints, seed, variant)
        print(seed)
        print(variant)
    elseif k == "l" then
        line = not line
    end
end
