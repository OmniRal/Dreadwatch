-- OmniRal

local RelicService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local AbilityService = require(ServerScriptService.Source.ServerModules.General.AbilityService)
local UnitValuesService = require(ServerScriptService.Source.ServerModules.General.UnitValuesService)

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)
local RelicInfo = require(ReplicatedStorage.Source.SharedModules.Info.RelicInfo)

local RelicModules = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerRelics: {
    [Player]: {
        {Name: string, Last: string, Cooldown: number, Connection: RBXScriptConnection?}
    }
} = {}

local Events = ServerStorage.Events

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RelicService:UpdatePlayerAttributes(Player: Player)
    local CurrentRelics = DataService:GetPlayerRelics(Player)

end

function RelicService:EquipRelic(Player: Player, SlotNum: number, RelicName: string)
    local P_Relics, Info = PlayerRelics[Player], RelicInfo[RelicName]
    if not P_Relics or not Info then return end

    Remotes.RelicService.Equipped:Fire(Player, RelicName)
    P_Relics[SlotNum].Last = P_Relics[SlotNum].Name
    P_Relics[SlotNum].Name = RelicName

    local Connection = PlayerRelics[Player][SlotNum].Connection
    if Connection then
        Connection:Disconnect()
        P_Relics[SlotNum].Connection = nil
    end

    if not Info.Ability then return end
    
    AbilityService:AddNew(Player, RelicName, {[Info.Ability.Type] = {Equipped = true, BaseCooldown = Info.Ability.Cooldown}})

    if Info.Ability.Type == "Passive" then
        local Module = RelicModules[RelicName]
        if not Module then return end

        P_Relics[SlotNum].Connection = Events.Unit.NewHistoryEntry.Event:Connect(function(Unit: Player, Entry: UnitEnum.HistoryEntry)
            if P_Relics[SlotNum].Name ~= RelicName then return end
            if not Unit or not Entry or not Module then return end
            if not Unit:IsA("Player") then return end
            Module:UsePassive(Player, Entry)
        end)
    end
end

function RelicService:UnequipRelic(Player: Player, RelicName: string)
    Remotes.RelicService.Unequipped:Fire(Player, RelicName)
end

function RelicService:UseActive(Player: Player, SlotNum: number, ShootFrom: Vector3?, ShootGoal: Vector3?): (number?, number?)
    local Slot = PlayerRelics[Player][SlotNum]
    local Info = RelicInfo[Slot.Name]
    if not Info then return CustomEnum.ReturnCodes.ComplexError, -1 end
    if not Info.Ability then return CustomEnum.ReturnCodes.ComplexError, -2 end
    if Info.Ability.Type == "Passive" then return CustomEnum.ReturnCodes.ComplexError, -3 end
    
    local Module = RelicModules[Slot.Name]
    return Module:UseActive(Player, ShootFrom, ShootGoal)
end

function RelicService:Init()
    Remotes:CreateToClient("Equipped", {"string"}, "Reliable")
    Remotes:CreateToClient("Unequipped", {"string"}, "Reliable")
    Remotes:CreateToClient("RelicSlotsUpdated", {"table"}, "Reliable")

    Remotes:CreateToServer("UseActive", {"number", "Vector3?", "Vector3?"}, "Returns", function(Player: Player, SlotNum: number, ShootFrom: Vector3?, ShootGoal: Vector3?)
        return RelicService:UseActive(Player, SlotNum, ShootFrom, ShootGoal)
    end)

    for _, Module in ServerScriptService.Source.ServerModules.Relics:GetChildren() do
        if Module.Name == "RelicService" then continue end
        RelicModules[string.sub(Module.Name, 1, string.len(Module.Name) - 7)] = require(Module) 
    end

	print("RelicService initialized...")
end

function RelicService:Deferred()
    print("RelicService deferred...")
end

function RelicService.PlayerAdded(Player: Player)
    local CurrentRelics = DataService:GetPlayerRelics(Player)

    PlayerRelics[Player] = {
        {Name = CurrentRelics[1], Last = CurrentRelics[1], Cooldown = 0},
        {Name = CurrentRelics[2], Last = CurrentRelics[2], Cooldown = 0},
        {Name = CurrentRelics[3], Last = CurrentRelics[3], Cooldown = 0},
        {Name = CurrentRelics[4], Last = CurrentRelics[4], Cooldown = 0},
        {Name = CurrentRelics[5], Last = CurrentRelics[5], Cooldown = 0},
        {Name = CurrentRelics[6], Last = CurrentRelics[6], Cooldown = 0},
    }

    task.delay(1, function()
        for x = 1, 3 do
            local Slot = PlayerRelics[Player][x]
            if Slot.Name == "None" then continue end

            local Info = RelicInfo[Slot.Name]
            local EffectDetails: UnitEnum.EffectDetails = {
                Name = Info.Name,
                From = Info.Name,
                Description = Info.Description,
                IsBuff = true,
                Icon = Info.Icon,
                Duration = -1,
                MaxStacks = Info.MaxStacks or 1,
                DoNotDisplay = true,
            }

            UnitValuesService:AddEffect(Player, EffectDetails, Info.Attributes, {})
            RelicService:EquipRelic(Player, x, Info.Name)
        end
    
        UnitValuesService:GetAttributes(Player)

        local CurrentRelics = DataService:GetPlayerRelics(Player)
        if not CurrentRelics then return end
        Remotes.RelicService.RelicSlotsUpdated:Fire(Player, CurrentRelics)
    end)

end

return RelicService