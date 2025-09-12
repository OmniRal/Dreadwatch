--OmniRal

local GameplayUIController = {}

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local UIBasics = require(ReplicatedStorage.Source.SharedModules.UI.UIBasics)

local GeneralUILibrary = require(ReplicatedStorage.Source.SharedModules.UI.GeneralUILibrary)
local ColorPalette = require(ReplicatedStorage.Source.SharedModules.Other.ColorPalette)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CURRENT_WEAPON_FRAME_PROPS = {
    Hidden = {Position = UDim2.fromScale(0.65, 0.925), GroupTransparency = 1},
    Visible = {Position = UDim2.fromScale(0.65, 0.89), GroupTransparency = 0},
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local Gui : ScreenGui
local HealthFrame
local CurrentWeaponFrame 

local UnitAttributes

local EffectBoxes = {}

local CurrentUnits = {}

local Assets = ReplicatedStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

local function SetCurrentWeaponFrame(CurrentWeaponFrame: any)
    local CWFTweens = {}
    local CWFHiddenDelay = nil
    local LastWeapon = "None"

    local AmountClipsChangeTween = nil
    local AmountMagsChangeTween = nil

    local ClipsAnimTween = nil
    local MagsAnimTween = nil

    CurrentWeaponFrame:SetAttribute("Current", "None")
    CurrentWeaponFrame:SetAttribute("Clips", 0)
    CurrentWeaponFrame:SetAttribute("Mags", 0)
    CurrentWeaponFrame:SetAttribute("ClipsAnim", "None")
    CurrentWeaponFrame:SetAttribute("MagsAnim", "None")

    CurrentWeaponFrame:GetAttributeChangedSignal("Current"):Connect(function()
        if CWFHiddenDelay then
            task.cancel(CWFHiddenDelay)
        end
        for _, OldTween in CWFTweens do
            if not OldTween then continue end
            OldTween:Cancel()
            OldTween = nil
        end
        table.clear(CWFTweens)

        local Props, EasingStyle, EasingDirection = CURRENT_WEAPON_FRAME_PROPS.Hidden, Enum.EasingStyle.Back, Enum.EasingDirection.In
        local IsHidden = true
        if CurrentWeaponFrame:GetAttribute("Current") ~= "None" then
            IsHidden = false

            if LastWeapon ~= CurrentWeaponFrame:GetAttribute("Current") then
                CurrentWeaponFrame.Position = CURRENT_WEAPON_FRAME_PROPS.Hidden.Position
                CurrentWeaponFrame.GroupTransparency.Value = 1
            end
        else
            CWFHiddenDelay = task.delay(0.5, function()
                if not CurrentWeaponFrame:GetAttribute("Hidden") then 
                    return
                end
                CurrentWeaponFrame.Visible = false
            end)
        end

        if not IsHidden then
            Props = CURRENT_WEAPON_FRAME_PROPS.Visible
            EasingDirection = Enum.EasingDirection.Out
        end
        CurrentWeaponFrame.Visible = true

        local MoveTween = TweenService:Create(CurrentWeaponFrame, TweenInfo.new(0.25, EasingStyle, EasingDirection), {Position = Props.Position})
        local TransTween = TweenService:Create(CurrentWeaponFrame.GroupTransparency, TweenInfo.new(0.25, EasingStyle, EasingDirection), {Value = Props.GroupTransparency})

        table.insert(CWFTweens, MoveTween)
        table.insert(CWFTweens, TransTween)

        MoveTween:Play()
        TransTween:Play()

        LastWeapon = CurrentWeaponFrame:GetAttribute("Current")
    end)

    CurrentWeaponFrame.GroupTransparency.Changed:Connect(function()
        local Transparency = CurrentWeaponFrame.GroupTransparency.Value
        CurrentWeaponFrame.Icon.ImageTransparency = Transparency
        CurrentWeaponFrame.Clips.TextTransparency = Transparency
        CurrentWeaponFrame.Clips.Stroke.Transparency = Transparency
        CurrentWeaponFrame.Mags.TextTransparency = Transparency
        CurrentWeaponFrame.Mags.Stroke.Transparency = Transparency
    end)

    CurrentWeaponFrame:GetAttributeChangedSignal("Clips"):Connect(function()
        if AmountClipsChangeTween then
            AmountClipsChangeTween:Cancel()
            AmountClipsChangeTween = nil
        end
        if CurrentWeaponFrame:GetAttribute("Clips") == -2 then
            CurrentWeaponFrame.Clips.Visible = false
            return
        end

        if CurrentWeaponFrame:GetAttribute("Clips") > CurrentWeaponFrame:GetAttribute("MaxClips") * 0.25 then 
            CurrentWeaponFrame.Clips.TextColor3 = ColorPalette.JetWhite
        elseif CurrentWeaponFrame:GetAttribute("Clips") > 0 and CurrentWeaponFrame:GetAttribute("Clips") <= CurrentWeaponFrame:GetAttribute("MaxClips") * 0.25 then
            CurrentWeaponFrame.Clips.TextColor3 = ColorPalette.AmmoLow

        elseif CurrentWeaponFrame:GetAttribute("Clips") == 0 then
            CurrentWeaponFrame.Clips.TextColor3 = ColorPalette.AmmoEmpty
        end
        
        CurrentWeaponFrame.Clips.Text = CurrentWeaponFrame:GetAttribute("Clips")
        CurrentWeaponFrame.Clips.Position = UDim2.fromScale(0.5, 0.75)
        
        AmountClipsChangeTween = TweenService:Create(CurrentWeaponFrame.Clips, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0.5, 0.5)})
        AmountClipsChangeTween.Completed:Connect(function()
            AmountClipsChangeTween = nil
        end)
        AmountClipsChangeTween:Play()
    end)

    CurrentWeaponFrame:GetAttributeChangedSignal("Mags"):Connect(function()
        if AmountMagsChangeTween then
            AmountMagsChangeTween:Cancel()
            AmountMagsChangeTween = nil
        end
        if CurrentWeaponFrame:GetAttribute("Mags") == -2 then
            CurrentWeaponFrame.Mags.Visible = false
            return
        end

        if CurrentWeaponFrame:GetAttribute("Mags") > 1 then
            CurrentWeaponFrame.Mags.TextColor3 = ColorPalette.JetWhite
        elseif CurrentWeaponFrame:GetAttribute("Mags") == 1 then
            CurrentWeaponFrame.Mags.TextColor3 = ColorPalette.AmmoLow
        elseif CurrentWeaponFrame:GetAttribute("Mags") == 0 then
            CurrentWeaponFrame.Mags.TextColor3 = ColorPalette.AmmoEmpty
        end

        CurrentWeaponFrame.Mags.Text = "[" .. CurrentWeaponFrame:GetAttribute("Mags") .. "]"
        CurrentWeaponFrame.Mags.Position = UDim2.fromScale(1.25, 1)
        
        AmountMagsChangeTween = TweenService:Create(CurrentWeaponFrame.Mags, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.fromScale(1.25, 0.75)})
        AmountMagsChangeTween.Completed:Connect(function()
            AmountMagsChangeTween = nil
        end)
        AmountMagsChangeTween:Play()
    end)

    CurrentWeaponFrame:GetAttributeChangedSignal("ClipsAnim"):Connect(function()
        if CurrentWeaponFrame:GetAttribute("ClipsAnim") == "None" then return end

        if ClipsAnimTween then
            ClipsAnimTween:Cancel()
            ClipsAnimTween = nil
        end

        CurrentWeaponFrame.Clips.Stroke.Color = ColorPalette.JetBlack
        CurrentWeaponFrame.Clips.Stroke.Thickness = 3

        if CurrentWeaponFrame:GetAttribute("ClipsAnim") == "ClipsMax" then
            ClipsAnimTween = TweenService:Create(
                CurrentWeaponFrame.Clips.Stroke, 
                TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), 
                {Color = ColorPalette.JetBlack:Lerp(ColorPalette.JetWhite, 0.8), Thickness = 4
            })

        elseif CurrentWeaponFrame:GetAttribute("ClipsAnim") == "ClipsEmpty" then
            ClipsAnimTween = TweenService:Create(
                CurrentWeaponFrame.Clips.Stroke, 
                TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), 
                {Color = ColorPalette.JetBlack:Lerp(ColorPalette.AmmoEmpty, 0.8), Thickness = 5
            })
            
        end

        ClipsAnimTween:Play()
        CurrentWeaponFrame:SetAttribute("ClipsAnim", "None")
    end)

    CurrentWeaponFrame:GetAttributeChangedSignal("MagsAnim"):Connect(function()
        if CurrentWeaponFrame:GetAttribute("MagsAnim") == "None" then return end

        if MagsAnimTween then
            MagsAnimTween:Cancel()
            MagsAnimTween = nil
        end

        CurrentWeaponFrame.Mags.Stroke.Color = ColorPalette.JetBlack
        CurrentWeaponFrame.Mags.Stroke.Thickness = 3

        if CurrentWeaponFrame:GetAttribute("MagsAnim") == "MagsMax" then
            MagsAnimTween = TweenService:Create(
                CurrentWeaponFrame.Mags.Stroke, 
                TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), 
                {Color = ColorPalette.JetBlack:Lerp(ColorPalette.JetWhite, 0.8), Thickness = 4
            })

        elseif CurrentWeaponFrame:GetAttribute("MagsAnim") == "MagsEmpty" then
            MagsAnimTween = TweenService:Create(
                CurrentWeaponFrame.Mags.Stroke, 
                TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), 
                {Color = ColorPalette.JetBlack:Lerp(ColorPalette.AmmoEmpty, 0.8), Thickness = 5
            })
            
        end

        MagsAnimTween:Play()
        CurrentWeaponFrame:SetAttribute("MagsAnim", "None")
    end)
