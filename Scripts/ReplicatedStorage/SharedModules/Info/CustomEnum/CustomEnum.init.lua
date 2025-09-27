-- OmniRal

--Enathri was here ^-^

local CustomEnum = {}

export type Currency = "None" | "Gold" | "Robux"

export type UnlockedBy = "Default" | "Coins" | "Robux" | "Other"

export type AttackType = "Melee" | "Ranged"
export type DamageType = "Physical" | "Magical" | "Pure"
export type AbilityType = "Active" | "Passive"

CustomEnum.RayType = {
    LineRaycast = "LineRaycast",
    BlockRaycast = "BlockRaycast",
}

CustomEnum.TextDisplayType = {
    HealthGain = "HealthGain",
    KillerDamage = "KillerDamage",
    VictimDamage = "VictimDamage",
    AttackMiss = "AttackMiss",
    Miss = "Miss",
    Evade = "Evade",
    Crit = "Crit",
}

CustomEnum.HistoryEntryType = {
    Damage = "Damage",
    HealthGain = "HealthGain",
}

export type Product = {
    Type: "Coins" | "Toy",
    Name: string,
    Detail: number | string?
}

export type Ability = {
    Name: string,
    DisplayName: string,
    Description: string,
    FlavorText: string,
    Icon: number,

    Type: AbilityType,
    Damage: NumberRange,
    Cooldown: number,

    Details: {}?
}

return CustomEnum