-- OmniRal

local RewardService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local ServerGlobalValues = require(ServerScriptService.Source.ServerModules.Top.ServerGlobalValues)
local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)
local RelicInfo = require(ReplicatedStorage.Source.SharedModules.Info.RelicInfo)
local ItemInfo = require(ReplicatedStorage.Source.SharedModules.Info.ItemInfo)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local RelicService = require(ServerScriptService.Source.ServerModules.General.RelicService)
local ItemService = require(ServerScriptService.Source.ServerModules.General.ItemService)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CIRCLE = math.pi * 2

local SHOW_DETAILS = false

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

type Reward = {Name: string, Rarity: number}
type RewardOption = {RewardID: number, RewardType: string, RewardName: string, CF: CFrame}

local PlayerRewards: {
    [Player]: {
        Claimed: boolean,
        Options: {RewardOption?},
        Progress: {},
    }
} = {}

local Relics: {Reward} = {}
local Items: {Reward} = {}

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CreateRewardSlot(Slot: CFrame)
    if not SHOW_DETAILS then return end
    Utility:CreateDot(Slot, Vector3.new(1, 1, 1), Enum.PartType.Ball, Color3.fromRGB(50, 255, 50), nil)
end

local function IsClose(A: CFrame, B: CFrame): boolean
    if (A.Position - B.Position).Magnitude > 0.1 then return false end
    return true
end

local function SetupRewardLists()
    -- Add relics
    for Name, Data in RelicInfo do
        table.insert(Relics, {Name = Name, Rarity = 1})
    end
    table.sort(Relics, function(A, B)
        return A.Rarity < B.Rarity
    end)

    -- Add items
    for Name, Data in ItemInfo do
        table.insert(Items, {Name = Name, Rarity = 1})
    end
    table.sort(Items, function(A, B)
        return A.Rarity < B.Rarity
    end)

    warn(Relics)
    warn(Items)
end

local function RequestPickupReward(Player: Player, RewardID: number, RewardType: string, RewardName: string, CF: CFrame): (number, number?)
    if not Player then return CustomEnum.ReturnCodes.ComplexError, 1 end
    local PRewards = PlayerRewards[Player]
    if not PRewards then return CustomEnum.ReturnCodes.ComplexError, 2 end
    if PRewards.Claimed then return CustomEnum.ReturnCodes.ComplexError, 3 end

    -- Player has no options right now
    if #PRewards.Options <= 0 then
        return CustomEnum.ReturnCodes.ComplexError, 4
    end

    -- See if any of the current reward options match all the parameters
    for _, Option in PRewards.Options do
        if not Option then continue end
        if Option.RewardID ~= RewardID or Option.RewardType ~= RewardType or Option.RewardName ~= RewardName or not IsClose(Option.CF, CF) then continue end
        PRewards.Claimed = true

        if RewardType == "Relic" then
            RelicService.RequestPickupRelic(Player, RewardName)
            
        elseif RewardType == "Item" then
            ItemService.RequestPickupItem(Player, RewardName)
        end
            
        table.clear(PRewards.Options)
        Remotes.RewardService.CleanupRewards:Fire(Player)

        return 1
    end

    return CustomEnum.ReturnCodes.ComplexError, 5
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Converts a reward block into a set of slot cframes; these slots are where the rewards are placed
function RewardService.GetRewardSlots(Block: BasePart): {CFrame}
    local List: {CFrame} = {}

    --[[if #ServerGlobalValue.LevelPlayers <= 1 then
        -- For a single player, put the slot at the center of it

        local Slot = Block.CFrame * CFrame.new(0, 3, 0)
        CreateRewardSlot(Slot)
        table.insert(List, Slot)

    else
        -- For multiple players, make a circle of slots
        for x = 0, CIRCLE - (CIRCLE / 2), CIRCLE / #ServerGlobalValue.LevelPlayers do
            local Slot = Block.CFrame * CFrame.new(4 * math.cos(x), 3, 4 * math.sin(x))
            table.insert(List, Slot)
            
            CreateRewardSlot(Slot)
        end
   -- end]]

   table.insert(List, Block.CFrame * CFrame.new(-4, 3, 0)) -- Left
   table.insert(List, Block.CFrame * CFrame.new(4, 3, 0)) -- Right
   table.insert(List, Block.CFrame * CFrame.new(0, 3, 0)) -- Middle

    Block:Destroy()
    return List
end

function RewardService.SpawnRewardsForAll(RewardTypes: {{Choice: LevelEnum.RewardType, Chance: number}}, Slots: {CFrame})
    local ChosenType = Utility.RollPick(RewardTypes) :: LevelEnum.RewardType
    local ThisList

    -- Decide which reward pool to use
    if ChosenType == "Relic" then
        ThisList = Relics
    
    elseif ChosenType == "Item" then
        ThisList = Items
    end
    
    for _, Player in Players:GetPlayers() do
        if not Player then continue end
        local TotalRewards = DataService.GetMaxRewards(Player)
        if not TotalRewards then continue end

        local PRewards = PlayerRewards[Player]
        if not PRewards then continue end

        PRewards.Claimed = false

        local Options = {}
        local IndexList = {}

        -- Put total amount as indexes in an array
        for x = 1, #ThisList do
            table.insert(IndexList, x)
        end

        -- Pick a rand index available and put as an option
        for x = 1, TotalRewards do
            local RandIndex = RNG:NextInteger(1, #IndexList)
            table.insert(Options, IndexList[RandIndex])
            table.remove(IndexList, RandIndex)
        end

        warn(Options)

        -- Spawn the rewards for the player
        for n, Index in ipairs(Options) do
            local RewardID = n
            local RewardName = ThisList[Index].Name
            local CF = Slots[n]

            table.insert(PRewards.Options, {RewardID = RewardID, RewardType = ChosenType, RewardName = RewardName, CF = CF})
            Remotes.RewardService.SpawnReward:Fire(Player, RewardID, ChosenType, RewardName, CF)
        end
    end
end

function RewardService.CleanupRewardsForAll()
    for _, Player in Players:GetPlayers() do
        if not Player then continue end
        local PRewards = PlayerRewards[Player]
        if not PRewards then continue end

        table.clear(PRewards.Options)
        Remotes.RewardService.CleanupRewards:Fire(Player)
        PRewards.Claimed = false
    end
end

function RewardService:Init()
    -- Spawns the reward for the client
    -- RewardID: number, RewardType: string, RewardName: string, CF: CFrame
    Remotes:CreateToClient("SpawnReward", {"number", "string", "string", "CFrame"})
    
    Remotes:CreateToClient("CleanupRewards", {})

    -- The client can request to pick up a reward from the ground
    Remotes:CreateToServer("RequestPickupReward", {"number", "string", "string", "CFrame"}, "Returns",  function(Player: Player, RewardID: number, RewardType: LevelEnum.RewardType, RewardName: string, CF: CFrame)
        return RequestPickupReward(Player, RewardID, RewardType, RewardName, CF)
    end)
end

function RewardService:Deferred()
    SetupRewardLists()
end

function RewardService.PlayerAdded(Player: Player)
    if PlayerRewards[Player] then return end

    PlayerRewards[Player] = {
        Claimed = false,
        Options = {},
        Progress = {},
    }
end

function RewardService.PlayerRemoving(Player: Player)

end

return RewardService