end

local function SetGui()
    HealthFrame = Gui:WaitForChild("HealthFrame")
    CurrentWeaponFrame = Gui:WaitForChild("CurrentWeaponFrame")

    SetCurrentWeaponFrame(CurrentWeaponFrame)
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
    if not Gui or not UnitAttributes then return end

end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function GameplayUIController:PlayAmmoAnim(For: "Clips" | "Mags", AnimName: "ClipsMax" | "ClipsEmpty" | "MagsMax" | "MagsEmpty")
    CurrentWeaponFrame:SetAttribute(For .. "Anim", AnimName)
end

function GameplayUIController:UpdateWeaponFrame(Icon: number?, ConnectClips: boolean?, ConnectMags: boolean?)
    if not Icon then
        CurrentWeaponFrame:SetAttribute("Current", "None")
    else
        CurrentWeaponFrame.Icon.Image = "rbxassetid://" .. Icon
        CurrentWeaponFrame:SetAttribute("Current", PlayerInfo.CurrentWeapon)

        if ConnectClips then
            PlayerInfo.WeaponModel.Clips.Changed:Connect(function()
                CurrentWeaponFrame:SetAttribute("Clips", PlayerInfo.WeaponModel.Clips.Value)
            end)
            CurrentWeaponFrame:SetAttribute("Clips", PlayerInfo.WeaponModel.Clips.Value)
            CurrentWeaponFrame:SetAttribute("MaxClips", PlayerInfo.WeaponModel.Clips:GetAttribute("Max"))
        end

        if ConnectMags then
            PlayerInfo.WeaponModel.Mags.Changed:Connect(function()
                CurrentWeaponFrame:SetAttribute("Mags", PlayerInfo.WeaponModel.Mags.Value)
            end)
            CurrentWeaponFrame:SetAttribute("Mags", PlayerInfo.WeaponModel.Mags.Value)
            CurrentWeaponFrame:SetAttribute("MaxMags", PlayerInfo.WeaponModel.Mags:GetAttribute("Max"))
        end
    end
