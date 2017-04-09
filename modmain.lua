
-- CONSTANTS --------------------------------------

-- overworld spiders
local PREFAB_SPIDER = "spider"
local PREFAB_SPIDER_WARRIOR = "spider_warrior"
local PREFAB_SPIDER_QUEEN = "spiderqueen"
-- cave spiders
local PREFAB_SPIDER_HIDER = "spider_hider"
local PREFAB_SPIDER_SPITTER = "spider_spitter"
local PREFAB_SPIDER_DROPPER = "spider_dropper"

local TAG_CHESTER = "chester"
local CHARACTER_WEBBER = "webber"


-- FUNCTIONS --------------------------------------

--[[

Please note that order of functions' definition IS important!
If function will be defined after the chunk calling it -
function will not be available at that chunk of code.
Define first, use later.

Couple hours of debugging was spent to understand this simple principle :)

--]]

--[[
Modified version of original retarget function from Reign of Giants DLC
--]]
local function NormalRetarget(inst)
    local targetDist = GLOBAL.TUNING.SPIDER_TARGET_DIST
    if inst.components.knownlocations:GetLocation("investigate") then
        targetDist = GLOBAL.TUNING.SPIDER_INVESTIGATETARGET_DIST
    end
    if GLOBAL.GetSeasonManager() and GLOBAL.GetSeasonManager():IsSpring() then
        targetDist = targetDist * GLOBAL.TUNING.SPRING_COMBAT_MOD
    end
    return GLOBAL.FindEntity(inst, targetDist, 
        function(guy) 
            if inst.components.combat:CanTarget(guy)
               and not (inst.components.follower and inst.components.follower.leader == guy)
               and not (inst.components.follower and inst.components.follower.leader == GLOBAL.GetPlayer() and guy:HasTag("companion")) then
                return (guy:HasTag("character") and not guy:HasTag("monster") and not guy:HasTag(TAG_CHESTER))-- this line was modified
            end
    end)
end

--[[
Modified version of original retarget function from Reign of Giants DLC
--]]
local function WarriorRetarget(inst)
    local targetDist = GLOBAL.TUNING.SPIDER_WARRIOR_TARGET_DIST
    if GLOBAL.GetSeasonManager() and GLOBAL.GetSeasonManager():IsSpring() then
        targetDist = targetDist * GLOBAL.TUNING.SPRING_COMBAT_MOD
    end
    return GLOBAL.FindEntity(inst, targetDist, function(guy)
		return ((guy:HasTag("character") and not guy:HasTag("monster") and not guy:HasTag(TAG_CHESTER)) or guy:HasTag("pig")) -- this line was modified
               and inst.components.combat:CanTarget(guy)
               and not (inst.components.follower and inst.components.follower.leader == guy)
               and not (inst.components.follower and inst.components.follower.leader == GLOBAL.GetPlayer() and guy:HasTag("companion"))
	end)
end

--[[
Modified version of retarget function for cave spiders from Reign of Giants DLC
--]]
local function CaveSpidersRetarget(inst)
    local targetDist = GLOBAL.TUNING.SPIDER_WARRIOR_TARGET_DIST
    if GLOBAL.GetSeasonManager() and GLOBAL.GetSeasonManager():IsSpring() then
        targetDist = targetDist * GLOBAL.TUNING.SPRING_COMBAT_MOD
    end
    return GLOBAL.FindEntity(inst, targetDist, function(guy)
        return ((guy:HasTag("character") and not guy:HasTag("monster") and not guy:HasTag(TAG_CHESTER)) or guy:HasTag("pig")) -- this line was modified, chester check was added
               and inst.components.combat:CanTarget(guy)
               and not (inst.components.follower and inst.components.follower.leader == guy)
               and not (inst.components.follower and inst.components.follower.leader == GLOBAL.GetPlayer() and guy:HasTag("companion"))
    end)
end

--[[
Modified version of retarget function for spider queen from Reign of Giants DLC
--]]
local function SpiderQueenRetarget(inst)
    if not inst.components.health:IsDead() and not inst.components.sleeper:IsAsleep() then
        local oldtarget = inst.components.combat.target

        local newtarget = GLOBAL.FindEntity(inst, 10, 
            function(guy) 
                if inst.components.combat:CanTarget(guy) then
                    return (guy:HasTag("character") and not guy:HasTag("monster") and not guy:HasTag(TAG_CHESTER)) -- this line was modified
                end
            end)
        
        if newtarget and newtarget ~= oldtarget then
			inst.components.combat:SetTarget(newtarget)
        end
    end
end

--[[
Returns a map of retarget function for spider prefabs
Map's key is a name of prefab ("spider", "spider_warrior", etc )
Map's value is a function to use as a new retarget function for prefab
    prefabName1 -> retargetFunction1
    prefabName2 -> retargetFunction2
    prefabName3 -> retargetFunction3
--]]
local function getSpidersRetargetMap()

	local retargetMap = {}
	
	-- overworld spiders
	retargetMap[PREFAB_SPIDER] = NormalRetarget
	retargetMap[PREFAB_SPIDER_WARRIOR] = WarriorRetarget
	-- cave spiders
	retargetMap[PREFAB_SPIDER_HIDER] = CaveSpidersRetarget
	retargetMap[PREFAB_SPIDER_SPITTER] = CaveSpidersRetarget
	retargetMap[PREFAB_SPIDER_DROPPER] = CaveSpidersRetarget
	-- spider queen
	retargetMap[PREFAB_SPIDER_QUEEN] = SpiderQueenRetarget
    
	return retargetMap
	
end

--[[
Returns retarget function for prefab
Will return nil if function for prefab is not present
--]]
local function getNewSpiderRetargetFn( instance )
	
	local retargetFn = nil
	
	local retargetMap = getSpidersRetargetMap()
	if retargetMap[instance.prefab] then
	    retargetFn = retargetMap[instance.prefab]
	end
	
	return retargetFn

end

--[[
Post init callback function for spiders' prefab
Checks if the player is a Webber and then
sets new retarget function (function that finds targets to attack) for prefab
--]]
local function makeSpidersIgnoreChester( prefab )
    
    -- is player character a Webber?
    local isWebber = (CHARACTER_WEBBER == GLOBAL.GetPlayer().prefab)
	
	-- if player IS Webber...
    if isWebber then
	
		-- ... get a new retarget function for spider prefab
	    local newRetargetFn = getNewSpiderRetargetFn( prefab )

		-- ... if retarget function found and prefab has combat component ...
		if newRetargetFn and prefab.components.combat then
		
			-- set new retarget function with the same period of calling as the last one
		    local prevRetargetPeriod = prefab.components.combat.retargetperiod
		    prefab.components.combat:SetRetargetFunction(prevRetargetPeriod, newRetargetFn)
			
		end
		
	end
	
end

local function main()

    -- get list of spiders prefab
    local retargetMap = getSpidersRetargetMap()
	-- for each spider prefab...
	for prefabName, retargetFn in pairs(retargetMap) do
	    
		-- ... add post init callback function
        AddPrefabPostInit(prefabName, makeSpidersIgnoreChester)
		
    end
	
end

-- MAIN PROGRAM ------------------------------

main()
