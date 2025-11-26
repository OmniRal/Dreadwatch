--!nocheck

local DataService = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local ServerScriptService = game:GetService('ServerScriptService')
local MarketplaceService = game:GetService("MarketplaceService")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local ProfileService = require(ServerScriptService.Source.ProfileService)

local ProductInfo = require(ReplicatedStorage.Source.SharedModules.Info.ProductInfo)
local ShopInfo = require(ReplicatedStorage.Source.SharedModules.Info.ShopInfo)
local BadgeInfo = require(ReplicatedStorage.Source.SharedModules.Info.BadgeInfo)
local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo)

local RelicEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.RelicEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DataService.ProfileReady = false
DataService.ServiceReady = false

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ProfileTemplate = {
	LogInTimes = 0,
	LoggedInDuration = 0,
	LastLoggedIn = 0,

    Stats = {
        TimePlayed = {Seconds = 0, Minutes = 0, Hours = 0, Days = 0},
        Weapons = {},
    },

    Level = 1,
    XP = 0,

    Quests = {
        Current = {},
        Completed = {},
    },
    
    Badges = {},

    Weapons = {},
    Relics = {},
    Items = {},

    CurrentWeapon = "BasicSword",
    CurrentWeaponSkin = "Default",
    CurrentWeaponAbility = "Innate",

    CurrentRelics = {
        [1] = "None",
        [2] = "None",
        [3] = "None",
    },

    CurrentItems = {
        [1] = "None",
        [2] = "None",
        [3] = "None",
        [4] = "None",
        [5] = "None",
        [6] = "None",
    },

    MaxRevives = 0,
}

local ProfileStore = ProfileService.GetProfileStore('OmniBlot_Hunters_Alpha_33', ProfileTemplate)

local Profiles = {}

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

function PlayerAdded(Player)
    while not DataService.ProfileReady or not DataService.ServiceReady do
        task.wait()
    end

	Player:SetAttribute("Joined", os.time())

	local profile = ProfileStore:LoadProfileAsync("Player_" .. Player.UserId)
    print("Loaded profile : ", profile)
    if profile ~= nil then
        profile:AddUserId(Player.UserId) -- GDPR compliance
        profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
        --print("R: ", profile)
        profile:ListenToRelease(function()
            Profiles[Player] = nil
            -- The profile could"ve been loaded on another Roblox server:
            Player:Kick("Could not load player data (1)")
        end)

        if Player:IsDescendantOf(Players) == true then
            Profiles[Player] = profile
            -- A profile has been successfully loaded:
			profile.Data.LogInTimes += 1
			profile.Data.LastLoggedIn = os.time()

			Player:SetAttribute("DataLoaded", true)
            Remotes.DataService.DataUpdate:Fire(Player, Profiles[Player].Data)
        else
            -- Player left before the profile loaded:
            profile:Release()
        end
    else
        -- The profile couldn"t be loaded possibly due to other
        --   Roblox servers trying to load this profile at the same time:
        Player:Kick("Could not load player data (2)")
    end
end

function PlayerRemoving(Player)
    task.wait(0.25)
	local profile = Profiles[Player]
    if profile ~= nil then
		profile.Data.LoggedInDuration += os.time() - Player:GetAttribute("Joined")
        profile:Release()
    end
end

--[[function DataService.Client:GetIndex(...)
	return DataService:GetIndex(...)
end]]

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function DataService:GetProfileTable(Player: Player)
    while not self.ServiceReady do
        task.wait()
    end
    while Profiles[Player] == nil do
        task.wait()
    end
    return Profiles[Player].Data
end

function DataService:GetIndex(Player, Index)
	self:WaitForPlayerDataLoaded(Player)
	return Profiles[Player].Data[Index]
end

function DataService:SetIndex(Player: Player, Index: string | {}, Value: string? | number? | boolean? | {}?)
	self:WaitForPlayerDataLoaded(Player)

    if typeof(Index) == "string" then
        Profiles[Player].Data[Index] = Value
    else
        local ThisData = Profiles[Player].Data
        for _, Key in ipairs(Index) do
            ThisData = ThisData[Key]
        end
        ThisData = Value
    end

    Remotes.DataService.DataUpdate:Fire(Player, Profiles[Player].Data)
end

function DataService:SetWeapon(Player: Player, WeaponName: string, SkinName: string?)
    self:WaitForPlayerDataLoaded(Player)
    assert(WeaponInfo[WeaponName] ~= nil, "Trying to set invalid weapon.")
    
    if not SkinName then
        SkinName = "Default"
    end
    assert(WeaponInfo[WeaponName].Skins[SkinName] ~= nil, "Trying to set invalid weapon skin.")

    Profiles[Player].Data.CurrentWeapon = WeaponName
    Profiles[Player].Data.CurrentWeaponSkin = SkinName or "Default"

    Remotes.DataService.DataUpdate:Fire(Player, Profiles[Player].Data)
end

-- Returns the players current weapon, its skin and the ability (innate or awakened) equipped
function DataService:GetPlayerCurrentWeapons(Player: Player): (string, string, string)
    self:WaitForPlayerDataLoaded(Player)

    local PlayerData = Profiles[Player].Data
    return PlayerData.CurrentWeapon, PlayerData.CurrentWeaponSkin, PlayerData.CurrentWeaponAbility
end

