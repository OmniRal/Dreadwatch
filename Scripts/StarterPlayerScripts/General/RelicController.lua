-- OmniRal

local RelicController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local RelicService = Remotes.RelicService

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)
local RelicInfo = require(ReplicatedStorage.Source.SharedModules.Info.RelicInfo)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function UseRelic(Action: string, InputState: Enum.UserInputState, InputObject: InputObject?)
    warn(1)
    if InputState ~= Enum.UserInputState.Begin then return end
    warn(2)
    if PlayerInfo.Dead or not PlayerInfo.Root then return end
    warn(3)

    local SlotNum = tonumber(string.sub(Action, 10, 10))
    local Result_1, Result_2 = RelicService:UseActive(SlotNum, PlayerInfo.Root.Position, Mouse.Hit.Position)

    warn("Result : ", Result_1, Result_2)
    return Result_1, Result_2
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RelicController:SetCharacter()
    RelicController:ToggleControls(true)
end

function RelicController:ToggleControls(Set: boolean)

    if Set then
        ContextActionService:BindAction("UseRelic_1", UseRelic, false, Enum.KeyCode.One)
        ContextActionService:BindAction("UseRelic_2", UseRelic, false, Enum.KeyCode.Two)
        ContextActionService:BindAction("UseRelic_3", UseRelic, false, Enum.KeyCode.Three)

    else
        ContextActionService:UnbindAction("UseRelic_1")
        ContextActionService:UnbindAction("UseRelic_2")
        ContextActionService:UnbindAction("UseRelic_3")
    end
end

function RelicController:Init()
    RelicService.Equipped:Connect(function(RelicName: string)
        print("Equipped ", RelicName)
    end)

    RelicService.Unequipped:Connect(function(RelicName: string)
        print("Unequipped ", RelicName)
    end)

	print("RelicController initialized...")
end

function RelicController:Deferred()
    print("RelicController deferred...")
end

return RelicController