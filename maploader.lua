require "love.timer"
ROT = require("rotLove/rotLove/rotLove")
local Map = require("Map")
local maploader = {}

local loaded = ...

if loaded == true then
    -- thread function
    local params
    local done = false

    local doneChannel = love.thread.getChannel("is_done")

    while not done do
        local task = love.thread.getChannel("task")
        params = task:pop()
        if params then
            local chp = love.thread.getChannel("process")
            chp:push(0)
            local map = Map(params.size)
            map:newIsland(params.islandType, params.pointType, params.numPoints, params.seed, params.variant)
            map:go(1, 1)
            chp:push(1)
            map:go(2, 2)
            chp:push(2)
            map:go(3, 3)
            chp:push(3)
            map:go(4, 4)
            chp:push(4)
            map:go(5, 5)
            chp:push(5)
            map:go(6, 6)
            chp:push(6)
            map:go(7, 7)
            chp:push(7)
            map:go(8, 8)
            chp:push(8)
            local ch = love.thread.getChannel("map")
            local lock = love.thread.getChannel("lock")
            lock:push("start")
            for _, p in pairs(map.centers) do
                ch:push({p.point.x, p.point.y, p.biome})
            end
            lock:push("end")
        end
        love.timer.sleep(1)

        -- done = doneChannel:pop()
    end
else
    -- main function
    local pending = {}
    local allDonecallback = nil
    local one = nil
    local mapBeingLoaded

    local pathToThisFile = (...):gsub("%.", "/") .. ".lua"

    local function shift(t)
        return table.remove(t, 1)
    end

    function maploader.newMap(holder, size, islandType, pointType, numPoints, seed, variant)
        pending[#pending+1] = {
            holder = holder,
            -- params = {size, islandType, pointType, numPoints}
            params = {size=size, islandType=islandType, pointType=pointType, numPoints=numPoints, seed=seed, variant=variant}
        }
    end

    local DATA = {}
    local start = false
    local done = false

    local function getResFromThreadIfAvailable()
        local chp = love.thread.getChannel("process")
        local process = chp:pop()
        while process do
            if one ~= nil then
                one(process)
            end
            process = chp:pop()
        end
        local lock = love.thread.getChannel("lock")
        local s = lock:pop()
        if s and s == "start" then
            start = true
            DATA = {}
        elseif s == "end" then
            done = true
        end

        local data
        local ch = love.thread.getChannel("map")
        data = ch:pop()
        while data do
            table.insert(DATA, data)
            data = ch:pop()
        end
        if start and done then
            mapBeingLoaded.holder['data'] = DATA
        end

        if start and done and allDonecallback then
            allDonecallback(mapBeingLoaded.holder)
            mapBeingLoaded = nil
        end

        if start and done then
            start = false
            done = false
        end
    end

    local function pushTaskToThread()
        mapBeingLoaded = shift(pending)
        local ch = love.thread.getChannel("task")
        ch:push(mapBeingLoaded.params)
    end

    local function endThreadIfAllLoaded()
        if not mapBeingLoaded and #pending == 0 then
            love.thread.getChannel("is_done"):push(true)
        end
    end

    function maploader.start(allDonecallback_, oneDoneCallback_)
        allDonecallback = allDonecallback_
        one = oneDoneCallback_

        local thread = love.thread.newThread(pathToThisFile)
        thread:start(true)

        maploader.thread = thread
    end

    function maploader.update()
        if maploader.thread then
            if maploader.thread:isRunning() then
                if mapBeingLoaded then
                    getResFromThreadIfAvailable()
                elseif #pending > 0 then
                    pushTaskToThread()
                else
                    endThreadIfAllLoaded()
                end
            else
                local errmsg = maploader.thread:getError()
                assert(not errmsg, errmsg)
            end
        end
    end

    return maploader
end
