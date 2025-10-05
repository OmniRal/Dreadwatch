-- OmniRal

local AbilityService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)
local UnitValuesService = require(ServerScriptService.Source.ServerModules.General.UnitValuesService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerAbilities: {
    [Player]: {
        [string]: { -- Source; such as a Weapon (BasicSword) or a Relic (Amplifier)
            [string]: { -- Ability name
                Equipped: boolean, -- If that ability is equipped
                BaseCooldown: number, -- What the cooldown is of that ability
                TimeAvailable: number, -- When the ability can be used again
            },
        }
    }
} = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Checks if any ability is equipped
local function AbilityEquipped(Player: Player, Source: string, AbilityName: string): boolean?
    local Data = PlayerAbilities[Player]
    if not Data then return end
    if not Data[Source] then return end
    if not Data[Source][AbilityName] then return end
    if not Data[Source][AbilityName].Equipped then return end

    return true
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Checks if an ability is on cooldown
function AbilityService:OnCooldown(Player: Player, Source: string, AbilityName: string): boolean | string
    local Data = PlayerAbilities[Player]
    if not AbilityEquipped(Player, Source, AbilityName) then return "NotEquipped" end
    
    return os.time() < Data[Source][AbilityName].TimeAvailable
end

-- Sets the cooldown of the ability
function AbilityService:SetCooldown(Player: Player, Source: string, AbilityName: string)
    local Data = PlayerAbilities[Player]
    if not AbilityEquipped(Player, Source, AbilityName) then return end
    
    local Ability = Data[Source][AbilityName]
    local CooldownReduction = UnitValuesService:GetAttributes(Player, "CooldownReduction") or 0
    local Limits = UnitEnum.BaseAttributeLimits.CooldownReduction

    -- Taking into account the base cooldown of that ability and how much cooldown reduction the player has from relics, items, etc
    local TotalCooldown = Ability.BaseCooldown - (Ability.BaseCooldown * (math.clamp(CooldownReduction, Limits.Min, Limits.Max) / 100))

    Ability.TimeAvailable = os.time() + TotalCooldown
end


-- Add a new abilities under the players list to keep track of
-- Refer to PlayerAbilities at the top
-- @Source = Either a weapon, relic, or something
-- @Abilities = A list with the relevant data for that ability
function AbilityService:AddNew(
    Player: Player,
    Source: string, 
    Abilities: {
        [string]: {
            Equipped: boolean,
            BaseCooldown: number,
        }
    }
)

    local Data = PlayerAbilities[Player]
    if not Data then return end
    if Data[Source] then return end

    Data[Source] = {}

    for Name, Info in Abilities do
        Data[Source][Name] = {}
        Data[Source][Name].Equipped = Info.Equipped
        Data[Source][Name].BaseCooldown = Info.BaseCooldown
        Data[Source][Name].TimeAvailable = os.time()
    end
end

function AbilityService:Init()
	print("AbilityService initialized...")
end

function AbilityService:Deferred()
    print("AbilityService deferred...")
end

function AbilityService.PlayerAdded(Player: Player)
    PlayerAbilities[Player] = {}
end

function AbilityService.PlayerRemoving(Player: Player)
    if not PlayerAbilities[Player] then return end
    PlayerAbilities[Player] = nil
end

return AbilityService