-- Set a specific relic slot in the players data
-- @NewMod : The name of the relic, or "None"
-- @DoNotSendSignalToPlayer : If true, it will NOT fire an event to the client, giving them their updated relic slots
function DataService:SetPlayerRelic(Player: Player, SlotNum: number, NewMod: "None" | string, DoNotSendSignalToPlayer: boolean?)
    self:WaitForPlayerDataLoaded(Player)

    if not Profiles[Player].Data.CurrentRelics then return end
    if not Profiles[Player].Data.CurrentRelics[SlotNum] then return end
    Profiles[Player].Data.CurrentRelics[SlotNum] = NewMod

    if DoNotSendSignalToPlayer then return end
    Remotes.RelicService.RelicSlotsUpdated:Fire(Player, Profiles[Player].Data.CurrentRelics)
end

-- Returns an array of the players current equipped relic.
function DataService:GetPlayerRelics(Player: Player): {[number]: string}
    self:WaitForPlayerDataLoaded(Player)

    return Profiles[Player].Data.CurrentRelics
end

-- Checks to see if the players relic slots are all taken
function DataService:ArePlayerRelicsFull(Player: Player): (boolean, number?)
    self:WaitForPlayerDataLoaded(Player)

    local CurrentRelics = Profiles[Player].Data.CurrentRelics

    for x = 1, 3 do
        if CurrentRelics[x] ~= "None" then continue end
        return false, x
    end

    return true
end

-- Returns an array of the players items
function DataService:GetPlayerItems(Player: Player): {[number]: string}
    self:WaitForPlayerDataLoaded(Player)

    return Profiles[Player].Data.CurrentItems
end

-- Set a players item slot to a specific items
function DataService:SetItem(Player: Player, SlotNum: number, ItemName: "None" | string)
    self:WaitForPlayerDataLoaded(Player)

    local PlayerData = Profiles[Player].Data
    PlayerData.CurrentItems[SlotNum] = ItemName
    Remotes.ItemService.ItemSlotsUpdated:Fire(Player, PlayerData.CurrentItems)
end

-- Swaps the item from one slot to another in the players data
function DataService:SwapItems(Player: Player, SlotNum_A: number, SlotNum_B: number): boolean?
    self:WaitForPlayerDataLoaded(Player)

    local PlayerData = Profiles[Player].Data
    local From_Relic = PlayerData.CurrentItems[SlotNum_A]
    local To_Relic = PlayerData.CurrentItems[SlotNum_B]
    
    PlayerData.CurrentItems[SlotNum_A] = To_Relic
    PlayerData.CurrentItems[SlotNum_B] = From_Relic

    Remotes.ItemService.ItemSlotsUpdated:Fire(Player, PlayerData.CurrentItems)

    return true
end

-- Checks to see if the players item slots are all taken
function DataService:AreItemSlotsFull(Player: Player): (boolean, number?)
    self:WaitForPlayerDataLoaded(Player)

    local CurrentRelics = Profiles[Player].Data.CurrentRelics

    for x = 1, 6 do
        if CurrentRelics[x] ~= "None" then continue end
        return false, x
    end

    return true
end

function DataService:IncrementIndex(Player, Index, Increment)
	self:WaitForPlayerDataLoaded(Player)
	Profiles[Player].Data[Index] += Increment
    Remotes.DataService.DataUpdate:Fire(Player, Profiles[Player].Data)
end

function DataService:WaitForPlayerDataLoaded(Player)
	if not Player:GetAttribute("DataLoaded") then
		Player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
end

function DataService:Init()
    print("Data Service Init...")

    Remotes:CreateToClient("DataUpdate", {"table"}, "Reliable")

    for WeaponName, W_Info in pairs(WeaponInfo) do
        local WeaponUnlocked = false
        if W_Info.UnlockedBy == "Default" then
            WeaponUnlocked = true
        end 

        local Skins = {}
        for SkinName, S_Info in pairs(W_Info.Skins) do
            local SkinUnlocked = false
            if S_Info.UnlockedBy == "Default" then
                SkinUnlocked = true
            end
            Skins[SkinName] = {Unlocked = SkinUnlocked, Date = "2023:" .. RNG:NextInteger(1, 12) .. ":30:" .. RNG:NextInteger(1, 23) .. ":00", IsNew = true}
        end

        ProfileTemplate.Weapons[WeaponName] = {Unlocked = WeaponUnlocked, Date = "2024:" .. RNG:NextInteger(1, 12) .. ":30:" .. RNG:NextInteger(1, 23) .. ":00", IsNew = true, Skins = Skins, EquippedSuit = "Default"}

        ProfileTemplate.Stats.Weapons[WeaponName] = {
            TimePlayed = {Seconds = 0, Minutes = 0, Hours = 0, Days = 0},
            Kills = 0,
            Assists = 0,
        }
    end

    self.ProfileReady = true

    ------------------------------------------------------------------------------------------------------------------

    print("Template Ready : ", ProfileTemplate)
end

function DataService:Deferred()
    print("Data Service Deferred...")
    self.ServiceReady = true
end

function DataService.PlayerAdded(Player: Player)
    task.spawn(function()
        PlayerAdded(Player)
    end)
end

function DataService.PlayerRemoving(Player: Player)
    task.spawn(function()
        PlayerRemoving(Player)
    end)
end

return DataService
