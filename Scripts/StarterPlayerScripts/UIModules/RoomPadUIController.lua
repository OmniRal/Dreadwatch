-- OmniRal

local RoomPadUIController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local RoomPadService = Remotes.RoomPadService

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)
local GeneralUILibrary = require(ReplicatedStorage.Source.SharedModules.UI.GeneralUILibrary)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CHECK_PAD_RATE = 0.1 -- How often to check if the player is standing on a pad
local PASSWORD_PLACEHOLDER = "No password set"

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local Gui: any? = nil

local UI_Shown = false

local CheckTick = 0

local AllPads: {Model} = {}
local CurrentPad: Model? = nil

local SharedAssets = ReplicatedStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function SetGui()
    if not Gui then return end
    if not Gui:FindFirstChild("Frame") then return end

    local OwnerView, JoinerView, PasswordView = Gui.Frame:FindFirstChild("OwnerView"), Gui.Frame:FindFirstChild("JoinerView"), Gui.Frame:FindFirstChild("PasswordView")
    if not OwnerView or not JoinerView or not PasswordView then return end

    GeneralUILibrary.AddBaseButtonInteractions(OwnerView.PrepView.Password.Confirm, OwnerView.PrepView.Password.Confirm.Button)

    OwnerView.PrepView.Password.Confirm:GetAttributeChangedSignal("Locked"):Connect(function()
        local Locked = OwnerView.PrepView.Password.Confirm:GetAttribute("Locked")
        
        OwnerView.PrepView.Password.Confirm.Button.AutoButtonColor = not Locked
        if Locked then
            OwnerView.PrepView.Password.Confirm.Button.BackgroundTransparency = 0.5
            OwnerView.PrepView.Password.Confirm.Button.TextTransparency = 0.5
        else
            OwnerView.PrepView.Password.Confirm.Button.BackgroundTransparency = 0
            OwnerView.PrepView.Password.Confirm.Button.TextTransparency = 0
        end
    end)

    OwnerView.PrepView.Password.Confirm.Button.Activated:Connect(function()
        if OwnerView.PrepView.Password.Confirm:GetAttribute("Locked") then return end
        if OwnerView.PrepView.Password.TextBox.Text == "" or OwnerView.PrepView.Password.TextBox.Text == OwnerView.PrepView.Password.TextBox.PlaceholderText then return end

        -- Change the password
        local NewPassword = OwnerView.PrepView.Password.TextBox.Text
        local Result = RoomPadService:SetPassword(CurrentPad, NewPassword)
        if Result == 1 then
            OwnerView.PrepView.Password.TextBox.Text = ""
            OwnerView.PrepView.Password.TextBox.PlaceholderText = NewPassword
        end
    end)
    
    GeneralUILibrary.AddBaseButtonInteractions(OwnerView.PrepView.Password.Cancel, OwnerView.PrepView.Password.Cancel.Button)

    OwnerView.PrepView.Password.Cancel:GetAttributeChangedSignal("Locked"):Connect(function()
        local Locked = OwnerView.PrepView.Password.Cancel:GetAttribute("Locked")
        
        OwnerView.PrepView.Password.Cancel.Button.AutoButtonColor = not Locked
        if Locked then
            OwnerView.PrepView.Password.Cancel.Button.BackgroundTransparency = 0.5
            OwnerView.PrepView.Password.Cancel.Button.TextTransparency = 0.5
        else
            OwnerView.PrepView.Password.Cancel.Button.BackgroundTransparency = 0
            OwnerView.PrepView.Password.Cancel.Button.TextTransparency = 0
        end
    end)

    OwnerView.PrepView.Password.Cancel.Button.Activated:Connect(function()
        if OwnerView.PrepView.Password.Cancel:GetAttribute("Locked") then return end
        if OwnerView.PrepView.Password.TextBox.PlaceholderText == PASSWORD_PLACEHOLDER then return end
        
        -- Set NO password
        RoomPadService:SetPassword(CurrentPad, "")
        OwnerView.PrepView.Password.TextBox.Text = ""
        OwnerView.PrepView.Password.TextBox.PlaceholderText = PASSWORD_PLACEHOLDER
    end)

    task.delay(1, function() 
        GeneralUILibrary.CleanSpecificOldGui(LocalPlayer, Gui, "RoomPadUI") 
    end)
end

local function ResetViews()
    if not Gui then return end

    Gui.Frame.OwnerView.Visible = false
    Gui.Frame.JoinerView.Visible = false
    Gui.Frame.PasswordView.Visible = false
