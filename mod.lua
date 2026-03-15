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

---@param eventName string
---@param historyName string
---@param history table
---@param currentStats table
---@return table
local function handleNewPeriod(eventName, historyName, history, currentStats)
    mod:log(eventName)
    table.insert(history, currentStats)
    if #history > 5 then table.remove(history, 1) end
    logAverages(history, historyName)
    return {} -- Reset stats by returning a new table
end

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

        if not resource or not resource.ResourceName then return end

        local resName = resource.ResourceName
        if not resName then return end

        local amount = quant or 0

        dailyStats[resName] = (dailyStats[resName] or 0) + amount
        weeklyStats[resName] = (weeklyStats[resName] or 0) + amount
        monthlyStats[resName] = (monthlyStats[resName] or 0) + amount
    end)
end

function COMP_STAT_CONTROLLER:registerProductionListeners(level)
    ---@type COMPONENT_MANAGER
    local workplaceManager = level:getComponentManager("COMP_WORKPLACE")
    if not workplaceManager then
        mod:log("Workplace manager does not exist.")
        return
    end

    -- Register listener when new workplaces are created
    event.register(self, workplaceManager.ON_COMPONENT_INITIALIZED, function(comp)
        event.register(self, comp.ON_WORKPLACE_PRODUCED, onResProduced)
    end)

    -- Unregister when workplaces are destroyed
    event.register(self, workplaceManager.ON_COMPONENT_DESTROYED, function(comp)
        event.unregister(self, comp.ON_WORKPLACE_PRODUCED)
    end)

    -- For all existing workplaces, attach the listener
    local comps = workplaceManager:getAllComponent()
    comps:forEach(function(comp)
        event.register(self, comp.ON_WORKPLACE_PRODUCED, onResProduced)
    end)
end

function COMP_STAT_CONTROLLER:onEnabled()
    mod:log("COMP_STAT_CONTROLLER ENABLED!")

    local level = self:getLevel()
    if not level then
        mod:log("Level is nil, cannot initialize stat controller.")
        return
    end

    self:registerProductionListeners(level)

    ---@type COMP_MAIN_GAME_LOOP
    local compMainGameLoop = level:find("COMP_MAIN_GAME_LOOP")
    if not compMainGameLoop then
        mod:log("COMP_MAIN_GAME_LOOP not found.")
        return
    end

    event.register(self, compMainGameLoop.ON_NEW_DAY, function()
        dailyStats = handleNewPeriod("New Day!", "Daily", dailyStatsHistory, dailyStats)
    end)

    event.register(self, compMainGameLoop.ON_NEW_WEEK, function()
        weeklyStats = handleNewPeriod("New Week!", "Weekly", weeklyStatsHistory, weeklyStats)
    end)

    event.register(self, compMainGameLoop.ON_NEW_MONTH, function()
        monthlyStats = handleNewPeriod("New Month!", "Monthly", monthlyStatsHistory, monthlyStats)
    end)
end

mod:registerClass(COMP_STAT_CONTROLLER)
mod:registerPrefabComponent("PREFAB_MANAGER", { DataType = "COMP_STAT_CONTROLLER" })
