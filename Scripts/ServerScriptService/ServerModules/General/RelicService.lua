-- OmniRal

local RelicService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)
local RelicInfo = require(ReplicatedStorage.Source.SharedModules.Info.RelicInfo)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local UnitValuesService = require(ServerScriptService.Source.ServerModules.General.UnitValuesService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerRelics: {
    [Player]: {
        {Name: string, Last: string, Cooldown: number}
    }
} = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RelicService:UpdatePlayerAttributes(Player: Player)
    local CurrentRelics = DataService:GetPlayerRelics(Player)

end

function RelicService:Init()
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
            local Data = PlayerRelics[Player][x]
            if Data.Name == "None" then continue end

            local Info = RelicInfo[Data.Name]
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

            print(Info)

            UnitValuesService:AddEffect(Player, EffectDetails, Info.Attributes, {})
        end
    
        UnitValuesService:GetAttributes(Player)
    end)

end

return RelicService