-- OmniRal

local RewardController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RewardService = Remotes.RewardService

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local CurrentRewards: {Model} = {}

local SharedAssets = ReplicatedStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CleanupRewards()
    for _, OldReward in CurrentRewards do
        if not OldReward then continue end
        OldReward:Destroy()
    end

    table.clear(CurrentRewards)
end

local function SpawnReward(RewardID: number, RewardType: string, RewardName: string, CF: CFrame)
    local NewReward = SharedAssets.Player.Reward:Clone()
    NewReward:PivotTo(CF)
    NewReward.Parent = Workspace

    NewReward.Base.Prompt.Triggered:Connect(function()
        warn(RewardID, RewardType, RewardName, CF)
        local Result_A, Result_B = RewardService:RequestPickupReward(RewardID, RewardType, RewardName, CF)
        warn(Result_A, Result_B)
    end)

    table.insert(CurrentRewards, NewReward)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RewardController:Init()
end

function RewardController:Deferred()
    RewardService.SpawnReward:Connect(function(RewardID: number, RewardType: LevelEnum.RewardType, RewardName: string, CF: CFrame)
        SpawnReward(RewardID, RewardType, RewardName, CF)
    end)

    RewardService.CleanupRewards:Connect(function()
        CleanupRewards()
    end)
end

return RewardController