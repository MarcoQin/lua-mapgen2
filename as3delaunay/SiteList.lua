local folderOfThisFile = (...):match("(.-)[^%/%.]+$")
local class = require(folderOfThisFile.."/middleclass")
local Site = require(folderOfThisFile.."/Site")
local Circle = require(folderOfThisFile.."/Circle")

local SiteList = class("SiteList")

function SiteList:init()
    self._sites = {}
    self._currentIndex = 1
    self._sorted = false
end

function SiteList:dispose()
    if self._sites ~= nil then
        for _, site in pairs(self._sites) do
            site:dispose()
        end
        self._sites = nil
    end
end

function SiteList:push(site)
    self._sorted = false
    table.insert(self._sites, site)
    return #self._sites
end

function SiteList:get_length()
    return #self._sites
end

function SiteList:next()
    if not self._sorted then
        print("**not sorted, return nil")
        return nil
    end
    if (self._currentIndex <= #self._sites) then
        local r = self._sites[self._currentIndex]
        print("**next r", r)
        self._currentIndex = self._currentIndex + 1
        return r
    else
        print("**self._currentIndex, return nil", self._currentIndex, #self._sites)
        return nil
    end
end

function SiteList:getSitesBounds()
    if self._sorted == false then
        Site.sortSites(self._sites)
        self._currentIndex = 1
        self._sorted = true
    end
    local xmin, xmax, ymin, ymax
    if #self._sites == 0 then
        return Rectangle(0, 0, 0, 0)
    end
    xmin = 9999999999.0
    xmax = 0.0
    for _, site in pairs(self._sites) do
        local sx = site:get_x()
        if sx < xmin then xmin = sx end
        if sx > xmax then xmax = sx end
    end
    ymin = self._sites[1]:get_y()
    ymax = self._sites[#self._sites]:get_y()

    return Rectangle(xmin, ymin, xmax - xmin, ymax - ymin)
end

function SiteList:siteCoords()
    local coords = {}
    for _, site in pairs(self._sites) do
        table.insert(coords, site:get_coord())
    end
    return coords
end

function SiteList:circles()
    local circles = {}
    for _, site in pairs(self._sites) do
        local radius = 0
        local nearestEdge = site:nearestEdge()

        if not nearestEdge:isPartOfConvexHull() then
            radius = nearestEdge:sitesDistance() * 0.5
        end
        table.insert(circles, Circle(site:get_x(), site:get_y(), radius))
    end
    return circles
end

function SiteList:regions(plotBounds)
    local regions = {}
    for _, site in pairs(self._sites) do
        table.insert(regions, site:region(plotBounds))
    end
    return regions
end

return SiteList
