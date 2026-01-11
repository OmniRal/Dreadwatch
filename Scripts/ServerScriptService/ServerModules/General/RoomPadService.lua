-- OmniRal

local RoomPadService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local AllPads: {
    [Model]: {
        Owner: Player?, 
        LevelID: number, 
        Password: string?,
        RoomType: "Public" | "Private" | "Friends", 
    }
} = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function SetPad(Pad: Model)
    if not Pad then return end
    local Platform = Pad:FindFirstChild("Platform") :: BasePart
    if not Platform then return end

    AllPads[Pad] = {
        Owner = nil,
        LevelID = 1,
        Password = "None",
        RoomType = "Private",
    }
    
    Platform.Transparency = 0.5

    Platform.Touched:Connect(function(Hit: BasePart)
        if not Hit then return end
        if not Hit.Parent then return end
        
        local ThisPlayer = Players:FindFirstChild(Hit.Parent.Name)
        if not ThisPlayer then return end

        local Alive = Utility.CheckPlayerAlive(ThisPlayer)
        if not Alive then return end

        local Info = AllPads[Pad]
        if not Info then return end

        if not Info.Owner then
            Info.Owner = ThisPlayer
            Remotes.RoomPadService.ShowUI:Fire(ThisPlayer, 1) -- Owner screen
        else
            if Info.Owner == ThisPlayer then return end
            
            if Info.Password == "None" then
                Remotes.RoomPadService.ShowUI:Fire(ThisPlayer, 2) -- Joiner screen
            else
                Remotes.RoomPadService.ShowUI:Fire(ThisPlayer, 3) -- Enter password screen
            end
        end
    end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RoomPadService.GetAllPads()
    for _, Pad in CollectionService:GetTagged("RoomPad") do
        if not Pad then continue end
        SetPad(Pad)
    end
end

function RoomPadService:Init()
    Remotes:CreateToClient("ShowUI", {"number"})
    
    Remotes:CreateToServer("SetPassword", {"Model", "string"}, "Returns", function(Player: Player, Pad: Model, NewPassword: string)
        if not Player or not Pad or not NewPassword then return end
    end)
end

return RoomPadService