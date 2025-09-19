--OmniRal
--!nocheck

local GameplayUIController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local UIBasics = require(ReplicatedStorage.Source.SharedModules.UI.UIBasics)

local GeneralUILibrary = require(ReplicatedStorage.Source.SharedModules.UI.GeneralUILibrary)
local ColorPalette = require(ReplicatedStorage.Source.SharedModules.Other.ColorPalette)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CURRENT_WEAPON_FRAME_PROPS = {
    Hidden = {Position = UDim2.fromScale(0.65, 0.925), GroupTransparency = 1},
    Visible = {Position = UDim2.fromScale(0.65, 0.89), GroupTransparency = 0},
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local Gui : ScreenGui
local HealthFrame
local CurrentWeaponFrame 

local UnitValues

local EffectBoxes = {}

local CurrentUnits = {}

local Assets = ReplicatedStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function SetGui()
    -- For later
end

function PositionEffectBoxes(CancelDelay: boolean?)
    local BasePositionX = (Gui.BottomFrame.Effects.AbsoluteSize.X / 2)
    local BoxSize = Gui.BottomFrame.Effects.AbsoluteSize.Y
    local BoxPadding = 5
    
    local ActiveEffects = 0

    for _, BoxData in ipairs(EffectBoxes) do
        if not BoxData then continue end
        if not BoxData.Box then continue end
        if BoxData.Box:GetAttribute("Clean") then continue end

        if not BoxData.Effect then
            BoxData.Box:SetAttribute("Clean", true)
        else
            ActiveEffects += 1
        end
    end

    BasePositionX -= ((BoxSize + BoxPadding) * (ActiveEffects - 1)) / 2
    print("Active Effects: ", ActiveEffects)

    local BoxAlignNum = 0
    for Num, BoxData in ipairs(EffectBoxes) do
        if not BoxData then continue end
        if not BoxData.Box then continue end
        if BoxData.Box:GetAttribute("Clean") == true then
            local CleanTween = TweenService:Create(BoxData.Box, TweenInfo.new(UIBasics.BaseTweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.fromScale(0.1, 0.1)})
            CleanTween.Completed:Connect(function()
                BoxData.Box:Destroy()
                for _, Connection in pairs(BoxData.Connections) do
                    if not Connection then continue end
                    Connection:Disconnect()
                end
            end)
            table.remove(EffectBoxes, Num)
            CleanTween:Play()
        else
            local GoalPosition = UDim2.new(0, BasePositionX + (BoxAlignNum * ((BoxSize + BoxPadding) / 1)), 0.5, 0)
            TweenService:Create(BoxData.Box, TweenInfo.new(UIBasics.BaseTweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = GoalPosition, Size = UDim2.fromScale(1, 1)}):Play()
            BoxAlignNum += 1
        end
    end

    if CancelDelay then return end
    task.delay(0.1, function()
        PositionEffectBoxes(true)
    end)
end

function AddNewEffectBox(Effect: any)
    if 1 == 1 then return end
    if not Effect then return end
    if not Effect:GetAttribute("Icon") or not Effect:GetAttribute("Description") or not Effect:GetAttribute("Duration") or not Effect:FindFirstChild("Timer") then return end

    local NewEffectBox = Gui.BottomFrame.Effects.OGEffect:Clone()
    NewEffectBox.Name = Effect.Name
    NewEffectBox.Icon.Image = "rbxassetid://" .. Effect:GetAttribute("Icon")
    NewEffectBox.Bar.BackgroundColor3 = if Effect:GetAttribute("IsBuff") then ColorPalette.HealthGreen else ColorPalette.HealthRed
    NewEffectBox:SetAttribute("Clean", false)
    NewEffectBox.Visible = true
    NewEffectBox.Parent = Gui.BottomFrame.Effects

    local Connections = {}
    if Effect:GetAttribute("Duration") > 0 then
        local TimerConnection = Effect.Timer.Changed:Connect(function()
            if not Effect or not NewEffectBox then return end
            if not Effect:FindFirstChild("Timer") then return end

            NewEffectBox.Bar.Size = UDim2.new(1, -2, Effect.Timer.Value / Effect:GetAttribute("Duration"))
            --[[if Effect.Timer.Value <= 0 then
                NewEffectBox:SetAttribute("Clean", true)
                PositionEffectBoxes()
            end]]
        end)
        table.insert(Connections, TimerConnection)
    end

    local CleanConnection = Effect:GetAttributeChangedSignal("Clean"):Connect(function()
        if not Effect then return end
        if Effect:GetAttribute("Clean") then
            print("Cleaning effect...")
            NewEffectBox:SetAttribute("Clean", true)
            PositionEffectBoxes()
        end
    end)
    table.insert(Connections, CleanConnection)

    table.insert(EffectBoxes, {Effect = Effect, Box = NewEffectBox, Connections = Connections})
    PositionEffectBoxes()
end

function CleanEffectBox(Effect: any)
    for _, BoxData in ipairs(EffectBoxes) do
        if not BoxData then continue end
        if not BoxData.Box then continue end
        if BoxData.Effect == Effect or nil then
            BoxData.Box:SetAttribute("Clean", true)
        end
    end
    PositionEffectBoxes()
end

function UpdateMainFrame()
    if not Gui or not UnitValues then return end

end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function GameplayUIController:SetCharacter(Character: any)
    while not Gui do
        task.wait(0.25)
    end
    UnitValues = Character:WaitForChild("UnitValues", 3)
    if not UnitValues then return end

    local MainFrame = Gui:WaitForChild("MainFrame")

    UnitValues.Current.Health.Changed:Connect(function()
        task.wait()
        GeneralUILibrary:UpdateBar(UnitValues.Current.Health.Value, UnitValues.Current.Health:GetAttribute("Max"), MainFrame.HealthBar.Bar, MainFrame.HealthBar.White)
    end)

    UnitValues.Effects.ChildAdded:Connect(function(Effect: any)
        task.wait()
        AddNewEffectBox(Effect)
    end)

    UnitValues.Effects.ChildRemoved:Connect(function(Effect: any)
        CleanEffectBox(Effect)
    end)

    UpdateMainFrame()
end

function GameplayUIController:RunHeartbeat(DeltaTime: number)
    UpdateMainFrame()
end

function GameplayUIController:Init()
    local NewGui = Assets.UIs.GameplayGui:Clone()
    NewGui.Parent = LocalPlayer.PlayerGui

    Gui = NewGui
end

function GameplayUIController:Deferred()
    
end

return GameplayUIController