end

local function GetPads()
    for _, Pad in CollectionService:GetTagged("RoomPad") do
        if not Pad then continue end
        table.insert(AllPads, Pad)
    end
end

-- Check if the player is standing inside any room pad
local function CheckInPad() : Model?
    if PlayerInfo.Dead or not PlayerInfo.Root then return end

    local SetTo: Model? = nil

    for _, Pad in AllPads do
        if not Pad then continue end
        local Platform = Pad:FindFirstChild("Platform")
        if not Pad:GetAttribute("Owner") or not Platform then continue end

        local RelativeCF = Platform.CFrame:PointToObjectSpace(PlayerInfo.Root.Position)
        if math.abs(RelativeCF.X) > Platform.Size.X / 2 or PlayerInfo.Root.Position.Y > Platform.Position.Y + 15 or math.abs(RelativeCF.Z) > Platform.Size.Z / 2 then continue end

        SetTo = Pad
    end

    return SetTo
end

local function UpdateUI()
    if not Gui or not CurrentPad then return end
    if not Gui:FindFirstChild("Frame") then return end

    local OwnerView, JoinerView, PasswordView = Gui.Frame:FindFirstChild("OwnerView"), Gui.Frame:FindFirstChild("JoinerView"), Gui.Frame:FindFirstChild("PasswordView")
    if not OwnerView or not JoinerView or not PasswordView then return end

    if CurrentPad:GetAttribute("Owner") == LocalPlayer.Name then
        -- Owner view
        if OwnerView.PrepView.Password.TextBox.Text == "" or OwnerView.PrepView.Password.TextBox.Text == OwnerView.PrepView.Password.TextBox.PlaceholderText then
            OwnerView.PrepView.Password.Confirm:SetAttribute("Locked", true)
        else
            OwnerView.PrepView.Password.Confirm:SetAttribute("Locked", false)
        end

        if OwnerView.PrepView.Password.TextBox.PlaceholderText == PASSWORD_PLACEHOLDER then
            OwnerView.PrepView.Password.Cancel:SetAttribute("Locked", true)
        else
            OwnerView.PrepView.Password.Cancel:SetAttribute("Locked", false)
        end

    else

    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RoomPadUIController.ShowUI(SetTo: number)
    if not Gui then return end

    ResetViews()

    if SetTo == 1 then
        Gui.Frame.OwnerView.Visible = true
    
    elseif SetTo == 2 then
        Gui.Frame.JoinerView.Visible = true

    else
        Gui.Frame.PasswordView.Visible = true
    end

    Gui.Frame.Visible = true
    UI_Shown = true
end

function RoomPadUIController.HideUI()
    if not Gui then return end

    Gui.Frame.Visible = false
    UI_Shown = false
end

function RoomPadUIController.RunHeartbeat(DeltaTime: number)
    CheckTick += DeltaTime
    if CheckTick < CHECK_PAD_RATE then return end

    CheckTick = 0

    local SetTo = CheckInPad()

    if SetTo == CurrentPad then 
        UpdateUI()
        return 
    end

    CurrentPad = SetTo

    if CurrentPad then
        local PlayerList, Platform = CurrentPad:FindFirstChild("PlayerList"), CurrentPad:FindFirstChild("Platform")
        if not PlayerList or not Platform then return end
        
        if CurrentPad:GetAttribute("Owner") == LocalPlayer.Name then
            RoomPadUIController.ShowUI(1)
        else
            if PlayerList:FindFirstChild(LocalPlayer.Name) then
                RoomPadUIController.ShowUI(2)
            else
                if not CurrentPad:GetAttribute("RequiresPassword") then return end
                RoomPadUIController.ShowUI(3)
            end
        end
        
    else
        if not UI_Shown then return end
        RoomPadUIController.HideUI()
    end
end

function RoomPadUIController:Init()
    if StarterGui:FindFirstChild("RoomPadUI") then
        StarterGui.RoomPadUI:Destroy()
    end

    local NewGui = SharedAssets.UIs.RoomPadUI:Clone()
    NewGui.Enabled = true
    NewGui.Frame.Visible = false
    NewGui:SetAttribute("Keep", true)
    NewGui.Parent = LocalPlayer.PlayerGui
    
    Gui = NewGui
    
    SetGui()
end

function RoomPadUIController:Deferred()
    GetPads()

    RoomPadService.ShowUI:Connect(function(SetTo: number)
        RoomPadUIController.ShowUI(SetTo)
    end)
end

return RoomPadUIController