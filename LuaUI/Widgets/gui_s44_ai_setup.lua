function widget:GetInfo()
    return {
        name    = "1944 A.I. Setup",
        desc    = "Pre-game panel for setting the start position and nation of A.I. teams",
        author  = "Spring: 1944 / Zero-K adaptation",
        date    = "2026",
        license = "GNU GPL v2 or later",
        layer   = 0,
        enabled = true,
    }
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local FLAG_DIR    = "LuaUI/Widgets/faction_change/"
local FLAG_SIZE   = 26
local ROW_HEIGHT  = 88
local WIN_WIDTH   = 330
local MARKER_RISE = 70

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local spGetTeamList        = Spring.GetTeamList
local spGetTeamInfo        = Spring.GetTeamInfo
local spGetTeamColor       = Spring.GetTeamColor
local spGetTeamRulesParam  = Spring.GetTeamRulesParam
local spGetAIInfo          = Spring.GetAIInfo
local spGetMyPlayerID      = Spring.GetMyPlayerID
local spGetMyAllyTeamID    = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetModOptions      = Spring.GetModOptions
local spGetGameFrame       = Spring.GetGameFrame
local spGetGroundHeight    = Spring.GetGroundHeight
local spSendLuaRulesMsg    = Spring.SendLuaRulesMsg
local spTraceScreenRay     = Spring.TraceScreenRay

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local Chili
local main_win
local hintLabel

local canSetSpawns   = false
local canSetFactions = false

local aiTeams = {}
local chosenSide = {}       -- chosenSide[teamID] = "ger", or "" once cleared
local chosenPos = {}        -- chosenPos[teamID] = {x, z}, or false once cleared
local flagButtons = {}
local placeButtons = {}

local placingForTeam

-- Start box polygons, so a click outside a bot's own box can be refused here
-- instead of being silently dropped by the gadget. Same data and same test the
-- gadget uses (LuaRules/Gadgets/start_boxes.lua, CheckStartbox).
-- Loaded in Initialize, not here: the header reads the polygons back out of the
-- game rules params that start_boxes.lua publishes, so LuaRules has to be up.
local startboxConfig

local function LoadStartBoxes()
    local ok, _, GetTriangulatedBoxes = pcall(VFS.Include, "LuaUI/Headers/startbox_utilities.lua")
    if ok and GetTriangulatedBoxes then
        local ok2, boxes = pcall(GetTriangulatedBoxes)
        if ok2 then
            startboxConfig = boxes
        end
    end
end

