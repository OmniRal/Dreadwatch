-- OmniRal

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.RelicEnum)

local RelicInfo: {
    [string]: RelicEnum.Relic
} = {}

RelicInfo.Chungus = {
    Name = "Chungus",
    DisplayName = "Chungus",
    Description = "Chungus",
    FlavorText = "Chungus",
    Icon = 0,

    Attributes = {
        Health = 25,
        Mana = 10,
    }
}

RelicInfo.Dingus = {
    Name = "Dingus",
    DisplayName = "Dingus",
    Description = "Dingus",
    FlavorText = "Dingus",
    Icon = 0,
    
    Attributes = {
        Damage = 10
    }
}

return RelicInfo