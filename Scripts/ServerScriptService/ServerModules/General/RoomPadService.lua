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

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)
local ColorPalette = require(ReplicatedStorage.Source.SharedModules.Other.ColorPalette)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UPDATE_PADS_RATE = 0.1
local SET_FIRST_ONE_WITH_FAKE_OWNER = true

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local AllPads: {
    [Model]: {
        Owner: Player | string?, 
        LevelID: number, 
        RoomType: CustomEnum.RoomPadType,
        Password: string?,
        Players: {Player?},
        Locked: number,
    }
} = {}

local RunPadsThread: thread? = nil

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function RemovePlayerFromLst(Pad: Model, ThisPlayer: Player)
    if not Pad or not ThisPlayer then return end

    local Info = AllPads[Pad]
    local PlayerList = Pad:FindFirstChild("PlayerList") :: Folder
    if not Info or not PlayerList then return end

    local Index = table.find(Info.Players, ThisPlayer)
    if Index then
        table.remove(Info.Players, Index)
    end

    New.CleanAll(PlayerList, ThisPlayer.Name)
end

local function AddPlayerTo(Pad: Model, ThisPlayer: Player)
    if not Pad or not ThisPlayer then return end

    local Info = AllPads[Pad]
    local PlayerList = Pad:FindFirstChild("PlayerList") :: Folder
    if not Info or not PlayerList then return end

    if table.find(Info.Players, ThisPlayer) or PlayerList:FindFirstChild(ThisPlayer.Name) then return end

    New.Instance("IntValue", ThisPlayer.Name, PlayerList, {Value = ThisPlayer.UserId})
end

local function SetPad(Pad: Model, FakeOwner: boolean?)
    if not Pad then return end
    local Platform = Pad:FindFirstChild("Platform") :: BasePart
    if not Platform then return end

    AllPads[Pad] = {
        Owner = if not FakeOwner then nil else "FakeTestOwner",
        LevelID = 1,
        Password = if not FakeOwner then "None" else "Jizz",
        RoomType = "Private",
        Players = {},
        Locked = 0,
    }
    
    Pad:SetAttribute("Owner", if not FakeOwner then "None" else "FakeTestOwner")
    Pad:SetAttribute("RoomType", if not FakeOwner then "Private" else "Private")
    Pad:SetAttribute("RequiresPassword", if not FakeOwner then false else true)
    New.Instance("Folder", "PlayerList", Pad) -- Store a list of the players as values; easy for client to see

    Platform.Transparency = 0.5
    Platform.Color = if not FakeOwner then ColorPalette.RoomPad_Available else ColorPalette.RoomPad_BeingUsed

    Platform.Touched:Connect(function(Hit: BasePart)
        if not Hit then return end
        if not Hit.Parent then return end
        
        local ThisPlayer = Players:FindFirstChild(Hit.Parent.Name)
        if not ThisPlayer then return end

        local Alive = Utility.CheckPlayerAlive(ThisPlayer)
        if not Alive then return end

        local Info = AllPads[Pad]
        if not Info then return end
        if Info.Locked > 0 then return end

        if not Info.Owner then
            Info.Locked = 5
            Info.Owner = ThisPlayer
            AddPlayerTo(Pad, ThisPlayer)
            Pad:SetAttribute("Owner", ThisPlayer.Name)
            Platform.Color = ColorPalette.RoomPad_BeingUsed
            warn("New Owner:", ThisPlayer)

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

-- Change the type of room between public, private and friends
local function ChangeType(Player: Player, Pad: Model, Type: CustomEnum.RoomPadType?)
    if not Player or not Pad then return CustomEnum.ReturnCodes.MissingData end
        
    local Info = AllPads[Pad]
    if not Info then return CustomEnum.ReturnCodes.ComplexError, 1 end

    if Info.Owner ~= Player then return CustomEnum.ReturnCodes.ComplexError, 2 end -- Player is not the owner

    -- Cycle through
    if not Type then
        if Info.RoomType == "Private" then
            Type = "Friends"
        elseif Info.RoomType == "Friends" then
            Type = "Public"
        else
            Type = "Private"
        end
    end

    if Type ~= "Public" and Type ~= "Private" and Type ~= "Friends" then return CustomEnum.ReturnCodes.ComplexError, 3 end -- Invalid room type

    Info.RoomType = Type
    Pad:SetAttribute("RoomType", Type)

    return 1
end

-- Set a new password for the room
local function SetPassword(Player: Player, Pad: Model, NewPassword: string): (number, number?)
    if not Player or not Pad then return CustomEnum.ReturnCodes.MissingData end
        
    local Info = AllPads[Pad]
    if not Info then return CustomEnum.ReturnCodes.ComplexError, 1 end

    if NewPassword == "None" then
        print("Cannont set password as none!")
        return CustomEnum.ReturnCodes.ComplexError, 2 -- Cannot set the password as "None"
    end

    if NewPassword == "" then
        print("Password removed!")
        Info.Password = "None"
    else
        print("Password set to:", NewPassword)
        Info.Password = NewPassword
    end

    warn(Info)

    return 1
end

local function AttemptJoin(Player: Player, Pad: Model, Password: string?): number?
    if not Player or not Pad then return CustomEnum.ReturnCodes.MissingData end

    local Info = AllPads[Pad]
    if not Info then return CustomEnum.ReturnCodes.ComplexError, 1 end

    if Info.Password and Password ~= Info.Password then return CustomEnum.ReturnCodes.ComplexError, 2 end -- Password incorrect

    AddPlayerTo(Pad, Player)

    return 1
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RoomPadService.GetAllPads()
    local Count = 0
    for _, Pad in CollectionService:GetTagged("RoomPad") do
        if not Pad then continue end
        Count += 1
        SetPad(Pad, if Count == 1 and SET_FIRST_ONE_WITH_FAKE_OWNER then true else false)
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

                if Info.Locked > 0 then
                    Info.Locked -= 1
                    if Info.Locked <= 0 and not Info.Owner then
                        Platform.Color = ColorPalette.RoomPad_Available

                        -- Maybe some animation here?
                    end

                    continue
                end

                if not Info.Owner then continue end
                if Info.Owner == "FakeTestOwner" then continue end
                local Alive, _, Root = Utility.CheckPlayerAlive(Info.Owner)
                if not Alive or not Root then continue end

                local RelativeCF = Platform.CFrame:PointToObjectSpace(Root.Position)
                if math.abs(RelativeCF.X) > Platform.Size.X / 2 or Root.Position.Y > Platform.Position.Y + 15 or math.abs(RelativeCF.Z) > Platform.Size.Z / 2 then
                    Info.Locked = 10
                    Platform.Color = ColorPalette.RoomPad_Locked
                    warn("Owner left!")
                    
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

    Remotes:CreateToServer("ChangeType", {"Model", "string?"}, "Returns", function(Player: Player, Pad: Model, Type: CustomEnum.RoomPadType?)
        return ChangeType(Player, Pad, Type)
    end)
    
    Remotes:CreateToServer("SetPassword", {"Model", "string"}, "Returns", function(Player: Player, Pad: Model, NewPassword: string)
        return SetPassword(Player, Pad, NewPassword)
    end)

    Remotes:CreateToServer("AttemptJoin", {"Model", "string?"}, "Returns", function(Player: Player, Pad: Model, Password: string?)
        return AttemptJoin(Player, Pad, Password)
    end)
end

function RoomPadService:Deferred()
    RoomPadService.Run()
end

return RoomPadService