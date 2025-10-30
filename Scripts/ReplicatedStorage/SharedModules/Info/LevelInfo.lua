-- OmniRal

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Levelinfo: {[string]: LevelEnum.Level} = {}

Levelinfo.Mission_1 = {
    Name = "They Crawl Within",
    Chunks = {
        {
            Biome = "Forest", 
            Amount_Rooms = NumberRange.new(1, 1), 
            Amount_Choices = NumberRange.new(2, 2), 
            TitleCard = "The Forest"
        },

        {
            Biome = "Forest", 
            Amount_Rooms = NumberRange.new(2, 3), 
            Amount_Choices = NumberRange.new(1, 3), 
        },

        { -- Transition
            Biome = "Forest", 
            Amount_Rooms = NumberRange.new(1, 1), 
            Amount_Choices = NumberRange.new(1, 1),
            SpecificRooms = {"Transition_Room"} -- Use this specific room for this chunk
        },

        { 
            Biome = "Town", 
            Amount_Rooms = NumberRange.new(2, 4), 
            Amount_Choices = NumberRange.new(2, 3),
        },
    },

    Description = "They do",
    Difficulty = "1",
}

return Levelinfo
