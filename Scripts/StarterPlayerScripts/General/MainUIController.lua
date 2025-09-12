-- OmniRal

local MainUIController = {}

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local VisualService = Remotes.VisualService

local WorldUIService = require(ReplicatedStorage.Source.SharedModules.UI.WorldUIService)

local DeviceController = require(StarterPlayer.StarterPlayerScripts.Source.General.DeviceController)
local GameplayUIController = require(StarterPlayer.StarterPlayerScripts.Source.UIModules.GameplayUIController)
local GeneralUILibrary = require(ReplicatedStorage.Source.SharedModules.UI.GeneralUILibrary)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

MainUIController.Menu = "None"

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Gui

local Assets = ReplicatedStorage.Assets

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

local function SetGui()

end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function MainUIController:SetCharacter()
    print("Main UI - Setting character started.")
    if LocalPlayer.Character then
        local Human = LocalPlayer.Character:FindFirstChild("Humanoid")

        GameplayUIController:SetCharacter(LocalPlayer.Character)

        print("Main UI - Setting character complete.")
    end
end

function MainUIController:RunHeartbeat(DeltaTime: number)
    GameplayUIController:RunHeartbeat(DeltaTime)
end

function MainUIController:Init()
    Gui = Assets.UIs.MainGui:Clone()
    Gui.Parent = LocalPlayer.PlayerGui

    print("Main UI Controller Init...")
end

function MainUIController:Deferred()
    print("Main UI Controller Deferred...")

    SetGui()

    DeviceController.CurrentDevice:Connect(function()
        print("Main UI Controller Device ", DeviceController.CurrentDevice:Get())
    end)

    VisualService.SpawnTextDisplay:Connect(function(From: string, Affects: string, DisplayType: string, Position: Vector3, OtherDetails: {}?)
        if not From or not Affects or not DisplayType or not Position then return end

        if DisplayType == CustomEnum.TextDisplayType.HealthGain then
            if Affects ~= LocalPlayer.Name then return end

        elseif DisplayType == CustomEnum.TextDisplayType.KillerDamage or DisplayType == CustomEnum.TextDisplayType.Crit then
            if Affects == LocalPlayer.Name then
                DisplayType = CustomEnum.TextDisplayType.VictimDamage
            end
        
        elseif DisplayType == CustomEnum.TextDisplayType.Miss then
            if Affects == LocalPlayer.Name then
                DisplayType = CustomEnum.TextDisplayType.Evade
            end
        end

        WorldUIService:SpawnTextDisplay(From, Affects, DisplayType, Position, OtherDetails)
    end)
end

return MainUIController