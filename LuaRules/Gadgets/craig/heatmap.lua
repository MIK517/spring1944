-- Author: Jose Luis Cercos-Pita
-- License: GNU General Public License v2

--[[
This class is implemented as a single function returning a table with public
interface methods.  Private data is stored in the function's closure.

Public interface:

function HeatmapMgr.GameStart()
function HeatmapMgr.GameFrame(f)
function HeatmapMgr.UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
]]--

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam

function CreateHeatmapMgr(myTeamID, myAllyTeamID, Log)

local UNITS_PER_FRAME = 5
-- local F_D, F_P, F_A = 1e-8, 1.0 / 50.0, 1e-8
local F_D, F_P, F_A = 1e-7, 0.2, 1e-7
local F_H = 2e-9
local HeatmapMgr = {}

local armourTypesByKey = {}
local armourTypesById = {}
for i, armourType in ipairs(Game.armorTypes) do
    armourTypesById[i] = armourType
    armourTypesByKey[armourType] = i
end
local units = {}
local intelligence

-- UnitDefs[].weapons and WeaponDefs[].customParams build new tables on every
-- access, so read the per-weapon constants once per unit type.
local weaponInfoCache = {}  -- unitDefID -> false | {{p, t, a, radius}, ...}
local function GetWeaponInfo(unitDefID)
    local info = weaponInfoCache[unitDefID]
    if info == nil then
        info = false
        local weapons = UnitDefs[unitDefID].weapons
        if #weapons > 0 then
            info = {}
            for i = 1, #weapons do
                local weaponDef = WeaponDefs[weapons[i].weaponDef]
                local cp = weaponDef.customParams
                info[i] = {
                    p = cp.armor_penetration_1000m or
                        cp.armor_penetration or
                        cp.armor_penetration_100m or
                        0,
                    t = weaponDef.reload / (weaponDef.salvoSize * weaponDef.projectiles),
                    a = weaponDef.accuracy,
                    radius = weaponDef.range,
                }
            end
        end
        weaponInfoCache[unitDefID] = info
    end
    return info
end

-- Heat objects are reused per unit; only the colour changes between passes.
-- The heatmap manager fills in the position fields right after this returns.
local heatCache = {}  -- unitID -> {defID = unitDefID, [i] = heat object}
local NO_HEATS = {}

local function parse_unit(unitID)
    if spGetUnitIsDead(unitID) then
        return NO_HEATS
    end

    local unitDefID = spGetUnitDefID(unitID)
    local info = unitDefID and GetWeaponInfo(unitDefID)
    if not info then
        return NO_HEATS
    end

    -- Ask intelligence if the unit can be parsed
    -- ...

    -- Get the firepower, which is a combination of the potential damage, d,
    -- the penetration, p, the reloading time, t, and the inaccuracy, a:
    --   firepower = sqrt(F_D * (1 + F_P * p) * d / t - F_A * a)
    -- We need to create a heat source for each weapon
    local heats = heatCache[unitID]
    if heats == nil or heats.defID ~= unitDefID then
        heats = {defID = unitDefID}
        for i = 1, #info do
            heats[i] = {radius = info[i].radius,
                        color = {r = 0.0, g = 0.0, b = 0.0, a = 0.0}}
        end
        heatCache[unitID] = heats
    end

    local allied = spGetUnitAllyTeam(unitID) == myAllyTeamID
    for i = 1, #info do
        local w = info[i]
        local d = Spring.GetUnitWeaponDamages(
            unitID, i, armourTypesByKey["unarmouredvehicles"])
        local firepower = math.sqrt(F_D * (1 + F_P * w.p) * d / w.t - F_A * w.a)
        local color = heats[i].color
        if allied then
            color.r, color.g = 0.0, firepower
        else
            color.r, color.g = firepower, 0.0
        end
    end

    return heats
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  The call-in routines
--

function HeatmapMgr.GameStart()
    -- Try to create a Heatmap. This operation would fail if some other allied
    -- team already did the job
    HeatmapMgr.hmap_name = "craig." .. tostring(myAllyTeamID) .. ".ground"
    GG.HeatmapManager:AddHeatmap(HeatmapMgr.hmap_name, parse_unit)
    intelligence = gadget.intelligences[myAllyTeamID]
end

function HeatmapMgr.GameFrame(f)
end

function HeatmapMgr.UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    heatCache[unitID] = nil
end

--------------------------------------------------------------------------------
--
--  Call-outs
--

function HeatmapMgr.FirepowerGradient(x, z)
    local heatmap = GG.HeatmapManager:GetHeatmap(HeatmapMgr.hmap_name)
    local gx, gy = heatmap:GetGradient(x, z)
    return gx, gy
end

return HeatmapMgr
end
