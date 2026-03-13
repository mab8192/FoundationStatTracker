local myMod = foundation.createMod()

-- Stats storage
local stats = {}
local resourceIds = {}
local currentView = "day" -- "day", "week", "month"

function myMod:initStats()
    local allResources = foundation.getAssetsByType("RESOURCE")
    resourceIds = {}
    for _, res in ipairs(allResources) do
        local id = res:getId()
        table.insert(resourceIds, id)
        if not stats[id] then
            stats[id] = {
                currentDay = { produced = 0, consumed = 0 },
                currentWeek = { produced = 0, consumed = 0 },
                currentMonth = { produced = 0, consumed = 0 },
                lastDay = { produced = 0, consumed = 0 },
                lastWeek = { produced = 0, consumed = 0 },
                lastMonth = { produced = 0, consumed = 0 }
            }
        end
    end
    table.sort(resourceIds)
end

function myMod:onResourceProduced(resourceAsset, amount)
    if not resourceAsset then return end
    local id = resourceAsset:getId()
    if stats[id] then
        stats[id].currentDay.produced = stats[id].currentDay.produced + amount
        stats[id].currentWeek.produced = stats[id].currentWeek.produced + amount
        stats[id].currentMonth.produced = stats[id].currentMonth.produced + amount
    end
end

function myMod:onResourceConsumed(resourceAsset, amount)
    if not resourceAsset then return end
    local id = resourceAsset:getId()
    if stats[id] then
        stats[id].currentDay.consumed = stats[id].currentDay.consumed + amount
        stats[id].currentWeek.consumed = stats[id].currentWeek.consumed + amount
        stats[id].currentMonth.consumed = stats[id].currentMonth.consumed + amount
    end
end

function myMod:registerInventory(inventoryComp)
    if not inventoryComp then return end
    
    -- Register for production
    if inventoryComp.ON_RESOURCE_PRODUCED then
        event.register(self, inventoryComp.ON_RESOURCE_PRODUCED, function(res, amt)
            self:onResourceProduced(res, amt)
        end)
    end
    
    -- Register for consumption
    if inventoryComp.ON_RESOURCE_CONSUMED then
        event.register(self, inventoryComp.ON_RESOURCE_CONSUMED, function(res, amt)
            self:onResourceConsumed(res, amt)
        end)
    end
end

-- Time tracking
function myMod:onNewDay()
    for id, resStats in pairs(stats) do
        resStats.lastDay.produced = resStats.currentDay.produced
        resStats.lastDay.consumed = resStats.currentDay.consumed
        resStats.currentDay.produced = 0
        resStats.currentDay.consumed = 0
    end
    self:updateUI()
end

function myMod:onNewWeek()
    for id, resStats in pairs(stats) do
        resStats.lastWeek.produced = resStats.currentWeek.produced
        resStats.lastWeek.consumed = resStats.currentWeek.consumed
        resStats.currentWeek.produced = 0
        resStats.currentWeek.consumed = 0
    end
    self:updateUI()
end

function myMod:onNewMonth()
    for id, resStats in pairs(stats) do
        resStats.lastMonth.produced = resStats.currentMonth.produced
        resStats.lastMonth.consumed = resStats.currentMonth.consumed
        resStats.currentMonth.produced = 0
        resStats.currentMonth.consumed = 0
    end
    self:updateUI()
end

-- UI
local uiPanel = nil

function myMod:createUI()
    local group = gui.ctx:Find("lua>elements a")
    if not group then return end
    
    uiPanel = group:AddControl("vertical_group")
    self:updateUI()
end

function myMod:updateUI()
    if not uiPanel then return end
    uiPanel:Clear()
    
    local headerText = "Resource Stats (Last " .. currentView:gsub("^%l", string.upper) .. ")"
    uiPanel:AddControl("label", headerText)
    
    local buttonRow = uiPanel:AddControl("horizontal_group")
    buttonRow:AddControl("button", "Day", function() currentView = "day"; self:updateUI() end)
    buttonRow:AddControl("button", "Week", function() currentView = "week"; self:updateUI() end)
    buttonRow:AddControl("button", "Month", function() currentView = "month"; self:updateUI() end)
    
    uiPanel:AddControl("label", "Resource | Prod | Cons")
    
    for _, id in ipairs(resourceIds) do
        local resStats = stats[id]
        local p, c = 0, 0
        if currentView == "day" then
            p, c = resStats.lastDay.produced, resStats.lastDay.consumed
        elseif currentView == "week" then
            p, c = resStats.lastWeek.produced, resStats.lastWeek.consumed
        elseif currentView == "month" then
            p, c = resStats.lastMonth.produced, resStats.lastMonth.consumed
        end
        
        if p > 0 or c > 0 then
            local text = string.format("%s | %d | %d", id, p, c)
            uiPanel:AddControl("label", text)
        end
    end
end

-- Events
myMod:registerEvent("GAME_START", function()
    myMod:initStats()
    
    -- Register existing buildings
    local buildingManager = getLevel():find("COMP_BUILDING_MANAGER")
    if buildingManager then
        for _, building in ipairs(buildingManager:getBuildingList()) do
            local inv = building:getComponent("COMP_INVENTORY")
            myMod:registerInventory(inv)
        end
        
        -- Register for new buildings
        event.register(myMod, buildingManager.ON_BUILDING_REGISTERED, function(building)
            local inv = building:getComponent("COMP_INVENTORY")
            myMod:registerInventory(inv)
        end)
    end
    
    -- Register agents
    local agentManager = getLevel():find("COMP_AGENT_MANAGER")
    if agentManager then
        for _, agent in ipairs(agentManager:getAgentList()) do
            local inv = agent:getComponent("COMP_INVENTORY")
            myMod:registerInventory(inv)
        end
        
        event.register(myMod, agentManager.ON_AGENT_REGISTERED, function(agent)
            local inv = agent:getComponent("COMP_INVENTORY")
            myMod:registerInventory(inv)
        end)
    end
    
    -- Time events
    local compMainGameLoop = getLevel():find("COMP_MAIN_GAME_LOOP")
    if compMainGameLoop then
        event.register(myMod, compMainGameLoop.ON_NEW_DAY, function() myMod:onNewDay() end)
        event.register(myMod, compMainGameLoop.ON_NEW_WEEK, function() myMod:onNewWeek() end)
        event.register(myMod, compMainGameLoop.ON_NEW_MONTH, function() myMod:onNewMonth() end)
    end
    
    myMod:createUI()
end)
