-- OmniRal

local MainUIController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local VisualService = Remotes.VisualService

local WorldUIService = require(ReplicatedStorage.Source.SharedModules.UI.WorldUIService)

local DeviceController = require(StarterPlayer.StarterPlayerScripts.Source.General.DeviceController)
local GameplayUIController = require(StarterPlayer.StarterPlayerScripts.Source.UIModules.GameplayUIController)
local GeneralUILibrary = require(ReplicatedStorage.Source.SharedModules.UI.GeneralUILibrary)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

MainUIController.Menu = "None"

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Gui

local DraggingUI: {Base: GuiObject?, Element: GuiObject?, Dragging: boolean, DragStart: Vector3?, PositionElement: UDim2?} = {
    Base = nil,
    Element = nil,
    Dragging = false,
    DragStart = nil,
    PositionElement = nil,
}

local Events = ReplicatedStorage.Events
local Assets = ReplicatedStorage.Assets

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function UpdateDrag(Input: InputObject)
    if not DraggingUI.Base or not DraggingUI.Element or not DraggingUI.DragStart or not DraggingUI.PositionElement then return end

    local Delta: Vector3 = Input.Position - DraggingUI.DragStart
    DraggingUI.Element.Position = UDim2.new(
        DraggingUI.PositionElement.X.Scale,
        DraggingUI.PositionElement.X.Offset + Delta.X,
        DraggingUI.PositionElement.Y.Scale,
        DraggingUI.PositionElement.Y.Offset + Delta.Y
    )
end

local function SetGui()

end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

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

    UserInputService.InputChanged:Connect(function(Input: InputObject)
        if not DraggingUI.Dragging then return end
        if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then return end
        UpdateDrag(Input)
    end)

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

    Events.UI.StartDraggingUI.Event:Connect(function(Start: Vector2, Base: GuiObject, Element: GuiObject?, StartDrag: (GuiObject, GuiObject) -> ()?)
        if not Base then return end

        local Position = if Element then Element.Position else Base.Position

        DraggingUI.DragStart = Start
        DraggingUI.Base = Base
        DraggingUI.Element = Element or Base
        DraggingUI.PositionElement = Position
        
        DraggingUI.Dragging = true

        if not StartDrag then return end
        StartDrag(Base, Element or Base)
    end)

    Events.UI.StopDraggingUI.Event:Connect(function(Base: GuiObject, Element: GuiObject?, StopDrag: (GuiObject, GuiObject?) -> ()?)
        DraggingUI.Dragging = false
        DraggingUI.Base = nil
        DraggingUI.Element = nil

        if not StopDrag then return end
        StopDrag(Base, Element or Base)
    end)
end

return MainUIController