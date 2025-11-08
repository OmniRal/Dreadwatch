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

local ServerGlobalValues = require(ServerScriptService.Source.ServerModules.Top.ServerGlobalValues)
local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)
local LevelInfo = require(ReplicatedStorage.Source.SharedModules.Info.LevelInfo)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PLAY_LEVEL_HERE = CFrame.new(1000, 1000, 1000) -- Where the level is placed and played
local KEEP_LEVEL_POS_SAME = true -- Do not move the level to PLAY_LEVEL_HERE if true

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CheckForceSpawnLevel()
    if not ServerGlobalValues.StartLevelInfo.TestingMode then return end
    if not ServerGlobalValues.StartLevelInfo.TestWithoutPlayers then return end
    task.delay(1, function()
        LevelService.LoadLevel(ServerGlobalValues.StartLevelInfo.ID)
    end)
end

-- Intended to get all parts named "Floor" inside Rooms and Halls
local function GetFloorParts(Build: Model): {BasePart}?
    if not Build then return end

    local List: {BasePart} = {}

    for _, Floor: Instance in Build:GetChildren() do
        if not Floor then continue end
        if Floor.Name ~= "Floor" or not Floor:IsA("BasePart") then continue end
        table.insert(List, Floor)
    end

    return List
end

local function NewHallData(Model: Model): LevelEnum.Hall?
    if not Model then return end

    local NewHall: LevelEnum.Hall = {
        SystemType = "Hall",
        Build = Model,
        CFrame = Model:GetPivot(),
        Size = Model:GetExtentsSize(),
        FloorParts = GetFloorParts(Model) or {},
        Slots = {},
        Decor = {},
        Players = {},
    }

    return NewHall
end

local function NewRoomData(ID: number, Model: Model): LevelEnum.Room?
    if not Model then return end

    local NewRoom: LevelEnum.Room = {
        SystemType = "Room",
        ID = ID,
        RoomType = "Normal",
        Values = {},
        Build = Model,
        CFrame = Model:GetPivot(),
        Size = Model:GetExtentsSize(),
        FloorParts = GetFloorParts(Model) or {},
        Occupied = {},
        Slots = {},
        Spawners = {},
        NPCs = {},
        Decor = {},
        Lighting = {},
        Players = {},
    }

    return NewRoom
end

local function NewChunkData(ID: number, Model: Model): LevelEnum.Chunk?
    if not Model then return end
    local Details = Model:FindFirstChild("ChunkDetails")
    if not Details then return end

    local NewChunk: LevelEnum.Chunk = {
        SystemType = "Chunk",
        ID = ID,
        Build = Model,
        Rooms = {},
        Halls = {},
        Entrances = {},
        Choices = {},
        TitleCard = Details.TitleCard.Value
    }

    return NewChunk
end

local function FinishChunkSetup(Chunk: LevelEnum.Chunk)
    if not Chunk then return end

    for _, Room in Chunk.Rooms do
        if not Room then continue end
        if not Room.Build then continue end
    
        -- Find the entrance and choice (parts) inside the rooms
        for _, CorePart: BasePart in Room.Build:GetChildren() do
            if not CorePart then continue end
            
            -- Add entrance
            if CorePart.Name == "Entrance" then
                table.insert(Chunk.Entrances, CorePart)

            -- Add choices
            elseif CorePart.Name == "Choice" then
                local ConnectTo = CorePart:GetAttribute("ConnectTo") :: number
                if not ConnectTo then continue end
                Chunk.Choices[CorePart] = ConnectTo
            end
        end
    end
end

-- Set all the safe spawns players can spawn into in a chunk
local function SetAvailableSpawns()
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end
    if not Level.CurrentChunk then return end
    if not Level.CurrentChunk.Entrances then return end

    table.clear(Level.AvailableSpawns)

    for _, Entrance in Level.CurrentChunk.Entrances do
        if not Entrance then continue end
        
        local CellSize, CellPadding = 4, 2
        local CellFinal = CellSize + CellPadding

        local Total = math.clamp(#ServerGlobalValues.StartLevelInfo.ExpectedPlayers, 1, 4) -- How many spawns to create (one for each player)
        local Base = Entrance.CFrame * CFrame.new(0, 0, -CellSize * 2)
        
        
        Base *= CFrame.new( -((Total / 2) * CellFinal) + (CellFinal / 2), 0, 0)

        for x = 1, Total do
            local Spawn = Base * CFrame.new((x - 1) * CellFinal, 0, 0)
            table.insert(Level.AvailableSpawns, Spawn)

            Utility:CreateDot(Spawn, Vector3.new(2, 2, 2), Enum.PartType.Block, Color3.fromRGB(50, 200, 255), 100)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function LevelService.MovePlayers()

end

function LevelService.LoadChunk(ID: number)
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end

    local Current, Next = Level.CurrentChunk, nil

    -- Find the chunk to load
    for _, Chunk in ipairs(Level.Chunks) do
        if not Chunk then continue end
        if Chunk.ID ~= ID then continue end
        Next = Chunk
    end

    if Next then
        Next.Build.Parent = Level.Build
    end
    
    if Current and Next then
        Current.Build.Parent = nil
    end
    
    Level.CurrentChunk = Next

    SetAvailableSpawns()
    LevelService.MovePlayers()
end

function LevelService.LoadLevel(ID: number): boolean?
    if not ID then return false end

    -- Get the details of the level
    local Details = LevelInfo["Level_" .. ID]
    if not Details then return false end

    -- Try to get the model of the level from Roblox
    local Success, BaseModel: Model = pcall(function()
        return InsertService:LoadAsset(Details.ModelID)
    end)

    if not Success then return false end

    local LevelModel = BaseModel:GetChildren()[1]
    LevelModel.Name = "CurrentLevel"
    LevelModel.Parent = Workspace
    BaseModel:Destroy()

    if not KEEP_LEVEL_POS_SAME then
        LevelModel:PivotTo(PLAY_LEVEL_HERE)
    end

    local NewLevel: LevelEnum.Level = {
        Details = Details,
        Chunks = {},
        Rooms = {},
        Halls = {},
        Build = LevelModel,
        CurrentChunk = nil,
        AvailableSpawns = {},
    }
    ServerGlobalValues.CurrentLevel = NewLevel

    -- Set up chunks
    for x = 1, #LevelModel:GetChildren() do
        local ChunkModel = LevelModel:FindFirstChild("Chunk_" .. x)
        if not ChunkModel then continue end

        local NewChunk = NewChunkData(x, ChunkModel)

        for _, Object: Model in ChunkModel:GetChildren() do
            if not Object then continue end

            -- Add rooms
            if string.find(Object.Name, "Room") then
                local Room_ID = string.sub(Object.Name, 6, string.len(Object.Name))
                local NewRoom = NewRoomData(Room_ID, Object)
                table.insert(NewChunk.Rooms, NewRoom)
                table.insert(NewLevel.Rooms, NewRoom)

            -- Add halls
            elseif string.find(Object.Name, "Hall") then 
                local NewHall = NewHallData(Object)
                table.insert(NewChunk.Halls, NewHall)
                table.insert(NewLevel.Halls, NewHall)
            end
        end

        FinishChunkSetup(NewChunk)

        table.insert(NewLevel.Chunks, NewChunk)
    end

    LevelService.LoadChunk(1)

    return true
end

function LevelService:Init()
	print("LevelService initialized...")
end

function LevelService:Deferred()
    CheckForceSpawnLevel()

    print("LevelService deferred...")
end

return LevelService