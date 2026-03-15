local mod = foundation.createMod()

local COMP_STAT_CONTROLLER = {
    TypeName = "COMP_STAT_CONTROLLER",
    ParentType = "COMPONENT",
    Properties = {}
}

mod:log("Resource Stats Tracker starting up!")

local dailyStats = {}
local weeklyStats = {}
local monthlyStats = {}

local dailyStatsHistory = {}
local weeklyStatsHistory = {}
local monthlyStatsHistory = {}

local function logAverages(history, periodName)
    local sums = {}
    local numPeriods = #history
    if numPeriods == 0 then return end

    for _, stats in ipairs(history) do
        for resName, quant in pairs(stats) do
            sums[resName] = (sums[resName] or 0) + quant
        end
    end

    local str = "Average " .. periodName .. " Stats (over last " .. tostring(numPeriods) .. " periods):"
    local hasStats = false
    for resName, total in pairs(sums) do
        local avg = total / numPeriods
        str = str .. string.format("\n  - %s: %.2f", resName, avg)
        hasStats = true
    end

    if not hasStats then
        str = str .. "\n  (none)"
    end
    mod:log(str)
end

---comment
---@param res RESOURCE_COLLECTION_VALUE
local function onResProduced(res)
    local collection = res.Collection

    if not collection then
        mod:log("No collection found for resource production.")
        return
    end

    collection:forEach(function(rqpair)
        ---@type RESOURCE
        local resource = rqpair.Resource
        ---@type integer
        local quant = rqpair.Quantity
        dailyStats[resource.ResourceName] = dailyStats[resource.ResourceName] or 0
        dailyStats[resource.ResourceName] = dailyStats[resource.ResourceName] + quant
        weeklyStats[resource.ResourceName] = weeklyStats[resource.ResourceName] or 0
        weeklyStats[resource.ResourceName] = weeklyStats[resource.ResourceName] + quant
        monthlyStats[resource.ResourceName] = monthlyStats[resource.ResourceName] or 0
        monthlyStats[resource.ResourceName] = monthlyStats[resource.ResourceName] + quant
    end)
end

function COMP_STAT_CONTROLLER:registerProductionListeners()
    local workplaceManager = self:getLevel():getComponentManager("COMP_WORKPLACE")
    if not workplaceManager then
        mod:log("Workplace manager does not exist.")
        return
    end

    local comps = workplaceManager:getAllComponent()
    mod:log("Found " .. tostring(#comps) .. " workplaces.")

    comps:forEach(function(comp)
        event.register(self, comp.ON_WORKPLACE_PRODUCED, onResProduced)
    end)
end

function COMP_STAT_CONTROLLER:onEnabled()
    mod:log("COMP_STAT_CONTROLLER ENABLED!")

    self:registerProductionListeners()

    ---@type COMP_MAIN_GAME_LOOP
    local compMainGameLoop = self:getLevel():find("COMP_MAIN_GAME_LOOP")

    event.register(self, compMainGameLoop.ON_NEW_DAY, function()
        mod:log("New Day!")
        table.insert(dailyStatsHistory, dailyStats)
        if #dailyStatsHistory > 5 then table.remove(dailyStatsHistory, 1) end
        logAverages(dailyStatsHistory, "Daily")
        dailyStats = {} -- reset stats
    end)

    event.register(self, compMainGameLoop.ON_NEW_WEEK, function()
        mod:log("New Week!")
        table.insert(weeklyStatsHistory, weeklyStats)
        if #weeklyStatsHistory > 5 then table.remove(weeklyStatsHistory, 1) end
        logAverages(weeklyStatsHistory, "Weekly")
        weeklyStats = {} -- reset stats
    end)

    event.register(self, compMainGameLoop.ON_NEW_MONTH, function()
        mod:log("New Month!")
        table.insert(monthlyStatsHistory, monthlyStats)
        if #monthlyStatsHistory > 5 then table.remove(monthlyStatsHistory, 1) end
        logAverages(monthlyStatsHistory, "Monthly")
        monthlyStats = {} -- reset stats
    end)
end

mod:registerClass(COMP_STAT_CONTROLLER)
mod:registerPrefabComponent("PREFAB_MANAGER", { DataType = "COMP_STAT_CONTROLLER" })