local SIDES = {}
do
    local sideDefs = VFS.Include("gamedata/sidedata.lua")
    for i = 2, #sideDefs do
        SIDES[#SIDES + 1] = string.lower(sideDefs[i].name)
    end
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function OptionEnabled(value)
    return (value == true) or (value == 1) or (value == "1")
end

local function CrossProduct(px, pz, ax, az, bx, bz)
    return ((px - bx) * (az - bz) - (ax - bx) * (pz - bz))
end

local function InsideStartBox(teamID, x, z)
    local boxID = spGetTeamRulesParam(teamID, "start_box_id")
    if not boxID then
        return true
    end
    local box = startboxConfig and startboxConfig[boxID] and startboxConfig[boxID].boxes
    if not box then
        return true -- cannot tell from here; let the gadget be the judge
    end
    for i = 1, #box do
        local x1, z1, x2, z2, x3, z3 = unpack(box[i])
        if  (CrossProduct(x, z, x1, z1, x2, z2) <= 0)
        and (CrossProduct(x, z, x2, z2, x3, z3) <= 0)
        and (CrossProduct(x, z, x3, z3, x1, z1) <= 0) then
            return true
        end
    end
    return false
end

local function MayConfigure(teamID, myPlayerID, myAllyTeamID)
    local _, _, _, isAI, _, aiAllyTeamID = spGetTeamInfo(teamID, false)
    if not isAI then
        return false
    end
    if myPlayerID == 0 then
        return true
    end
    if spGetAIInfo and (select(3, spGetAIInfo(teamID)) == myPlayerID) then
        return true
    end
    return aiAllyTeamID == myAllyTeamID
end

local function GetShownSide(teamID)
    local side = chosenSide[teamID] or spGetTeamRulesParam(teamID, "side")
    if (side == "") or (side == nil) then
        return nil
    end
    return side
end

local function GetShownPos(teamID)
    local pos = chosenPos[teamID]
    if pos == false then
        return nil
    end
    if pos then
        return pos[1], pos[2]
    end
    local x = spGetTeamRulesParam(teamID, "ai_start_x")
    local z = spGetTeamRulesParam(teamID, "ai_start_z")
    -- -1 is the gadget's "nothing chosen" value
    if x and z and (x >= 0) and (z >= 0) then
        return x, z
    end
end

local function SetHint(text)
    if hintLabel then
        hintLabel:SetCaption(text or "")
    end
end

local function RefreshFlags(teamID)
    local current = GetShownSide(teamID)
    local row = flagButtons[teamID]
    if not row then
        return
    end
    for side, control in pairs(row) do
        control.backgroundColor = (side == current) and {1, 1, 1, 1} or {0.4, 0.4, 0.4, 1}
        control:Invalidate()
    end
end

local function RefreshPlaceButton(teamID)
    local button = placeButtons[teamID]
    if not button then
        return
    end
    if placingForTeam == teamID then
        button.caption = "Click the map"
    elseif GetShownPos(teamID) then
        button.caption = "Move position"
    else
        button.caption = "Set position"
    end
    button:Invalidate()
end

local function StopPlacing()
    local was = placingForTeam
    placingForTeam = nil
    if was then
        RefreshPlaceButton(was)
    end
end

local function StartPlacing(teamID)
    StopPlacing()
    placingForTeam = teamID
    SetHint("Click inside this A.I.'s start box.")
    RefreshPlaceButton(teamID)
end

--------------------------------------------------------------------------------
-- Controls
--------------------------------------------------------------------------------
local function AddTeamRow(parent, teamData, offset)
    local teamID = teamData.teamID
    local r, g, b = spGetTeamColor(teamID)

    Chili.Label:New{
        parent   = parent,
        x        = 4,
        y        = offset,
        right    = 4,
        height   = 18,
        valign   = "center",
        autosize = false,
        caption  = teamData.name .. "   (team " .. teamData.allyTeamID .. ")",
        font     = {size = 14, outline = true, color = {r, g, b, 1},
                    outlineWidth = 2, outlineWeight = 2},
    }

    local y = offset + 20

    if canSetFactions then
        flagButtons[teamID] = {}
        for i = 1, #SIDES do
            local side = SIDES[i]
            local button = Chili.Button:New{
                parent  = parent,
                x       = 4 + (i - 1) * (FLAG_SIZE + 2),
                y       = y,
                width   = FLAG_SIZE,
                height  = FLAG_SIZE,
                caption = "",
                padding = {1, 1, 1, 1},
                tooltip = "Fight as " .. string.upper(side),
                OnClick = {function()
                    chosenSide[teamID] = side
                    spSendLuaRulesMsg("ai_side:" .. teamID .. ":" .. side)
                    SetHint("")
                    RefreshFlags(teamID)
                end},
            }
            Chili.Image:New{
                parent = button,
                x = 0, y = 0, right = 0, bottom = 0,
                file = FLAG_DIR .. side .. ".png",
                keepAspect = false,
            }
            flagButtons[teamID][side] = button
        end

        Chili.Button:New{
            parent  = parent,
            x       = 4 + #SIDES * (FLAG_SIZE + 2) + 4,
            y       = y,
            width   = 34,
            height  = FLAG_SIZE,
            caption = "rnd",
            tooltip = "Back to a random nation, picked when the match starts.",
            font    = {size = 11},
            OnClick = {function()
                chosenSide[teamID] = ""
                spSendLuaRulesMsg("ai_clear_side:" .. teamID)
                SetHint("")
                RefreshFlags(teamID)
            end},
        }

        RefreshFlags(teamID)
        y = y + FLAG_SIZE + 6
    end

    if canSetSpawns then
        placeButtons[teamID] = Chili.Button:New{
            parent  = parent,
            x       = 4,
            y       = y,
            width   = 130,
            height  = 24,
            caption = "Set position",
            tooltip = "Click here, then click the map inside this A.I.'s start box.",
            OnClick = {function()
                if placingForTeam == teamID then
                    StopPlacing()
                    SetHint("")
                else
                    StartPlacing(teamID)
                end
            end},
        }
        RefreshPlaceButton(teamID)

        Chili.Button:New{
            parent  = parent,
            x       = 140,
            y       = y,
            width   = 90,
            height  = 24,
            caption = "Automatic",
            tooltip = "Back to an automatic start point inside this A.I.'s start box.",
            font    = {size = 11},
            OnClick = {function()
                if placingForTeam == teamID then
                    StopPlacing()
                end
                chosenPos[teamID] = false
                spSendLuaRulesMsg("ai_clear_start_pos:" .. teamID)
                SetHint("")
                RefreshPlaceButton(teamID)
            end},
        }
    end
end

local function InitializeControls()
    main_win = Chili.Window:New{
        parent    = Chili.Screen0,
        x         = 60,
        y         = 160,
        width     = WIN_WIDTH,
        height    = math.min(96 + #aiTeams * ROW_HEIGHT, 560),
        minWidth  = 260,
        minHeight = 150,
        draggable = true,
        resizable = true,
        padding   = {0, 0, 0, 0},
        caption   = "A.I. Setup",
    }

    Chili.Label:New{
        parent   = main_win,
        x = 0, right = 0, y = 4, height = 24,
        align    = "center",
        valign   = "center",
        autosize = false,
        caption  = "A.I. Setup",
        font     = {size = 18, outline = true, color = {0.85, 0.85, 0.85, 1},
                    outlineWidth = 2, outlineWeight = 2},
    }

    hintLabel = Chili.Label:New{
        parent   = main_win,
        x = 6, right = 6, bottom = 4, height = 18,
        align    = "center",
        valign   = "center",
        autosize = false,
        caption  = "",
        font     = {size = 12, outline = true, color = {1, 0.85, 0.4, 1},
                    outlineWidth = 2, outlineWeight = 2},
    }

    local scroll = Chili.ScrollPanel:New{
        parent              = main_win,
        x = 6, y = 30, right = 6, bottom = 26,
        horizontalScrollbar = false,
    }

    local offset = 0
    for i = 1, #aiTeams do
        AddTeamRow(scroll, aiTeams[i], offset)
        offset = offset + ROW_HEIGHT
    end
end

--------------------------------------------------------------------------------
-- Call-ins
--------------------------------------------------------------------------------
function widget:MousePress(mx, my, button)
    if (button ~= 1) or (not placingForTeam) then
        return false
    end

    local teamID = placingForTeam
    local kind, coords = spTraceScreenRay(mx, my, true)
    if (kind == "ground") and coords then
        local x, z = coords[1], coords[3]
        if InsideStartBox(teamID, x, z) then
            chosenPos[teamID] = {x, z}
            spSendLuaRulesMsg("ai_start_pos:" .. teamID .. ":" .. math.floor(x) .. ":" .. math.floor(z))
            SetHint("")
            StopPlacing()
        else
            -- stay armed so the next click can land properly
            SetHint("Outside that A.I.'s start box - pick another spot.")
        end
    else
        StopPlacing()
        SetHint("")
    end
    return true
end

function widget:MouseRelease()
    return -1
end

function widget:DrawWorld()
    if not canSetSpawns then
        return
    end

    gl.LineWidth(2)
    for i = 1, #aiTeams do
        local teamID = aiTeams[i].teamID
        local x, z = GetShownPos(teamID)
        if x then
            local y = spGetGroundHeight(x, z)
            local r, g, b = spGetTeamColor(teamID)
            gl.Color(r, g, b, 0.9)
            gl.DrawGroundCircle(x, y, z, 96, 24)

            -- label it, so several bots' markers can be told apart
            gl.PushMatrix()
            gl.Translate(x, y + MARKER_RISE, z)
            gl.Billboard()
            gl.Text(aiTeams[i].name, 0, 0, 24, "cvo")
            gl.PopMatrix()
        end
    end
    gl.Color(1, 1, 1, 1)
    gl.LineWidth(1)
end

function widget:GameFrame()
    widgetHandler:RemoveWidget(widget)
end

function widget:Shutdown()
    if main_win then
        main_win:Dispose()
        main_win = nil
    end
end

function widget:Initialize()
    if (not WG.Chili) or (spGetGameFrame() > 0) then
        widgetHandler:RemoveWidget(widget)
        return
    end

    local modOptions = spGetModOptions()
    canSetSpawns   = OptionEnabled(modOptions.set_ai_spawns)
    canSetFactions = OptionEnabled(modOptions.set_ai_factions)
    if not (canSetSpawns or canSetFactions) then
        widgetHandler:RemoveWidget(widget)
        return
    end

    if spGetSpectatingState() then
        widgetHandler:RemoveWidget(widget)
        return
    end

    local myPlayerID = spGetMyPlayerID()
    local myAllyTeamID = spGetMyAllyTeamID()
    local teamList = spGetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]
        if MayConfigure(teamID, myPlayerID, myAllyTeamID) then
            aiTeams[#aiTeams + 1] = {
                teamID     = teamID,
                allyTeamID = select(6, spGetTeamInfo(teamID, false)),
                name       = select(2, spGetAIInfo(teamID)) or ("A.I. " .. teamID),
            }
        end
    end

    if #aiTeams == 0 then
        widgetHandler:RemoveWidget(widget)
        return
    end

    LoadStartBoxes()

    Chili = WG.Chili
    InitializeControls()
end
