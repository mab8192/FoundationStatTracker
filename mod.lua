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

function COMP_STAT_CONTROLLER:registerProductionListeners()
    local workplaceManager = self:getLevel():getComponentManager("COMP_WORKPLACE")
    if not workplaceManager then
        mod:log("Workplace manager does not exist.")
        return
    end

    local comps = workplaceManager:getAllComponent()
    mod:log("Found " .. tostring(#comps) .. " workplaces.")

    comps:forEach(function(comp)
        event.register(self, comp.ON_WORKPLACE_PRODUCED, function(res)
            local collection = res.Collection
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
        end)
    end)
end

function COMP_STAT_CONTROLLER:onEnabled()
    mod:log("COMP_STAT_CONTROLLER ENABLED!")

    self:registerProductionListeners()

    ---@type COMP_MAIN_GAME_LOOP
    local compMainGameLoop = self:getLevel():find("COMP_MAIN_GAME_LOOP")

    event.register(self, compMainGameLoop.ON_NEW_DAY, function()
        mod:log("New Day!")
        mod:log("Daily Stats: \n" .. tostring(dailyStats))
        dailyStats = {} -- reset stats
    end)

    event.register(self, compMainGameLoop.ON_NEW_WEEK, function()
        mod:log("New Week!")
        mod:log("Weekly Stats: \n" .. tostring(weeklyStats))
        weeklyStats = {} -- reset stats
    end)

    event.register(self, compMainGameLoop.ON_NEW_MONTH, function()
        mod:log("New Month!")
        mod:log("Monthly Stats: \n" .. tostring(monthlyStats))
        monthlyStats = {} -- reset stats
    end)
end

mod:registerClass(COMP_STAT_CONTROLLER)
mod:registerPrefabComponent("PREFAB_MANAGER", { DataType = "COMP_STAT_CONTROLLER" })
