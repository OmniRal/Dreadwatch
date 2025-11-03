-- OmniRal

local LevelService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)
local LevelInfo = require(ReplicatedStorage.Source.SharedModules.Info.LevelInfo)

local Grid = require(ServerScriptService.Source.ServerModules.Classes.Grid)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PLAY_LEVEL_HERE = CFrame.new(1000, 1000, 1000) -- Where the level is placed and played

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function LevelService:LoadLevel(ID: number): boolean?
    if not ID then return false end

    -- Get the details of the level
    local Details = LevelInfo["Level_" .. ID]
    if not Details then return false end

    -- Try to get the model of the level from Roblox
    local Success, LevelModel: Model = pcall(function()
        return InsertService:LoadAsset(Details.ModelID)
    end)

    if not Success then return false end

    LevelModel:PivotTo(PLAY_LEVEL_HERE)

    local NewGrid = Grid.new(PLAY_LEVEL_HERE)

    local NewLevel: LevelEnum.Level = {
        Details = Details,
        Chunks = {},
        Rooms = {},
        Halls = {},
        Grid = NewGrid,
        Model = LevelModel,
    }

    -- Set up chunks
    local RoomNum = 1

    for x = 1, #LevelModel:GetChildren() do
        local ChunkModel = LevelModel:FindFirstChild("Chunk_" .. x)
        if not ChunkModel then continue end

        local NewChunk: LevelEnum.Chunk = {
            SystemType = "Chunk",
            Model = ChunkModel,
            Rooms = {},
            Halls = {},
            TitleCard = ChunkModel:GetAttribute("TitleCard")
        }
        
        local Room = LevelModel:FindFirstChild("Room_" .. RoomNum)
        if Room then
            --table.insert(NewChunk.Rooms, Room)
        end
    end

    return true
end

function LevelService:Init()
	print("LevelService initialized...")
end

function LevelService:Deferred()
    task.delay(1, function()
        LevelService:LoadLevel(1)
    end)

    print("LevelService deferred...")
end

return LevelService