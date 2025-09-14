-- OmniRal

local WeaponEnum = {}

local CustomEnum = require(script.Parent)

export type WeaponUseType = "Single" | "Auto"
export type WeaponStyle = "Melee" | "Ranged"

export type WeaponAbility = {
    Name: string,
    DisplayName: string,
    Description: string,
    FlavorText: string,
    Icon: number,

    Damage: NumberRange,
}

export type Weapon = {
    UnlockedBy: CustomEnum.UnlockedBy,
    Cost: number,

    DisplayName: string,
    Description: string,
    FlavorText: string,
    Icon: number,
    
    UseType: WeaponUseType,
    Style: WeaponStyle,

    MeleeData: {
        CanComboChain: boolean?,
        ComboAmount: number?,
    }?,

    RangedData: {
        Reload: boolean?,
        MaxAmmo: number,
    }?,

    Damage: NumberRange,

    Abilities: {
        Innate: WeaponAbility,
        Grand: WeaponAbility,
    },

    BaseAnimations: {
        ["idle"]: number?,
        ["walk"]: number?,
        ["run"]: number?,
        ["jump"]: number?,
        ["fall"]: number?,
    }?,
    
    HoldingAnimations: {[string]: number | {[string]: {ID: number, Priority: Enum.AnimationPriority}}?}?,
    ModelAnimations: {[string]: number | {[string]: {ID: number, Priority: Enum.AnimationPriority}}?}?,

    Skins: {[string]: {UnlockedBy: CustomEnum.UnlockedBy, Cost: number}},
}

return WeaponEnum