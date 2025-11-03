-- OmniRal

local ChungusService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local AbilityService = require(ServerScriptService.Source.ServerModules.General.AbilityService)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function ChungusService:UsePassive(Player: Player, Entry: UnitEnum.HistoryEntry): number?
    if not Player or not Entry then return end
    if Entry.Type ~= "DamageDealt" then return end
    local Alive, _, Root = Utility:CheckPlayerAlive(Player)
    if not Alive or not Root then return end

    if AbilityService:OnCooldown(Player, "Chungus", "Passive") then return CustomEnum.ReturnCodes.OnCooldown end

    AbilityService:SetCooldown(Player, "Chungus", "Passive")

    local Ball = Instance.new("Part")
    Ball.Name = "PassiveBall"
    Ball.Anchored = true
    Ball.CanCollide = false
    Ball.CanQuery = false
    Ball.CanTouch = false
    Ball.Locked = true
    Ball.Material = Enum.Material.Neon
    Ball.Color = Color3.fromRGB(255, 50, 50)
    Ball.Size = Vector3.new(3, 3, 3)
    Ball.Shape = Enum.PartType.Ball
    Ball.CFrame = Root.CFrame
    Ball.Parent = Workspace

    TweenService:Create(Ball, TweenInfo.new(1), {Size = Vector3.new(15, 15, 15), Transparency = 1}):Play()
    Debris:AddItem(Ball, 1.1)

    return 1
end

function ChungusService:Init()
	print("ChungusService initialized...")
end

function ChungusService:Deferred()
    print("ChungusService deferred...")
end

return ChungusService