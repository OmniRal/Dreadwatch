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

local CHECK_RATE = 0.1 -- How often to check if the player is standing on a pad

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
    if CheckTick < CHECK_RATE then return end

    CheckTick = 0

    local SetTo = CheckInPad()

    if SetTo == CurrentPad then return end -- No change

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