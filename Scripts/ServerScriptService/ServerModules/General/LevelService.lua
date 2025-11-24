-- OmniRal

local LevelService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local New = require(ReplicatedStorage.Source.Pronghorn.New)

local ServerGlobalValues = require(ServerScriptService.Source.ServerModules.Top.ServerGlobalValues)
local LevelEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)
local LevelInfo = require(ReplicatedStorage.Source.SharedModules.Info.LevelInfo)

local NPCService = require(ServerScriptService.Source.ServerModules.General.NPCService)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UPDATE_RATE = 0.1

local PLAY_LEVEL_HERE = CFrame.new(1000, 1000, 1000) -- Where the level is placed and played
local KEEP_LEVEL_POS_SAME = true -- Do not move the level to PLAY_LEVEL_HERE if true

local SHOW_ROOM_DETAILS = true

local SHOW_WALLS_WHEN_COLLIDE = true

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local MyPlayers: {Player} = {}

local RunHeartbeat: RBXScriptConnection? = nil
local MovingToNewChunk = false

local TempRoom: Model = Workspace.TempRoom

local Assets = ServerStorage.Assets
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CheckForceSpawnLevel()
    if not ServerGlobalValues.StartLevelInfo.TestingMode then return end
    if not ServerGlobalValues.StartLevelInfo.TestWithoutPlayers then return end
    task.delay(1, function()
        LevelService.LoadLevel({}, ServerGlobalValues.StartLevelInfo.ID)
    end)
end

-- Toggle the collisions for the slot walls of a room
local function ToggleSlotWalls(ThisRoom: LevelEnum.Room, Set: boolean)
    for _, Slot in ThisRoom.Slots do
        if not Slot.WallPart then continue end
        Slot.WallPart.CanCollide = Set

        if SHOW_WALLS_WHEN_COLLIDE and Set then
            Slot.WallPart.Transparency = 0.5
        elseif SHOW_WALLS_WHEN_COLLIDE and not Set then
            Slot.WallPart.Transparency = 1
        end
    end
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

