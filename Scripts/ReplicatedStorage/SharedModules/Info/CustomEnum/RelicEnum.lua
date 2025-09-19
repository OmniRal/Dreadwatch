-- OmniRal

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)

local RelicEnum = {}



export type Relic = {
    Name: string,
    DisplayName: string,
    Description: string,
    FlavorText: string,
    Icon: number,

    Attributes: UnitEnum.BaseAttributes,
    
    Ability: CustomEnum.Ability?,
    MaxStacks: number?,
}

return RelicEnum