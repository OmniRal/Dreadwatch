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
    Config: Configuration?,
}

export type BaseAttributes = {
    Health: number,
    HealthGain: number,

    Mana: number,
    ManaGain: number,
}

export type BaseStates = {
    Stunned: boolean,
}

export type Effect = {
    From: Player | Model | string,
    IsBuff: boolean,
    Name: string,
    Description: string?,
    Icon: number?,

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
    Icon: string?, 
    Duration: number, 
    MaxStacks: number,
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