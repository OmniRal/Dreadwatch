-- OmniRal

local UnitManagerService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local GlobalConstraints = require(ReplicatedStorage.Source.SharedModules.Top.GlobalValues)
local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)

local CharacterService = require(ServerScriptService.Source.ServerModules.General.CharacterService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local HEARTBEAT_RATE = 1 -- How often the update function should happen.

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local HeartbeatHandler: RBXScriptConnection? = nil
local LastHeartbeat: number = 0

local Units: {
    [Player | Model]: {
        Model: Model,
        Dead: boolean,
        Connections: {
            [string]: RBXScriptConnection,
        },

        Clean: boolean?,
    }
} = {}  

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function Cleanup(ThisUnit: Player | Model)
    if not Units then return end
    if not Units[ThisUnit] then return end
    Units[ThisUnit] = nil
end

local function UpdateUnits()
    for Unit, Info in Units do
        -- Safely clean up the unit.
        if Info.Clean then
            Cleanup(Unit)
            continue
        end

        pcall(function()
            
        end)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function UnitManagerService:AddUnit(ThisUnit: Player | Model)
    if not ThisUnit then return end
    if not Units[ThisUnit] then return end

    -- For players
    if ThisUnit:IsA("Player") then
        local Char = ThisUnit.Character
        if not Char then return end
        
        Units[ThisUnit] = {
            Model = Char,
            Dead = false,
            Connections = {

            }
        }

    -- For NPCs and enemies
    elseif ThisUnit:IsA("Model") then
        Units[ThisUnit] = {
            Model = ThisUnit,
            Dead = false,
            Connections = {

            }
        }
    end
end

function UnitManagerService:RemoveUnit(ThisUnit: Player | Model)
    if not ThisUnit then return end
    if not Units[ThisUnit] then return end

    Units[ThisUnit].Clean = true
end

-- Updates all the units on heart beat at the rate set.
function UnitManagerService:RunMain()
    if HeartbeatHandler then return end

    HeartbeatHandler = RunService.Heartbeat:Connect(function(DeltaTime: number)
        if os.clock() < LastHeartbeat + HEARTBEAT_RATE then return end

        UpdateUnits()
    end)
end

-- Stops the updating heartbeat.
function UnitManagerService:StopMain()
    if not HeartbeatHandler then return end
    HeartbeatHandler:Disconnect()
end

function UnitManagerService:Init()
	print("UnitManagerService initialized...")
end

function UnitManagerService:Deferred()
    print("UnitManagerService deferred...")
end

return UnitManagerService