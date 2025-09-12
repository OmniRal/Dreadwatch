-- OmniRal

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

export type WeaponType = "Primary" | "Utility" | "Melee"

export type WeaponUseType = "Single" | "Auto"

export type Weapon = {
    UnlockedBy: CustomEnum.UnlockedBy,
    Cost: number,

    DisplayName: string,
    Description: string,
    FlavorText: string,
    Icon: number,
    
    Type: WeaponType,
    UseType: WeaponUseType,
    Reload: boolean?,

    UseRate: number,
    ReloadTime: number,
    MaxMags: number?,
    MaxClips: number?,

    Damage: NumberRange,

    HoldingAnimations: {[string]: number | {[string]: {ID: number, Priority: Enum.AnimationPriority}}?}?,
    ModelAnimations: {[string]: number | {[string]: {ID: number, Priority: Enum.AnimationPriority}}?}?,

    Skins: {[string]: {UnlockedBy: CustomEnum.UnlockedBy, Cost: number}},
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local WeaponInfo: {[string]: Weapon} = {}

WeaponInfo.Cruncher = {
    DisplayName = "Cruncher",
    Description = "Grinds bolts, metals and various other debris to use as fire power!",
    FlavorText = "They won't know what hit 'em! Literally.",
    Icon = 136509376539536,

    Type = "Primary",
    UseType = "Auto",
    Reload = true,

    ReloadTime = 2,
    UseRate = 0.25,
    MaxClips = 30,
    MaxMags = 3,

    Damage = NumberRange.new(1, 1),

    HoldingAnimations = {
        Base = {
            ["Idle"] = {ID = 70991446529659, Priority = Enum.AnimationPriority.Action}
        }, 
        Using = {
            ["StartFire"] = {ID = 111271078408107, Priority = Enum.AnimationPriority.Action2}, 
            ["Firing"] = {ID = 105064106391976, Priority = Enum.AnimationPriority.Action2},
            ["StopFire"] = {ID = 76608737715824, Priority = Enum.AnimationPriority.Action2},
            ["Reloading"] = {ID = 93639917370633, Priority = Enum.AnimationPriority.Action3},
        }},
    ModelAnimations = {
        Base = {
            ["Grinding"] = {ID = 87569697764574, Priority = Enum.AnimationPriority.Idle},
        },
        Using = {
            ["Reloading"] = {ID = 73447210844421, Priority = Enum.AnimationPriority.Action},
        }
    },

    UnlockedBy = "Default",
    Cost = 0,

    Skins = {
        ["Default"] = {UnlockedBy = "Default", Cost = 0},
        ["Greenmark"] = {UnlockedBy = "Default", Cost = 0}
    },
}

WeaponInfo.Rusty = {
    DisplayName = "Rusty",
    Description = "",
    FlavorText = "",
    Icon = 101320814584009,

    Type = "Melee",
    UseType = "Single",

    ReloadTime = 0,
    UseRate = 0.25,
    MaxClips = -2,
    MaxMags = -2,

    Damage = NumberRange.new(1, 1),

    HoldingAnimations = {
        Base = {
            ["Idle"] = {ID = 125915672325737, Priority = Enum.AnimationPriority.Action}
        }, 
        Using = {
            ["Swing1"] = {ID = 117025060129870, Priority = Enum.AnimationPriority.Action2}, 
            ["Swing2"] = {ID = 102691627815800, Priority = Enum.AnimationPriority.Action2},
            ["Swing1B"] = {ID = 96544824870356, Priority = Enum.AnimationPriority.Action2},
        }
    },
    ModelAnimations = {},

    UnlockedBy = "Default",
    Cost = 0,

    Skins = {
        ["Default"] = {UnlockedBy = "Default", Cost = 0},
        ["Mannys"] = {UnlockedBy = "Default", Cost = 0}
    },
}

WeaponInfo.Brighton = {
    UnlockedBy = "Default",
    Cost = 0,

    DisplayName = "Brighton",
    Description = "Description",
    FlavorText = "Flavor text",
    Icon = 10,

    Type = "Primary",
    UseType = "Auto",
    Reload = true,
    
    UseRate = 0.1,
    ReloadTime = 1,
    MaxMags = 20,
    MaxClips = 100,

    Damage = NumberRange.new(3, 4),

    HoldingAnimations = {
        Base = {
            ["Idle"] = {ID = 77779427517639, Priority = Enum.AnimationPriority.Action},
            ["StillIdle"] = {ID = 88035369296667, Priority = Enum.AnimationPriority.Action}
            
        }, 
        Using = {
            ["StartFire"] = {ID = 124955372594934, Priority = Enum.AnimationPriority.Action2}, 
            ["Firing"] = {ID = 79319678215722, Priority = Enum.AnimationPriority.Action2},
            ["StopFire"] = {ID = 122545310874552, Priority = Enum.AnimationPriority.Action2},
            ["Reloading"] = {ID = 111652523060184, Priority = Enum.AnimationPriority.Action3}, -- GrabMag, PullMag, ThrowMag, CheckPocket, NewMag, InsertMag
        }},
    ModelAnimations = {
        Base = {
            --["Grinding"] = {ID = 87569697764574, Priority = Enum.AnimationPriority.Idle},
        },
        Using = {
            ["Reloading"] = {ID = 139007808851580, Priority = Enum.AnimationPriority.Action},
        }
    },

    Skins = {
        ["Default"] = {UnlockedBy = "Default", Cost = 0},
    },
}

return WeaponInfo