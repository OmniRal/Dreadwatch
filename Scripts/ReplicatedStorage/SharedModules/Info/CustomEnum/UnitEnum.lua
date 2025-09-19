-- OmniRal

local UnitEnum = {}

UnitEnum.BaseAttributeLimits = {
    Health = NumberRange.new(0, math.huge),
    Mana = NumberRange.new(0, math.huge),
}

export type UnitValues = {
    Base: BaseAttributes,
    Offsets: BaseAttributes,
    States: BaseStates,

    Effects: {},
    History: {},
    Folder: Configuration?,
}

export type BaseAttributes = {
    Health: number?,
    HealthGain: number?,

    Mana: number?,
    ManaGain: number?,

    Armor: number?,
    WalkSpeed: number?, 
    AttackSpeed: number?,
    CritPercent: number?,
    CritChance: number?,
    Damage: number?,
}

export type BaseStates = {
    Immune: boolean?,
    Silenced: boolean?,
    Disarmed: boolean?,
    Break: boolean?,
    Rooted: boolean?,
    Stunned: boolean?,
    Tracked: boolean?,
    Panic: {Active: boolean, From: Vector3?}?,
    Taunt: {Active: boolean, Goal: Vector3? | BasePart?}?,
}

export type Effect = {
    From: Player | Model | string,
    IsBuff: boolean,
    Name: string,
    Icon: number?,
    Description: string?,

    SpawnTime: number,
    Duration: number,
    MaxStacks: number,
    NumberStack: boolean?,
    Amount: number?,
    
    Offsets: BaseAttributes?,

    States: BaseStates?,

    CleanFunction: () -> (),
    CleanDelay: thread,

    Config: Configuration?,
}

export type EffectDetails = {
    Name: string, 
    From: Player | Model | string,
    Description: string?, 
    IsBuff: boolean, 
    Icon: number?, 
    Duration: number, 
    MaxStacks: number,
    DoNotDisplay: boolean?,
}

export type HistoryEntry = {
    Source: string?,
    
    Name: string,
    Type: string,
    Amount: number,
    TimeAdded: number?,
    CleanTime: number?,
}

return UnitEnum