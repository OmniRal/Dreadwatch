-- OmniRal

local ModService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)

local ModStoneEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.ModStoneEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function Blast(Position: Vector3)
    task.delay(0.5, function()
        local E = Instance.new("Explosion")
        E.Position = Position
        E.BlastRadius = 5
        E.BlastPressure = 0
        E.Parent = Workspace
    end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function ModService:RunThroughMods(Player: Player, BaseAction: () -> (), Position: Vector3)
    if not Player or not BaseAction then return end
    local Mods : ModStoneEnum.ModList = DataService:GetPlayerMods(Player)
    if not Mods then return end

    local AddedActions: {() -> ()} = {BaseAction}

    for _, Mod in ipairs(Mods) do
        if Mod == "Echo" then
            table.insert(
                AddedActions, 
                function()
                    task.wait(0.1)
                    BaseAction()
                end
            )

        elseif Mod == "Blast" then
            table.insert(AddedActions, function () Blast(Position) end)
        end
    end

    if #AddedActions <= 0 then return end

    for _, Action in ipairs(AddedActions) do
        if not Action then continue end
        Action()
    end
end

function ModService:Init()
	print("ModService initialized...")
end

function ModService:Deferred()
    print("ModService deferred...")
end

return ModService