-- OmniRal

local RelicService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

local RelicEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.RelicEnum)
local RelicInfo = require(ReplicatedStorage.Source.SharedModules.Info.RelicInfo)

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

local function CreateNewRelic(Relic: string, Position: Vector3): boolean?
    local Info = RelicInfo[Relic]
    if not Info then return end

    local NewRelic: Model = New.Instance("Model", Relic, Workspace)
    NewRelic:AddTag("Relic")

    local NewBase = New.Instance("Part", "Base", NewRelic,
        {
            Anchored = true, CanCollide = false, CanQuery = true, CanTouch = false, Color = Info.RelicColor, 
            Material = Enum.Material.SmoothPlastic, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(Position)
        }
    )

    NewRelic.PrimaryPart = NewBase

    return true
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Player attempts to drop a mod Relic out near them
-- @SlotNum : The mod slot in their data they wish to drop
-- @DropTo : Where to drop it
function RelicService.RequestDropRelic(Player: Player, SlotNum: number, DropTo: Vector3?): boolean?
    if not Player or not SlotNum then return end
    local Alive, _, Root = Utility.CheckPlayerAlive(Player)
    if not Alive or not Root then return end

    local Mods = DataService:GetPlayerRelics(Player)
    if not Mods then return end
    if not Mods[SlotNum] then return end
    if Mods[SlotNum] == "None" then return end

    local DropPosition = DropTo
    
    if not DropPosition then
        -- If DropTo was not provided, set DropPosition to be in front of the player
        DropPosition = (Root.CFrame * CFrame.new(0, 0, -10)).Position

    else
        -- If DropTo is too far, bring reduce its distance but keeping it in the same direction
        DropPosition = (CFrame.new(Root.Position, DropPosition) * CFrame.new(0, 0, -10)).Position
    end

    -- Try to drop the Relic onto the ground using a raycast
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {Player.Character, Workspace.Units}
    Params.IgnoreWater = true
    local NewRay, Dropped = Workspace:Raycast(DropPosition + Vector3.new(0, 10, 0), Vector3.new(0, -25, 0), Params), false
    if NewRay then
        if NewRay.Position then
            Dropped = CreateNewRelic(Mods[SlotNum], NewRay.Position)
        end
    end

    if not Dropped then return end

    -- Set players data with the new mod
    DataService:SetPlayerRelic(Player, SlotNum, "None")

    return true
end

-- Player attempts to pick up / equip a mod Relic that is on the ground
-- @Relic : The model of the Relic in the 3D world
function RelicService.RequestPickupRelic(Player: Player, RelicName: string, RelicModel: Model?): boolean?
    if not Player or not RelicName then return end
    local Info = RelicInfo[RelicName]
    if not Info then return end

    local Full, OpenSlot = DataService:ArePlayerRelicsFull(Player)
    if Full or not OpenSlot then return end

    DataService:SetPlayerRelic(Player, OpenSlot, RelicName)

    if RelicModel then
        RelicModel:Destroy()
    end

    return true
end

function RelicService:RunThroughMods(Player: Player, BaseAction: () -> (), Position: Vector3)
    if not Player or not BaseAction then return end
    local Mods = DataService:GetPlayerRelics(Player)
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

function RelicService:Init()
    Remotes:CreateToClient("RelicSlotsUpdated", {"table"}, "Reliable")

    Remotes:CreateToServer("RequestDropRelic", {"number", "Vector3?"}, "Returns", function(Player: Player, SlotNum: number, DropTo: Vector3?)
        return RelicService.RequestDropRelic(Player, SlotNum, DropTo)
    end)

    Remotes:CreateToServer("RequestPickupRelic", {"Model"}, "Returns", function(Player: Player, RelicName: string, Relic: Model)
        return RelicService.RequestPickupRelic(Player, RelicName, Relic)
    end)

	print("RelicService initialized...")
end

function RelicService.PlayerAdded(Player: Player)
    if not Player then return end
    
    task.delay(1, function()
        local CurrentMods = DataService:GetPlayerRelics(Player)
        Remotes.RelicService.RelicSlotsUpdated:Fire(Player, CurrentMods)
    end)

end

return RelicService