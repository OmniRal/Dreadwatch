-- OmnIRal

local UnitManagerService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

--local UnitAttributeService = require(ServerScriptService.Source.ServerModules.Units.UnitAttributeService)
local CharacterService = require(ServerScriptService.Source.ServerModules.General.CharacterService)
local WorldUIService = require(ReplicatedStorage.Source.SharedModules.UI.WorldUIService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UPDATE_RATE = 1

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Units = {}

local RunSystem : RBXScriptConnection?

local LastUpdate = os.clock()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

function SetupUnit(Model: any, Player: Player?)
    task.spawn(function()
        local Unit = Player or Model

        local Human, Root, Attributes = Model:WaitForChild("Humanoid"), Model:WaitForChild("HumanoidRootPart"), Model:WaitForChild("UnitAttributes")
        if not Human or not Root or not Attributes then return end

        Model.Parent = Workspace.Units
        local HealthChangeConnection = Attributes.Current.Health.Changed:Connect(function()
            if Attributes.States:GetAttribute("Dead") then return end

            if Attributes.Current.Health.Value <= 0 then
                UnitAttributeService:CleanAllEffects(Unit)
                Attributes.States:SetAttribute("Dead", true)
                Human.Health = 0
                Units[Unit].Dead = true
            end
        end)

        Human.MaxSlopeAngle = 89--45

        table.insert(Units[Unit].Connections, HealthChangeConnection)

        --WorldUIService:GuiPointForUnit(Model)
    end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function UnitManagerService:RemoveUnit(Unit: Player | Model)
    if not Unit then return end
    if not Units[Unit] then return end
    Units[Unit] = nil
end

function UnitManagerService:AddUnit(Unit: Player | Model)
    print("Attempting to add unit: ", Unit)
    if Unit:IsA("Player") then
        if not Unit:GetAttribute("Team") then
            Unit:SetAttribute("Team", "Blue")
        end
        
        local Char = Unit.Character :: Model
        Units[Unit] = {Model = Char, Dead = false, Connections = {}}
        Char:SetAttribute("Team", Unit:GetAttribute("Team"))

        SetupUnit(Unit.Character, Unit)
        Remotes.UnitManagerService.PlayerUnitAdded:Fire(Unit)

    elseif Unit:IsA("Model") then
        if Units[Unit] then return end
        Units[Unit] = {Model = Unit, Dead = false, Connections = {}}

        SetupUnit(Unit)
    end
end

function UnitManagerService:Run()
    if RunSystem then
        RunSystem:Disconnect()
    end
    RunSystem = RunService.Heartbeat:Connect(function(DeltaTime: number)
        if os.clock() < LastUpdate + UPDATE_RATE then return end

        LastUpdate = os.clock()

        for Unit, Info in Units do
            if not Info then continue end
            if not Info.Model then continue end

            if Info.Dead then
                for _, OldConnection in Info.Connections do
                    if not OldConnection then continue end
                    OldConnection:Disconnect()
                end

                Info[Unit] = nil
                continue
            end

            local UnitAttributes = UnitAttributeService:Get(Unit)
            if not UnitAttributes then continue end

            if Unit:IsA("Player") then
                if not Players:FindFirstChild(Unit.Name) then
                    Units[Unit] = nil
                    continue
                end

                if not Info.Model and Unit.Character then
                    Info.Model = Unit.Character
                end
            end

            if not Info.Model then continue end

            pcall(function()
                CharacterService:ApplyHealthGain("Unit Manager", Unit,
                    math.clamp(UnitAttributes.Base.HealthGain + UnitAttributes.Offsets.HealthGain, CustomEnum.BaseAttributeLimits.HealthGain.Min, CustomEnum.BaseAttributeLimits.HealthGain.Max)
                )
                CharacterService:ApplyManaGain("Unit Manager", Unit,
                    math.clamp(UnitAttributes.Base.ManaGain + UnitAttributes.Offsets.ManaGain, CustomEnum.BaseAttributeLimits.ManaGain.Min, CustomEnum.BaseAttributeLimits.ManaGain.Max)
                )
            end)
        end
    end)
end

function UnitManagerService:Stop()
    if RunSystem then
        RunSystem:Disconnect()
    end
    RunSystem = nil
end

function UnitManagerService:Init()
    Remotes:CreateToClient("PlayerUnitAdded", {}, "Reliable")
end

function UnitManagerService:Deferred()
    UnitManagerService:Run()
end

return UnitManagerService