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
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

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
local CurrentPad: {
    Model: Model?,
    ListChangeListener: RBXScriptConnection?,
} = {Model = nil, ListChangeListener = nil}

local SharedAssets = ReplicatedStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function SetGui()
    if not Gui then return end
    if not Gui:FindFirstChild("Frame") then return end

    local OwnerView, JoinerView, PasswordView = Gui.Frame:FindFirstChild("OwnerView"), Gui.Frame:FindFirstChild("JoinerView"), Gui.Frame:FindFirstChild("PasswordView")
    if not OwnerView or not JoinerView or not PasswordView then return end

    -- Change room type button
    GeneralUILibrary.AddBaseButtonInteractions(OwnerView.PrepView.Type, OwnerView.PrepView.Type.Button)
    OwnerView.PrepView.Type:GetAttributeChangedSignal("Locked"):Connect(function()
        local Locked = OwnerView.PrepView.Type:GetAttribute("Locked")
        
        OwnerView.PrepView.Type.Button.AutoButtonColor = not Locked
        if Locked then
            OwnerView.PrepView.Type.Button.BackgroundTransparency = 0.5
            OwnerView.PrepView.Type.Button.TextTransparency = 0.5
        else
            OwnerView.PrepView.Type.Button.BackgroundTransparency = 0
            OwnerView.PrepView.Type.Button.TextTransparency = 0
        end
    end)
    OwnerView.PrepView.Type.Button.Activated:Connect(function() 
        if OwnerView.PrepView.Type:GetAttribute("Locked") then return end
        OwnerView.PrepView.Type:SetAttribute("Locked", true)
        RoomPadService:ChangeType(CurrentPad.Model)
        task.wait(0.5)

        OwnerView.PrepView.Type:SetAttribute("Locked", false)
    end)

    -- Password confirm button
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
        local Result = RoomPadService:SetPassword(CurrentPad.Model, NewPassword)
        if Result == 1 then
            OwnerView.PrepView.Password.TextBox.Text = ""
            OwnerView.PrepView.Password.TextBox.PlaceholderText = NewPassword
        end
    end)
    
    -- Remove password button
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
        RoomPadService:SetPassword(CurrentPad.Model, "")
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

-- Return which frame view is currently open
local function GetCurrentView(): Frame?
    if not Gui or not CurrentPad.Model then return end
    if not Gui:FindFirstChild("Frame") then return end

    local OwnerView, JoinerView, PasswordView = Gui.Frame:FindFirstChild("OwnerView"), Gui.Frame:FindFirstChild("JoinerView"), Gui.Frame:FindFirstChild("PasswordView")
    if not OwnerView or not JoinerView or not PasswordView then return end

    local ThisView = nil

    if OwnerView.Visible then
        if OwnerView.PrepView.Visible then
            ThisView = OwnerView.PrepView
        end

    elseif JoinerView.Visible then
        if JoinerView.PrepView.Visible then
            ThisView = JoinerView.PrepView
        end
    
    else
        ThisView = PasswordView
    end

    return ThisView
end

-- Updates player in the room UI with their headshots
local function UpdatePlayerList(ListFrame: Frame?)
    if not CurrentPad.Model then return end

    if not ListFrame then
        local ThisView = GetCurrentView()
        if ThisView and ThisView:FindFirstChild("CurrentPlayers"):FindFirstChild("List") then
            ListFrame = ThisView.CurrentPlayers.List
        end
    end

    if not ListFrame then return end

    local List = CurrentPad.Model:FindFirstChild("PlayerList") :: Folder
    local OG_Player = ListFrame:FindFirstChild("OG_Player")
    if not List or not OG_Player then return end

    OG_Player.Visible = false

    -- Clean up old ones
    for _, PlayerFrame in ListFrame:GetChildren() do
        if not PlayerFrame then continue end
        if List:FindFirstChild(PlayerFrame.Name) then continue end
        if PlayerFrame == OG_Player or PlayerFrame.Name == "UIListLayout" then continue end
        PlayerFrame:Destroy()
    end

    -- Add new ones
    for _, PlayerVal: IntValue in List:GetChildren() do
        if not PlayerVal then continue end
        if ListFrame:FindFirstChild(PlayerVal.Name) then continue end
        
        task.spawn(function()
            local NewFrame = OG_Player:Clone()
            NewFrame.Owner.Visible = if CurrentPad.Model:GetAttribute("Owner") == PlayerVal.Name then true else false
            NewFrame.Username.Text = PlayerVal.Name
            NewFrame.Icon.Image = Players:GetUserThumbnailAsync(PlayerVal.Value, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
            NewFrame.Visible = true
            NewFrame.Parent = ListFrame
        end)
    end
end

local function UpdateUI()
    if not Gui or not CurrentPad.Model then return end
    if not Gui:FindFirstChild("Frame") then return end

    local OwnerView, JoinerView, PasswordView = Gui.Frame:FindFirstChild("OwnerView"), Gui.Frame:FindFirstChild("JoinerView"), Gui.Frame:FindFirstChild("PasswordView")
    if not OwnerView or not JoinerView or not PasswordView then return end

    if CurrentPad.Model:GetAttribute("Owner") == LocalPlayer.Name then
        -- Owner view

        -- Change room type button
        OwnerView.PrepView.Type.Button.Text = CurrentPad.Model:GetAttribute("RoomType")

        -- Password confirm button
        if OwnerView.PrepView.Password.TextBox.Text == "" or OwnerView.PrepView.Password.TextBox.Text == OwnerView.PrepView.Password.TextBox.PlaceholderText then
            OwnerView.PrepView.Password.Confirm:SetAttribute("Locked", true)
        else
            OwnerView.PrepView.Password.Confirm:SetAttribute("Locked", false)
        end

        -- Remove password button
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

    if SetTo == CurrentPad.Model then 
        UpdateUI()
        return 
    end

    CurrentPad.Model = SetTo
    if CurrentPad.ListChangeListener then
        CurrentPad.ListChangeListener:Disconnect()
        CurrentPad.ListChangeListener = nil
    end

    if CurrentPad.Model then
        local PlayerList, Platform = CurrentPad.Model:FindFirstChild("PlayerList"), CurrentPad.Model:FindFirstChild("Platform")
        if not PlayerList or not Platform then return end

        CurrentPad.ListChangeListener = PlayerList.Changed:Connect(function() 
            UpdatePlayerList()
        end)

        UpdatePlayerList()
        
        if CurrentPad.Model:GetAttribute("Owner") == LocalPlayer.Name then
            RoomPadUIController.ShowUI(1)
        else
            local UINum = 2 -- Joiner view

            if not PlayerList:FindFirstChild(LocalPlayer.Name) then
                return
            end

            if PlayerList:FindFirstChild(LocalPlayer.Name) then
                RoomPadUIController.ShowUI(2)
            else
                if not CurrentPad.Model:GetAttribute("RequiresPassword") then return end
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