-- OmniRal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)
local LevelService = require(ServerScriptService.Source.ServerModules.General.LevelService)

local Level_1: LevelEnum.LevelModule = {}

Level_1["Chunk_1"] = {
    SystemType = "Chunk",
    ID = 1,
    CompletionRequirements = {
        Rooms = {3}
    },

    Methods = {
        Init = function(Chunk)
            for _, ThisRoom: LevelEnum.Room in (Chunk :: LevelEnum.Chunk).Rooms do
                if not ThisRoom.Build then continue end
                for _, Floor in ThisRoom.FloorParts do
                    Floor.Color = Color3.fromRGB(78, 101, 146)
                end
            end
        end,

        Update = function(Chunk)
            
        end
    },
}

Level_1["Chunk_2"] = {
    SystemType = "Chunk",
    ID = 1,
    CompletionRequirements = {
        Rooms = {}
    },

    Methods = {},
}

Level_1["Chunk_3"] = {
    SystemType = "Chunk",
    ID = 1,
    CompletionRequirements = {
        Rooms = {}
    },

    Methods = {},
}

Level_1["Chunk_4"] = {
    SystemType = "Chunk",
    ID = 1,
    CompletionRequirements = {
        Rooms = {}
    },

    Methods = {},
}

Level_1["Room_2"] = {
    SystemType = "Room",
    ID = 2,
    CompletionRequirements = {SolvePuzzles = true},

    AllPlayersRequiredToStart = true,
    RoomBlockedOutUntilComplete = true,

    Methods = {
        Init = function(Room)
            if not Room.Build then return end

            local Button: BasePart = Room.Build:FindFirstChild("CompleteButton")
            if not Button then return end

            local Debounce = false

            Button.Touched:Connect(function(Hit: BasePart)  
                if Debounce then return end
                if not Hit then return end
                if not Hit.Parent then return end
                if not Players:FindFirstChild(Hit.Parent.Name) then return end
                Debounce = true

                Room.PuzzlesSolved = true

                Button.Color = Color3.fromRGB(0, 0, 0)
            end)
        end,

        StartRoom = function(Room)
            for _, Floor in Room.FloorParts do
                Floor.Color = Color3.fromRGB(116, 33, 76)
            end
        end
    }
}

Level_1["Room_3"] = {
    SystemType = "Room",
    ID = 3,
    CompletionRequirements = {ClearWaves = true},
    
    AllPlayersRequiredToStart = true,
    RoomBlockedOutUntilComplete = true,
    
    Waves = {
        {
            {SpawnerIDs = {1, 2}, EnemyName = "TestBot", Amount = 2, UnitValues = {}}
        }
    },

    Methods = {
        StartRoom = function(Room)
            for _, Floor in Room.FloorParts do
                Floor.Color = Color3.fromRGB(78, 146, 102)
            end
        end
    }
}

return Level_1