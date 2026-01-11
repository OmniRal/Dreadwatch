-- OmniRal

local RoomPadUIController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local RoomPadService = Remotes.RoomPadService

local GeneralUILibrary = require(ReplicatedStorage.Source.SharedModules.UI.GeneralUILibrary)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local Gui: any? = nil

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

local function ShowUI(SetTo: number)
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
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

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
    RoomPadService.ShowUI:Connect(function(SetTo: number)
        ShowUI(SetTo)
    end)
end

return RoomPadUIController