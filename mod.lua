local mod = foundation.createMod()

-- Declare a new component
local COMP_STAT_CONTROLLER = {
    TypeName = "COMP_STAT_CONTROLLER",
    ParentType = "COMPONENT",
    Properties = {}
}

mod:log("Starting up!")

-- When that component gets enabled, start doing stuff
function COMP_STAT_CONTROLLER:onEnabled()

    mod:log("COMPONENT ENABLED!")

    local compMainGameLoop = self:getLevel():find("COMP_MAIN_GAME_LOOP")
    event.register(self, compMainGameLoop.ON_NEW_DAY, function()
        mod:log("NEW DAY!")
    end)

end -- component init end

-- Register the custom class
mod:registerClass(COMP_STAT_CONTROLLER)

-- Attach class to the prefab manager which means it will be present in the game from the beginning
mod:registerPrefabComponent("PREFAB_MANAGER", { DataType = "COMP_STAT_CONTROLLER" } )
