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
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local ModStoneService = Remotes.ModStoneService

local UIBasics = require(ReplicatedStorage.Source.SharedModules.UI.UIBasics)
local GeneralUILibrary = require(ReplicatedStorage.Source.SharedModules.UI.GeneralUILibrary)

local ColorPalette = require(ReplicatedStorage.Source.SharedModules.Other.ColorPalette)

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)
local ModStonesInfo = require(ReplicatedStorage.Source.SharedModules.Info.ModStonesInfo)

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

local function SetModStonesFrame()
    local Mods = Gui:WaitForChild("ModStonesFrame")
    
    for _, Slot in Mods:GetChildren() do
        if not Slot then continue end
        if Slot.Name == "UIListLayout" then continue end

        local SlotNum = tonumber(string.sub(Slot.Name, 5, 5))

        -- This is a copy of the icon that can actually be dragged
        local IconDrag = Slot.Icon:Clone()
        IconDrag.Name = "IconDrag"
        IconDrag.Visible = false
        IconDrag.Parent = Slot

        -- Connect interaction for each mod slot
        GeneralUILibrary:AddBaseButtonInteractions(
            Slot, 
            Slot.Button, 
            false,
            IconDrag,
            1,

            function()
                Slot.Icon.ImageTransparency = 0.5
                IconDrag.Visible = true
            end,

            function()
                Slot.Icon.ImageTransparency = 0
                IconDrag.Visible = false

                -- Check to drop the stone
                local CanDrop, DropTo = GeneralUILibrary:CheckDragElementDropped(IconDrag, Slot, true)
                if CanDrop and DropTo then
                    ModStoneService:RequestDropStone(SlotNum, DropTo)
                end

                IconDrag.Position = Slot.Icon.Position
            end
        )
    end
end

local function SetRelicsFrame()
    local Relics = Gui:WaitForChild("RelicsFrame")

    -- Active
    for _, Slot in Relics.Top:GetChildren() do
        if not Slot then continue end
        if Slot.Name == "UIListLayout" then continue end

        local SlotNum = tonumber(string.sub(Slot.Name, 5, 5))

        -- This is a copy of the icon that can actually be dragged
        local IconDrag = Slot.Icon:Clone()
        IconDrag.Name = "IconDrag"
        IconDrag.Visible = false
        IconDrag.Parent = Slot

        Slot.Icon.Image = ""
    end

    -- Inactive (backpack)
    for _, Slot in Relics.Bottom:GetChildren() do
        if not Slot then continue end
        if Slot.Name == "UIListLayout" then continue end

        local SlotNum = tonumber(string.sub(Slot.Name, 5, 5))

        -- This is a copy of the icon that can actually be dragged
        local IconDrag = Slot.Icon:Clone()
        IconDrag.Name = "IconDrag"
        IconDrag.Visible = false
        IconDrag.Parent = Slot

        Slot.Icon.Image = ""
    end
end

local function SetGui()
    SetModStonesFrame()
    SetRelicsFrame()
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

function UpdateBars()
    if not Gui or not UnitValues then return end

end



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function GameplayUIController:UpdateModStoneFrame(List: {[number]: string})
    local Mods = Gui:WaitForChild("ModStonesFrame")

    for Num, Name in ipairs(List) do
        local Frame = Mods:FindFirstChild("Mod_" .. Num)
        local Info = ModStonesInfo[Name]
        if not Frame then continue end

        if Info then
            Frame.Icon.Image = "rbxassetid://" .. Info.Icon
        else
            Frame.Icon.Image = ""
        end

        Frame.IconDrag.Image = Frame.Icon.Image
    end
end

function GameplayUIController:SetCharacter(Character: any)
    while not Gui do
        task.wait(0.25)
    end
    UnitValues = Character:WaitForChild("UnitValues", 3)
    if not UnitValues then return end

    local Bars = Gui:WaitForChild("BarsFrame")

    UnitValues.Current.Health.Changed:Connect(function()
        task.wait()
        GeneralUILibrary:UpdateBar(UnitValues.Current.Health.Value, UnitValues.Current.Health:GetAttribute("Max"), Bars.HealthBar.Bar, Bars.HealthBar.White)
        Bars.HealthBar.Nums.Text = math.floor(UnitValues.Current.Health.Value) .. " / " .. UnitValues.Current.Health:GetAttribute("Max")
    end)

    UnitValues.Current.Health:GetAttributeChangedSignal("Max"):Connect(function()
        task.wait()
        GeneralUILibrary:UpdateBar(UnitValues.Current.Health.Value, UnitValues.Current.Health:GetAttribute("Max"), Bars.HealthBar.Bar, Bars.HealthBar.White, nil, true)
    end)

    UnitValues.Current.Mana.Changed:Connect(function()
        task.wait()
        GeneralUILibrary:UpdateBar(UnitValues.Current.Mana.Value, UnitValues.Current.Mana:GetAttribute("Max"), Bars.ManaBar.Bar, Bars.ManaBar.White)
        Bars.ManaBar.Nums.Text = math.floor(UnitValues.Current.Mana.Value) .. " / " .. UnitValues.Current.Mana:GetAttribute("Max")
    end)

    UnitValues.Current.Mana:GetAttributeChangedSignal("Max"):Connect(function()
        task.wait()
        GeneralUILibrary:UpdateBar(UnitValues.Current.Mana.Value, UnitValues.Current.Mana:GetAttribute("Max"), Bars.ManaBar.Bar, Bars.ManaBar.White, nil, true)
    end)

    UnitValues.Effects.ChildAdded:Connect(function(Effect: any)
        task.wait()
        AddNewEffectBox(Effect)
    end)

    UnitValues.Effects.ChildRemoved:Connect(function(Effect: any)
        CleanEffectBox(Effect)
    end)

    UpdateBars()
end

function GameplayUIController:RunHeartbeat(DeltaTime: number)
    UpdateBars()
end

function GameplayUIController:Init()
    local NewGui = Assets.UIs.GameplayGui:Clone()
    NewGui.Parent = LocalPlayer.PlayerGui

    Gui = NewGui

    SetGui()
end

function GameplayUIController:Deferred()
    ModStoneService.ModStonesUpdated:Connect(function(Current: {[number]: string})
        GameplayUIController:UpdateModStoneFrame(Current)
    end)
end

return GameplayUIController