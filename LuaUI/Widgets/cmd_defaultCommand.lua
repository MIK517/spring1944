function widget:GetInfo()
    return {
        name = "1944 Default Commands",
        desc = "Allows using the rightclick for some commands",
        author = "KDR_11k (David Becker), Craig Lawrence",
        date = "2008-06-24",
        license = "Public Domain",
        layer = 1,
        enabled = true
    }
end

local CMD_MOVE = CMD.MOVE
local CMD_FIGHT = CMD.FIGHT
local CMD_ATTACK = CMD.ATTACK
local CMD_CAPTURE = CMD.CAPTURE
local defCom = {}
local fallbackCommand = CMD_FIGHT

-- S:44 assigns custom command IDs at runtime (LuaRules/Configs/customcmds.lua).
local function GetAreaAttackCmdID()
    return Spring.Utilities.CMD.AREAATTACK
end

local function SetDefaultCommand(cmdID)
    fallbackCommand = cmdID
end

options_path = 'Settings/Interface/Commands'
options_order = {'rightClickDefault', 'buildersMove'}
options = {
    rightClickDefault = {
        name = 'Right click on the ground',
        desc = 'Order given by right clicking the ground. Middle click a command button to use that command instead for the rest of the game.',
        type = 'radioButton',
        value = 'fight',
        items = {
            {key = 'fight', name = 'Attack move (units fight their way there)'},
            {key = 'move', name = 'Move'},
        },
        noHotkey = true,
        OnChange = function(self)
            fallbackCommand = (self.value == 'move' and CMD_MOVE) or CMD_FIGHT
        end,
    },
    buildersMove = {
        name = 'Engineers move on right click',
        desc = 'A selection of only engineers and other builders moves instead of attack moving, so they do not wander off to repair or salvage.',
        type = 'bool',
        value = true,
        noHotkey = true,
        OnChange = function(self)
            defCom = {}
            for _, unitID in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
                widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
            end
        end,
    },
}

local function GetDefaultCommand()
    return fallbackCommand
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if (not defCom[unitDefID]) then
        local ud = UnitDefs[unitDefID]
        -- mobile combat units except SPGs, AT guns, etc
        --if (ud.speed > 0 and ud.canAttack and not ud.customParams.defaultmove) then
        --    defCom[unitDefID] = CMD_FIGHT
        -- Deployed howitzers with area attack
        --[[else]]if (ud.speed == 0 and ud.customParams.canareaattack and GetAreaAttackCmdID()) then
                defCom[unitDefID] = GetAreaAttackCmdID()
        -- Deployed AT and AA guns
        elseif (ud.speed == 0 and ud.canAttack and not ud.customParams.canareaattack and not ud.isBuilder) then
                defCom[unitDefID] = CMD_ATTACK
        elseif ud.isMobileBuilder and options.buildersMove.value then
                defCom[unitDefID] = CMD_MOVE
        end
    end
end

function widget:Initialize()
    for _, unitID in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
        widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
    end
    WG.SetDefaultCommand = SetDefaultCommand
    WG.GetDefaultCommand = GetDefaultCommand
end

function widget:DefaultCommand(targetType, targetID)
    -- To select the default command, we have several criteria. In order of
    -- priority:
    --   1. If we are targeting an unit, which is abandoned and can be captured,
    --      then we return CMD_CAPTURE
    --   2. In case all the selected units share a common "defCom" (see
    --      UnitCreated() above), then we are returning such a "defCom"
    --   3. If no unit is targeted we are returning the global default command,
    --      set with WG.SetDefaultCommand(cmdID).
    --   4. nil/false otherwise, so the engine selects the appropriate command
    --      itself
    local capturableTarget = false
    if targetType == "unit" and (Spring.GetUnitAllyTeam(targetID) ~= Spring.GetMyAllyTeamID()) then
        local targetDefID = Spring.GetUnitDefID(targetID)
        local targetDef = UnitDefs[targetDefID]
        -- radar blips have no visible unitDef
        capturableTarget = targetDef and targetDef.capturable and Spring.GetUnitNeutral(targetID)
    end

    local cmd = false
    for _,u in ipairs(Spring.GetSelectedUnits()) do
        local unitDefID = Spring.GetUnitDefID(u)
        if capturableTarget and UnitDefs[unitDefID].canCapture then
            return CMD_CAPTURE
        end

        local unitDefCom = defCom[Spring.GetUnitDefID(u)]
        if unitDefCom and cmd == false then
            cmd = unitDefCom
        elseif cmd ~= unitDefCom then
            cmd = nil
        end
    end

    -- Builders only default to move on the ground; on units the engine
    -- picks repair, guard or salvage.
    if cmd == CMD_MOVE and targetID then
        cmd = nil
    end

    if not cmd and not targetID then
        cmd = GetDefaultCommand()
    end
    
    return cmd
end

-- A command chosen by middle clicking a button lasts for the current game;
-- the persistent choice is the rightClickDefault option.
local optionApplied = false
function widget:Update()
    if optionApplied then
        return
    end
    optionApplied = true
    options.rightClickDefault.OnChange(options.rightClickDefault)
end