-- Find the slots in rooms or halls, add them to table
local function SetSlots(Space: LevelEnum.Room | LevelEnum.Hall)
    if not Space then return end
    if not Space.Build then return end
    
    for _, SlotPart in Space.Build:GetChildren() do
        if not SlotPart then continue end
        if SlotPart.Name ~= "Slot" then continue end

        -- Keep the slot part and the slot wall in one model
        local NewModel = New.Instance("Model", "Slot_" .. #Space.Slots + 1, Space.Build)

        -- Add the wall for the slot (used for locking players in rooms when needed)
        local NewWall = New.Instance("Part", "SlotWall", NewModel, {
            Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Size = Vector3.new(SlotPart.Size.X, 25, SlotPart.Size.Z), Transparency = 1,
            CFrame = SlotPart.CFrame * CFrame.new(0, 12.5, 0)
        })
        
        local NewSlot: LevelEnum.Slot = {
            SystemType = "Slot",
            Open = true,
            Index = #Space.Slots + 1,
            SlotPart = SlotPart,
            WallPart = NewWall,
            ConnectedTo = nil,
        }

        SlotPart.Transparency = 1
        SlotPart.Parent = NewModel

        table.insert(Space.Slots, NewSlot)
    end
end

-- Looks through all the rooms and halls in a chunk and sees what each one connects to; updating their slot data
local function CheckSlotConnections(ThisChunk: LevelEnum.Chunk)
    if not ThisChunk then return end

    local TempList: {LevelEnum.Room | LevelEnum.Hall} = {}

    for _, ThisRoom in ThisChunk.Rooms do 
        table.insert(TempList, ThisRoom) 
    end
    for _, ThisHall in ThisChunk.Halls do 
        table.insert(TempList, ThisHall) 
    end

    for _, Space_A in TempList do
        if not Space_A.Slots then continue end
        for _, Slot_A: LevelEnum.Slot in Space_A.Slots do
            if not Slot_A.SlotPart or not Slot_A.Open then continue end
            
            for _, Space_B in TempList do
                if Space_B == Space_A then continue end
                for _, Slot_B: LevelEnum.Slot in Space_B.Slots do
                    if not Slot_B.SlotPart or not Slot_B.Open then continue end

                    local RelativeCF = Slot_A.SlotPart.CFrame:PointToObjectSpace(Slot_B.SlotPart.Position)
                    if math.abs(RelativeCF.X) > 0.1 or math.abs(RelativeCF.Y) > 0.1 or math.abs(RelativeCF.Z) > 4.5 then continue end

                    Slot_A.ConnectedTo = Space_B
                    Slot_A.Open = false
                    Slot_B.ConnectedTo = Space_A
                    Slot_B.Open = false

                    --warn(`{Space_A.Build.Name} slot {Slot_A.Index} connected to {Space_B.Build.Name} slot {Slot_B.Index}`)

                    break
                end
            end
        end
    end
end

local function CreateNewHall(Model: Model): LevelEnum.Hall?
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

    SetSlots(NewHall)

    return NewHall
end

local function CreateNewRoom(ID: number, Model: Model, RoomData: LevelEnum.SpaceData): LevelEnum.Room?
    if not Model then return end

    local NewRoom: LevelEnum.Room = {
        SystemType = "Room",
        ID = ID,
        RoomType = "Normal",
        Started = false,
        Completed = false,
        Values = {},
        
        Build = Model,
        CFrame = Model:GetPivot(),
        Size = Model:GetExtentsSize(),
        FloorParts = GetFloorParts(Model) or {},

        Slots = {},
        
        NPCs = {},

        Decor = {},
        Lighting = {},
        Players = {},
    }

    SetSlots(NewRoom)

    NewRoom.Spawners = NPCService:AddMultipleSpawners(Model, true) or nil

    if RoomData and RoomData.CompletionRequirements.ClearEnemyWaves and RoomData.EnemyWaves then
        NewRoom.WavesCleared = false
        NewRoom.WaveNum = 1
        NewRoom.Waves = {}

        for _, WaveData in ipairs(RoomData.EnemyWaves) do
            local NewWaveTracker: {LevelEnum.WaveEnemyTracker} = {}

            for _, EnemyWaveData in ipairs(WaveData) do
                if not EnemyWaveData then continue end
                local NewWaveEnemyTracker: LevelEnum.WaveEnemyTracker = {
                    Enemies = {},
                    Spawned = 0,
                    Killed = 0,
                }

                table.insert(NewWaveTracker, NewWaveEnemyTracker)
            end

            table.insert((NewRoom.Waves :: any), NewWaveTracker)
        end
    end

    return NewRoom
end

local function CreateNewChunk(ID: number, Model: Model): LevelEnum.Chunk?
    if not Model then return end
    local Details = Model:FindFirstChild("ChunkDetails")
    if not Details then return end

    local NewChunk: LevelEnum.Chunk = {
        SystemType = "Chunk",
        ID = ID,
        Active = false,
        Completed = false,
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
                CorePart:SetAttribute("Room_ID", Room.ID)
                table.insert(Chunk.Entrances, CorePart)

            -- Add choices
            elseif CorePart.Name == "Choice" then
                local ConnectTo = tonumber(CorePart:GetAttribute("ConnectTo") :: string)
                if not ConnectTo then continue end
                CorePart.CanTouch = true
                Chunk.Choices[CorePart] = ConnectTo
            end
        end

        if not SHOW_ROOM_DETAILS then continue end

        local Gui = Assets.Other.WorldLevelUI.RoomGui:Clone()
        Gui.Name = "Gui"
        Gui._1.Text = Room.ID
        Gui.Parent = Room.Build.PrimaryPart
    end

    -- Add choice connections
    for Part, ConnectTo in Chunk.Choices do
        if not Part or not ConnectTo then continue end

        Part.CanTouch = true
        Part.Transparency = 0.5
        
        -- NOTE: may have to make a better (than onTouch part) way to trigger moving to a new chunk
        Part.Touched:Connect(function(Hit: BasePart)
            if MovingToNewChunk then return end
            if not Hit then return end
            if not Hit.Parent then return end
            if not Players:FindFirstChild(Hit.Parent.Name) then return end
            
            local NextChunk = LevelService.FindChunkFromRoomID(ConnectTo)
            if not NextChunk then return end

            LevelService.MigrateToThisChunk(NextChunk.ID, ConnectTo, Part:GetAttribute("Entrance_ID"))
        end)
    end
end

-- Tracks which players are in which rooms
local function TrackPlayersInRooms()
    if MovingToNewChunk then return end
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end
    if not Level.CurrentChunk then return end

    for _, Player in Players:GetPlayers() do
        if not Player then continue end
        if not Player.Character then continue end
        local Root: BasePart = Player.Character:FindFirstChild("HumanoidRootPart")
        if not Root then continue end
        
        for _, Room in Level.CurrentChunk.Rooms do
            if not Room then continue end
            if not Room.FloorParts then continue end
            
            -- Check if the player is within ANY of the floor segments of the room
            local InRoom = false
            for _, Floor in Room.FloorParts do
                if not Floor then continue end
                local RelativeCF = Floor.CFrame:PointToObjectSpace(Root.Position)
                if math.abs(RelativeCF.X) > Floor.Size.X / 2 or math.abs(RelativeCF.Z) > Floor.Size.Z / 2 then continue end
                InRoom = true
                break
            end

            local PIndex = table.find(Room.Players, Player)
            if InRoom and not PIndex then
                table.insert(Room.Players, Player)
            
            elseif not InRoom and PIndex then
                table.remove(Room.Players, PIndex)
            end

            if not SHOW_ROOM_DETAILS then continue end
            Room.Build.PrimaryPart.Gui._2.Text = #Room.Players
        end
    end
end

local function RunRoom(ThisRoom: LevelEnum.Room, RoomData: LevelEnum.SpaceData)
        -- Run the StartRoom function if it exists
    if RoomData.Methods.StartRoom and not ThisRoom.Started then
        if RoomData.AllPlayersRequiredToStart and #ThisRoom.Players < #MyPlayers then return end

        ThisRoom.Started = true
        RoomData.Methods.StartRoom(ThisRoom)

        -- Block players inside the room (if set to TRUE)
        if RoomData.RoomBlockedOutUntilComplete then
            ToggleSlotWalls(ThisRoom, true)
        end
    end

    if not ThisRoom.Started then return end

    -- Handle enemy wave spawning
    if ThisRoom.Waves and not ThisRoom.WavesCleared and ThisRoom.WaveNum and ThisRoom.Spawners and RoomData.CompletionRequirements.ClearEnemyWaves and RoomData.EnemyWaves then
        local Wave = ThisRoom.Waves[ThisRoom.WaveNum]
        local WaveData = RoomData.EnemyWaves[ThisRoom.WaveNum]
        local SpawnersToUse: {number} = {}
        local SpawnNextIDs: {number} = {}

        for n, Tracker in ipairs(Wave) do
            local TrackerData = WaveData[n]
            if not TrackerData then continue end
            if Tracker.Killed >= TrackerData.Amount then continue end
            if TrackerData.Chance and RNG:NextInteger(1, 100) > TrackerData.Chance then continue end

            -- Make sure two enemies are not being spawned at the same spawner
            local AvailableSpawners = table.clone(TrackerData.SpawnerIDs)
            for x = #AvailableSpawners, 1, -1 do
                if not table.find(SpawnersToUse, AvailableSpawners[x]) then continue end
                table.remove(AvailableSpawners, x)
            end

            if #AvailableSpawners <= 0 then continue end

            -- Add to the list to be spawned next
            local RandSpawner = AvailableSpawners[RNG:NextInteger(1, #AvailableSpawners)]
            table.insert(SpawnersToUse, RandSpawner)
            table.insert(SpawnNextIDs, n)
        end

        if #SpawnersToUse > 0 then
            for n = 1, #SpawnNextIDs do
                local Tracker = Wave[n]
                local TrackerData = WaveData[n]
                local Spawner = ThisRoom.Spawners[SpawnersToUse[n]]
                if not Tracker or not TrackerData or not Spawner then continue end

                Tracker.Spawned += 1
                NPCService:Spawn(Spawner, TrackerData.EnemyName)
            end
        end
    end

    -- Check to update
    if not RoomData.Methods.Update then return end
    if RoomData.UpdateWithoutPlayers and #ThisRoom.Players <= 0 then return end

    RoomData.Methods.Update(ThisRoom)
end

-- Run methods for the current chunk and its rooms
local function RunChunk()
    if MovingToNewChunk then return end
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end
    if not Level.CurrentChunk or not Level.Module then return end

    -- Run the chunks update method if it exists
    if Level.CurrentData and Level.CurrentData.Methods.Update then
        Level.CurrentData.Methods.Update(Level.CurrentChunk)
    end

    for _, ThisRoom in Level.CurrentChunk.Rooms do
        if not ThisRoom then continue end
        local RoomData: LevelEnum.SpaceData = Level.Module["Room_" .. ThisRoom.ID]
        if not RoomData or ThisRoom.Completed then continue end
        
        RunRoom(ThisRoom, RoomData)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Sets a room to complete, then checks the associated chunk to see if ALL its rooms are complete
function LevelService.CompleteRoom(ThisRoom: LevelEnum.Room)
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end
    if not Level.Module then return end
    
    -- Get the chunk the room is in
    local ThisChunk = LevelService.FindChunkFromRoomID(ThisRoom.ID)
    if not ThisChunk then return end

    -- Make sure the chunk is a part of the module script for this level
    local ChunkData = Level.Module["Chunk_" .. ThisChunk.ID]
    if not ChunkData then return end

    ThisRoom.Completed = true
    local RoomData: LevelEnum.SpaceData = Level.Module["Room_" .. ThisRoom.ID]
    if RoomData and RoomData.RoomBlockedOutUntilComplete then
        ToggleSlotWalls(ThisRoom, false)
    end

    -- Check if all the rooms of this chunk are complete
    local AllComplete = true
    for _, Room: LevelEnum.Room in ThisChunk.Rooms do
        if not Room then continue end
        if not table.find(ChunkData.CompletionRequirements.Rooms, Room.ID) then continue end
        if Room.Completed then continue end

        -- This room is NOT complete
        AllComplete = false
    end

    ThisChunk.Completed = AllComplete
end

function LevelService.MigrateToThisChunk(ThisChunk_ID: number, ThisRoom_ID: number?, ThisEntrance_ID: number?)
    local Level = ServerGlobalValues.CurrentLevel
    if not Level or MovingToNewChunk then return end
    if not Level.CurrentChunk.Completed then return end

    MovingToNewChunk = true

    -- Move players to the temp room
    LevelService.MovePlayers("TempRoom") 

    -- Load the new chunk
    LevelService.LoadChunk(ThisChunk_ID) 

    -- Set current available to spawns to that new chunk and specific room + entrance IDs (if provided)
    LevelService.SetAvailableSpawns(ThisRoom_ID, ThisEntrance_ID) 

    -- Move players to the new available spawns
    LevelService.MovePlayers("CurrentAvailableSpawns")
    
    task.wait(1) -- For safety
    MovingToNewChunk = false
end

-- @To - "TempRoom" = moves players to a floating room in the world; meant to be a temporary space to hold players while loading other stuff
-- @To - "CurrentAvailableSpawns" = moves players to the current available spawns of a level
function LevelService.MovePlayers(To: "TempRoom" | "CurrentAvailableSpawns")
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end

    for _, Player in Players:GetPlayers() do
        if not Player then continue end
        if not Player.Character then continue end
        local Order_ID: number = Player:GetAttribute("Order_ID")
        if not Order_ID then 
            warn("Order ID missing for", Player)
            continue
        end

        local SpawnHere = Level.AvailableSpawns[Order_ID]

        if To == "TempRoom" then
            -- Find the Spawn in the temp room with the same ID as the player
            SpawnHere = TempRoom:FindFirstChild("Spawn_" .. Order_ID)
            if not SpawnHere then
                warn("Temp Spawn ID " .. Order_ID .. "is missing?")
                continue
            end

            SpawnHere = SpawnHere.CFrame
        end

        if not SpawnHere then continue end

        Player.Character:PivotTo(SpawnHere * CFrame.new(0, 3, 0))
    end
end

-- Set all the safe spawns players can spawn into in a chunk
-- @ThisRoom_ID = if the available spawns in a chunk should only from a specific room
-- @ThisEntrance_ID = if the available spawns in a chunk only be from a single specific entrance
function LevelService.SetAvailableSpawns(ThisRoom_ID: number?, ThisEntrance_ID: number?)
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end
    if not Level.CurrentChunk then return end
    if not Level.CurrentChunk.Entrances then return end

    table.clear(Level.AvailableSpawns)

    for _, Entrance in Level.CurrentChunk.Entrances do
        if not Entrance then continue end
        if ThisRoom_ID and Entrance:GetAttribute("Room_ID") ~= ThisRoom_ID then continue end
        if ThisEntrance_ID and Entrance:GetAttribute("ID") ~= ThisEntrance_ID then continue end
        
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

-- Returns a chunk that has a specific room number
function LevelService.FindChunkFromRoomID(ID: number): LevelEnum.Chunk?
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end

    for _, Chunk in Level.Chunks do
        if not Chunk then continue end
        if not Chunk.Rooms then continue end
        
        for _, Room in Chunk.Rooms do
            if not Room then continue end
            if Room.ID ~= ID then continue end
            return Chunk
        end    
    end

    return
end

-- Load a single chunk
-- @HideAllChunks = If true, all chunks will be set to inactive and their builds parented to nil
function LevelService.LoadChunk(ID: number, HideAllChunks: boolean?)
    local Level = ServerGlobalValues.CurrentLevel
    if not Level then return end

    local NextData = Level.Module["Chunk_" .. ID]
    assert(NextData, "Missing next module chunk!")

    local NextChunk = nil

    -- Find the chunk to load
    for _, Chunk in ipairs(Level.Chunks) do
        if not Chunk then continue end

        if HideAllChunks then
            Chunk.Active = false
            Chunk.Build.Parent = nil
        end

        if Chunk.ID ~= ID then continue end
        NextChunk = Chunk
    end

    if NextChunk then
        NextChunk.Active = true
        NextChunk.Build.Parent = Level.Build
    end
    
    if Level.CurrentChunk and NextChunk then
        if Level.CurrentData and Level.CurrentData.Methods.Exit then
            Level.CurrentData.Methods.Exit(Level.CurrentChunk)
        end

        Level.CurrentChunk.Active = false
        Level.CurrentChunk.Build.Parent = nil
    end

    -- Run init method for the chunk, if it exists
    if NextData.Methods.Init then
        NextData.Methods.Init(NextChunk)
    end

    -- If the chunk has NO rooms that need to be completed, set its completion to true by default
    if #NextData.CompletionRequirements.Rooms <= 0 then
        NextChunk.Completed = true
    end

    -- Run init methods for its rooms, if they exist
    for _, Room in NextChunk.Rooms do
        if not Room then continue end
        local RoomData = Level.Module["Room_" .. Room.ID]
        if not RoomData then continue end
        if not RoomData.Methods.Init then continue end

        RoomData.Methods.Init(Room)
    end

    Level.CurrentChunk = NextChunk
    Level.CurrentData = NextData
end

function LevelService.LoadLevel(LoadingPlayers: {Player}, ID: number): boolean?
    if not LoadingPlayers or not ID then return false end

    for _, Player in ipairs(LoadingPlayers) do
        table.insert(MyPlayers, Player)
    end

    warn("MY PLAYERS:", MyPlayers)

    -- Get the details of the level
    local Details = LevelInfo["Level_" .. ID]
    if not Details then return false end

    local Module = ServerScriptService.Source.ServerModules.LevelModules:FindFirstChild("Level_" .. ID)
    if not Module then return false end

    -- Try to get the model of the level from Roblox
    local Success, BaseModel: Model = pcall(function()
        return InsertService:LoadAsset(Details.ModelID)
    end)

    if not Success then return false end

    local LevelModel = BaseModel:GetChildren()[1] :: Model
    LevelModel.Name = "CurrentLevel"
    LevelModel:PivotTo(PLAY_LEVEL_HERE)
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
        Module = require(Module)
    }
    ServerGlobalValues.CurrentLevel = NewLevel

    -- Set up chunks
    for x = 1, #LevelModel:GetChildren() do
        local ChunkModel = LevelModel:FindFirstChild("Chunk_" .. x)
        if not ChunkModel then continue end
        
        local NewChunk = CreateNewChunk(x, ChunkModel)
        
        for _, Object: Model in ChunkModel:GetChildren() do
            if not Object then continue end

            -- Add rooms
            if string.find(Object.Name, "Room") then
                local Room_ID = tonumber(string.sub(Object.Name, 6, string.len(Object.Name)))
                local RoomData = NewLevel.Module["Room_" .. Room_ID]

                local NewRoom = CreateNewRoom(Room_ID, Object, RoomData)
                table.insert(NewChunk.Rooms, NewRoom)
                table.insert(NewLevel.Rooms, NewRoom)

            -- Add halls
            elseif string.find(Object.Name, "Hall") then 
                local NewHall = CreateNewHall(Object)
                table.insert(NewChunk.Halls, NewHall)
                table.insert(NewLevel.Halls, NewHall)
            end
        end

        FinishChunkSetup(NewChunk)
        CheckSlotConnections(NewChunk)

        table.insert(NewLevel.Chunks, NewChunk)
    end

    LevelService.LoadChunk(1, true)
    LevelService.SetAvailableSpawns()
    LevelService.Run()

    return true
end

function LevelService.Stop()
    if not RunHeartbeat then return end
    RunHeartbeat:Disconnect()
    RunHeartbeat = nil
end

function LevelService.Run()
    LevelService.Stop()

    local NextUpdate = os.clock() + UPDATE_RATE
    RunHeartbeat = RunService.Heartbeat:Connect(function()
        if os.clock() < NextUpdate then return end
        NextUpdate = os.clock() + UPDATE_RATE

        TrackPlayersInRooms()
        RunChunk()
    end)
end

function LevelService:Init()
	print("LevelService initialized...")
end

function LevelService:Deferred()
    CheckForceSpawnLevel()

    print("LevelService deferred...")
end

return LevelService