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

    Methods = {},
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

Level_1["Room_3"] = {
    SystemType = "Room",
    ID = 2,
    CompletionRequirements = {},
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

                LevelService.CompleteRoom(Room)

                Button.Color = Color3.fromRGB(0, 0, 0)
            end)
        end
    }
}

return Level_1