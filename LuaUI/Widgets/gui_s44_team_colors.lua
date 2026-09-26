function widget:GetInfo()
    return {
        name    = "1944 Team Colors",
        desc    = "Gives every team a distinct colour locally, grouped by team tone",
        author  = "Spring: 1944 / Zero-K adaptation",
        date    = "2026",
        license = "GNU GPL v2 or later",
        layer   = 0,
        enabled = true,
    }
end

--------------------------------------------------------------------------------
-- Why this exists
--
-- The Zero-K launcher writes the same RgbColor for every team in the start
-- script (Chobby's getTeamColor falls back to one default orange whenever the
-- battle has no per-user colour), so without this everybody -- players and bots
-- alike -- is the same shade. Zero-K solves it the same way, in
-- LuaUI/Widgets/gui_local_colors.lua: Spring.SetTeamColor is unsynced, so each
-- client simply recolours the teams for itself. Nothing here is sent anywhere.
--
-- Colours are assigned deterministically rather than randomly, so they stay put
-- across a reload and both sides of a rejoin agree with themselves.
--------------------------------------------------------------------------------

local function Range(c)
    return {c[1] / 255, c[2] / 255, c[3] / 255}
end

-- You, so you can always find yourself.
local MY_COLOR = Range({50, 250, 50})
local GAIA_COLOR = Range({200, 200, 200})

-- Your own team: shades of blue.
local ALLY_COLORS = {
    Range({50, 110, 255}),
    Range({10, 250, 250}),
    Range({150, 150, 255}),
    Range({60, 170, 190}),
    Range({30, 120, 110}),
    Range({90, 40, 255}),
}

-- Every other team gets a family of its own, and its members get shades of it,
-- so "who is on whose side" reads off the minimap at a glance.
local ENEMY_FAMILIES = {
    { Range({255, 65, 65}),   Range({200, 30, 75}),    Range({170, 40, 40}),    Range({255, 120, 120}) },
    { Range({255, 145, 30}),  Range({255, 180, 50}),   Range({160, 90, 15}),    Range({200, 130, 110}) },
    { Range({255, 255, 40}),  Range({225, 220, 140}),  Range({125, 100, 20}),   Range({200, 190, 60})  },
    { Range({240, 40, 150}),  Range({255, 120, 220}),  Range({170, 20, 100}),   Range({230, 150, 170}) },
    { Range({150, 90, 255}),  Range({110, 60, 200}),   Range({190, 150, 255}),  Range({90, 40, 160})   },
    { Range({180, 100, 100}), Range({140, 80, 60}),    Range({210, 150, 120}),  Range({110, 70, 50})   },
}

local spGetTeamList     = Spring.GetTeamList
local spGetTeamInfo     = Spring.GetTeamInfo
local spGetGaiaTeamID   = Spring.GetGaiaTeamID
local spGetMyTeamID     = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spSetTeamColor    = Spring.SetTeamColor
local spGetSpectatingState = Spring.GetSpectatingState

local function ApplyColors()
    local gaiaTeamID = spGetGaiaTeamID()
    local myTeamID = spGetMyTeamID()
    local myAllyTeamID = spGetMyAllyTeamID()
    local spectating = spGetSpectatingState()

    spSetTeamColor(gaiaTeamID, GAIA_COLOR[1], GAIA_COLOR[2], GAIA_COLOR[3])

    local allyIndex = 0
    local familyOf = {}     -- familyOf[allyTeamID] = index into ENEMY_FAMILIES
    local usedFamilies = 0
    local memberIndex = {}  -- memberIndex[allyTeamID] = how many of it are coloured

    local teamList = spGetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]
        if teamID ~= gaiaTeamID then
            local allyTeamID = select(6, spGetTeamInfo(teamID, false))

            if (not spectating) and (teamID == myTeamID) then
                spSetTeamColor(teamID, MY_COLOR[1], MY_COLOR[2], MY_COLOR[3])
            elseif allyTeamID == myAllyTeamID then
                allyIndex = (allyIndex % #ALLY_COLORS) + 1
                local c = ALLY_COLORS[allyIndex]
                spSetTeamColor(teamID, c[1], c[2], c[3])
            else
                if not familyOf[allyTeamID] then
                    usedFamilies = usedFamilies + 1
                    familyOf[allyTeamID] = ((usedFamilies - 1) % #ENEMY_FAMILIES) + 1
                    memberIndex[allyTeamID] = 0
                end
                local family = ENEMY_FAMILIES[familyOf[allyTeamID]]
                memberIndex[allyTeamID] = (memberIndex[allyTeamID] % #family) + 1
                local c = family[memberIndex[allyTeamID]]
                spSetTeamColor(teamID, c[1], c[2], c[3])
            end
        end
    end

    -- Older widget handlers do not have this; the colours still apply without it.
    if widgetHandler.TeamColorsChanged then
        widgetHandler:TeamColorsChanged()
    end
end

function widget:PlayerChanged()
    ApplyColors()
end

function widget:Initialize()
    ApplyColors()
end
