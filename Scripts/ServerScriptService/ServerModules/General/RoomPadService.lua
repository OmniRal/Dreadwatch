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
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UPDATE_PADS_RATE = 0.5

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
        LockOut: number,
    }
} = {}

local RunPadsThread: thread? = nil

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function RemovePlayerFromLst(Pad: Model, ThisPlayer: Player)
    warn(1)
    if not Pad or not ThisPlayer then return end
    warn(2)
    local PlayerList = Pad:FindFirstChild("PlayerList") :: Folder
    if not PlayerList then return end

    warn("CLEAN")
    New.CleanAll(PlayerList, ThisPlayer.Name)
end

local function AddPlayerTo(Pad: Model, ThisPlayer: Player)
    if not Pad or not ThisPlayer then return end
    local PlayerList = Pad:FindFirstChild("PlayerList") :: Folder
    if not PlayerList then return end

    New.Instance("IntValue", ThisPlayer.Name, PlayerList, {Value = ThisPlayer.UserId})
end

local function SetPad(Pad: Model)
    if not Pad then return end
    local Platform = Pad:FindFirstChild("Platform") :: BasePart
    if not Platform then return end

    AllPads[Pad] = {
        Owner = nil,
        LevelID = 1,
        Password = "None",
        RoomType = "Private",
        LockOut = 0,
    }
    
    Pad:SetAttribute("Owner", "None")
    Pad:SetAttribute("RequiresPassword", false)
    New.Instance("Folder", "PlayerList", Pad) -- Store a list of the players as values; easy for client to see

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
        if Info.LockOut > 0 then return end

        if not Info.Owner then
            Info.Owner = ThisPlayer
            AddPlayerTo(Pad, ThisPlayer)
            Pad:SetAttribute("Owner", ThisPlayer.Name)

            Remotes.RoomPadService.ShowUI:Fire(ThisPlayer, 1) -- Owner screen
        --[[else
            if Info.Owner == ThisPlayer then return end

            if Info.Password == "None" then
                Remotes.RoomPadService.ShowUI:Fire(ThisPlayer, 2) -- Joiner screen
            else
                Remotes.RoomPadService.ShowUI:Fire(ThisPlayer, 3) -- Enter password screen
            end]]
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

function RoomPadService.Stop()
    if not RunPadsThread then return end
    task.cancel(RunPadsThread)
    RunPadsThread = nil
end

function RoomPadService.Run()
   RoomPadService.Stop()
   
   RunPadsThread = task.spawn(function()
        while true do
            task.wait(UPDATE_PADS_RATE)

            for Pad, Info in AllPads do
                if not Pad or not Info then continue end
                local Platform = Pad:FindFirstChild("Platform") :: BasePart
                if not Platform then continue end

                if Info.LockOut > 0 then
                    Info.LockOut -= 1
                    if Info.LockOut <= 0 then
                        -- Maybe some animation here?
                        continue
                    end
                end

                if not Info.Owner then continue end
                local Alive, _, Root = Utility.CheckPlayerAlive(Info.Owner)
                if not Alive or not Root then continue end

                local RelativeCF = Platform.CFrame:PointToObjectSpace(Root.Position)
                if math.abs(RelativeCF.X) > Platform.Size.X / 2 or Root.Position.Y > Platform.Position.Y + 15 or math.abs(RelativeCF.Z) > Platform.Size.Z / 2 then
                    Info.LockOut = 3
                    RemovePlayerFromLst(Pad, Info.Owner)
                    Pad:SetAttribute("Owner", "None")
                    Info.Owner = nil
                end
            end
        end
    end)
end

function RoomPadService:Init()
    Remotes:CreateToClient("ShowUI", {"number"})
    
    Remotes:CreateToServer("SetPassword", {"Model", "string"}, "Returns", function(Player: Player, Pad: Model, NewPassword: string)
        if not Player or not Pad or not NewPassword then return end
    end)
end

function RoomPadService:Deferred()
    RoomPadService.Run()
end

return RoomPadService