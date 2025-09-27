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
    },

    Ability = {
        Name = "Test Passive",
        DisplayName = "Test Passive Display",
        Description = "Test Passive Description",
        FlavorText = "Test Passive Flavor Test",
        Icon = 0,

        Type = "Passive",
        Damage = NumberRange.new(0, 0),
        Cooldown = 3,

        Details = {},
    }
}

RelicInfo.Dingus = {
    Name = "Dingus",
    DisplayName = "Dingus",
    Description = "Dingus",
    FlavorText = "Dingus",
    Icon = 0,
    
    Attributes = {
        Damage = 0
    },

    Ability = {
        Name = "Test Active",
        DisplayName = "Test Active Display",
        Description = "Test Active Description",
        FlavorText = "Test Active Flavor Text",
        Icon = 0,

        Type = "Active",
        Damage = NumberRange.new(10, 10),
        Cooldown = 5,

        Details = {},
    }
}

return RelicInfo