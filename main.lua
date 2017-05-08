local Map = require("Map")
local Camera = require("camera")

local SIZE = 600
local islandType = 'Radial'
-- local islandType = 'Square'
-- local islandType = 'ROT'
local pointType = 'Square'
local numPoints = 5000
local mapMode = 'Polygons'
local map

local maploader = require("maploader")

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


local grid = {}

local circle = {}

function love.load()
    circle.x = 100
    circle.y = 100
    camera = Camera(circle.x, circle.y, nil, nil, Camera.smooth.damped(2))
    camera:lockPosition(circle.x, circle.y)

    local seed = math.floor(love.math.random() * 10000000)
    local variant = 1+math.floor(9*love.math.random())
    maploader.newMap(nm, SIZE, islandType, pointType, numPoints, seed, variant)
    local function allDone()
        print("#nm.data", #nm.data)
        -- for _, v in ipairs(nm.data) do
            -- print(v[1], v[2])
        -- end
        local numGrid = math.sqrt(#nm.data)
        for i = 1, numGrid do
            grid[i] = {}
            for j = 1, numGrid do
                local p = table.remove(nm.data)
                grid[i][j] = p[3]
            end
        end
        generated = true
    end
    local function oneDone(process_)
        if not generated then
            process = process_
            nextProcess = process_ + 1
        end
    end
    maploader.start(allDone, oneDone)
    print(seed)
    print(variant)
end

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local n = SIZE / math.sqrt(numPoints) * 0.5
-- local n2 = n * 2
local n2 = 128 * 2

local line = false
local full = false
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

    camera:attach()

    -- for _, p in pairs(nm.data) do
        -- local color = colors[p[3]]
        -- if not color then
            -- color = {255, 255, 255}
        -- end
        -- love.graphics.setColor(color)
        -- love.graphics.rectangle('fill', p[1] - n, p[2]-n, n*2, n*2)
        -- love.graphics.setColor(255, 255, 255)
        -- love.graphics.print(tostring(round(p[1], 1))..";;"..tostring(round(p[2], 1)), p[1] - 10, p[2])

        -- if line then
            -- love.graphics.setColor(255, 255, 255, 60)
            -- love.graphics.rectangle('line', p[1]-n, p[2]-n, n*2, n*2)
        -- end
    -- end

    -- for x, v in ipairs(grid) do
        -- for y, biome in ipairs(v) do
            -- local r_x = (x - 1) * n2
            -- local r_y = (y - 1) * n2
            -- local color = colors[biome]
            -- if not color then
                -- color = {255, 255, 255}
            -- end
            -- love.graphics.setColor(color)
            -- love.graphics.rectangle('fill', r_x, r_y, n2, n2)
            -- love.graphics.setColor(255, 255, 255)
            -- love.graphics.print(tostring(x)..";"..tostring(y), r_x, r_y)

            -- if line then
                -- love.graphics.setColor(255, 255, 255, 60)
                -- love.graphics.rectangle('line', r_x, r_y, n2, n2)
            -- end
        -- end
    -- end

    local g_x = math.floor(circle.x / n2) + 1
    local g_y = math.floor(circle.y / n2) + 1

    -- local bound = math.floor(#grid / 3)
    local bound = math.floor(#grid / 5)

    local l_x = g_x - bound
    local l_y = g_y - bound

    local r_x = g_x + bound
    local r_y = g_y + bound

    if l_x < 1 then l_x = 1 end
    if l_y < 1 then l_y = 1 end

    local num_grid = #grid

    if r_x > num_grid then r_x = num_grid end
    if r_y > num_grid then r_y = num_grid end

    local function f(a, b)
        return (a - b) < bound
    end

    if f(g_x, l_x) then
        r_x = r_x + bound - (g_x - l_x)
    end
    if f(g_y, l_y) then
        r_y = r_y + bound - (g_y - l_y)
    end

    if f(r_x, g_x) then
        l_x = l_x - (bound - (r_x - g_x))
    end
    if f(r_y, g_y) then
        l_y = l_y - (bound - (r_y - g_y))
    end


    for x = l_x, r_x do
        for y = l_y, r_y do
            local biome = grid[x][y]
            local rr_x = (x - 1) * n2
            local rr_y = (y - 1) * n2
            local color = colors[biome]
            if not color then
                color = {255, 255, 255}
            end
            love.graphics.setColor(color)
            love.graphics.rectangle('fill', rr_x, rr_y, n2, n2)
            love.graphics.setColor(255, 255, 255)
            -- love.graphics.print(tostring(x)..";"..tostring(y), rr_x, rr_y)

            if line then
                love.graphics.setColor(255, 255, 255, 60)
                love.graphics.rectangle('line', rr_x, rr_y, n2, n2)
            end
        end
    end


    local color = {155, 155, 155, 100}

    love.graphics.setColor(color)
    love.graphics.rectangle('fill', (g_x - 1) * n2, (g_y - 1) * n2, n2, n2)

    love.graphics.setColor(255, 255, 255, 60)
    love.graphics.circle("fill", circle.x, circle.y, 10)
    love.graphics.print(tostring(circle.x)..";"..tostring(circle.y), circle.x, circle.y)

    camera:detach()

    love.graphics.setColor(255, 255, 255)
    love.graphics.print("Press 'K' to generate new map", 600, 100)
    love.graphics.print("Press 'L' to draw edges", 600, 150)
    love.graphics.print("Press 'J' to draw full minimap", 600, 170)

    love.graphics.push()

    local n3 = 3
    love.graphics.setColor(0, 0, 0, 255)
    love.graphics.rectangle('fill', 0, 0, n3 * #grid, n3 * #grid)
    if full then
        l_x = 1
        l_y = 1
        r_x = #grid
        r_y = #grid
    end
    for x = l_x, r_x do
        for y = l_y, r_y do
            local biome = grid[x][y]
            local rr_x = (x - 1) * n3
            local rr_y = (y - 1) * n3
            local color = colors[biome]
            if not color then
                color = {255, 255, 255}
            end
            love.graphics.setColor(color)
            love.graphics.rectangle('fill', rr_x, rr_y, n3, n3)
            love.graphics.setColor(255, 255, 255, 100)
            -- love.graphics.print(tostring(x)..";"..tostring(y), rr_x, rr_y)

            if line then
                love.graphics.setColor(255, 255, 255, 60)
                love.graphics.rectangle('line', rr_x, rr_y, n3, n3)
            end
        end
    end
    love.graphics.setColor(255, 255, 255)
    love.graphics.circle('fill', g_x * n3, g_y * n3, n3)

    love.graphics.pop()
end

function love.update(dt)
    maploader.update()
    if process < nextProcess then
        process = process + 200.0 / numPoints
    end
    if love.keyboard.isDown("left") then
        circle.x = circle.x - 10
    elseif love.keyboard.isDown("right") then
        circle.x = circle.x + 10
    end
    if love.keyboard.isDown("up") then
        circle.y = circle.y - 10
    elseif love.keyboard.isDown("down") then
        circle.y = circle.y + 10
    end
    camera:lockPosition(circle.x, circle.y)
end

function love.keypressed(k)
    if k == "k" then
        process = 0
        nextProcess = 1
        generated = false
        nm.data = {}
        local seed = math.floor(love.math.random() * 10000000)
        local variant = 1+math.floor(9*love.math.random())
        maploader.newMap(nm, SIZE, islandType, pointType, numPoints, seed, variant)
        print(seed)
        print(variant)
    elseif k == "l" then
        line = not line
    elseif k == "j" then
        full = not full
    end
end
