-- OmniRal

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModStoneEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.ModStoneEnum)

local ModStonesInfo: {[string]: ModStoneEnum.ModStone} = {}

ModStonesInfo.Echo = {
    Name = "Echo",
    Description = "",
    FlavorText = "",
    Icon = 77310075815750,

    StoneColor = Color3.fromRGB(255, 39, 133),
}

ModStonesInfo.Blast = {
    Name = "Blast",
    Description = "",
    FlavorText = "",
    Icon = 123228184913688,

    StoneColor = Color3.fromRGB(255, 118, 39)
}

return ModStonesInfo