end

function GameplayUIController:SetCharacter(Character: any)
    while not Gui do
        task.wait(0.25)
    end
    UnitAttributes = Character:WaitForChild("UnitAttributes", 3)
    if not UnitAttributes then return end

    local HealthFrame = Gui:WaitForChild("HealthFrame")
    GeneralUILibrary:SetBarGradientTransparency(HealthFrame.BarFrame.Gradient)
    GeneralUILibrary:SetBarGradientTransparency(HealthFrame.WhiteFrame.Gradient)

    UnitAttributes.Current.Health.Changed:Connect(function()
        task.wait()
        GeneralUILibrary:UpdateBarPercent(UnitAttributes.Current.Health.Value, UnitAttributes.Base:GetAttribute("Health"), HealthFrame.BarFrame.Gradient.Percent, HealthFrame.WhiteFrame.Gradient.Percent)
    end)

    UnitAttributes.Effects.ChildAdded:Connect(function(Effect: any)
        task.wait()
        AddNewEffectBox(Effect)
    end)

    UnitAttributes.Effects.ChildRemoved:Connect(function(Effect: any)
        CleanEffectBox(Effect)
    end)

    UpdateMainFrame()
end

function GameplayUIController:RunHeartbeat(DeltaTime: number)
    UpdateMainFrame()
end

function GameplayUIController:Init()
    --local NewGui = Assets.UIs.GameplayUI:Clone()
    --NewGui.Parent = LocalPlayer.PlayerGui
    task.spawn(function()
        Gui = LocalPlayer.PlayerGui:WaitForChild("MainGui")
        SetGui()
    end)
end

function GameplayUIController:Deferred()
    
end

return GameplayUIController