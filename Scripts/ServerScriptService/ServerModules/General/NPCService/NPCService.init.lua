-- OmniRal
--!nocheck

local NPCService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ServerGlobalValues = require(ServerScriptService.Source.ServerModules.Top.ServerGlobalValues)

local NPCInfo = require(ServerScriptService.Source.ServerModules.Info.NPCInfo)
local NPC = require(ServerScriptService.Source.ServerModules.Classes.NPC)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RunHanlder: RBXScriptConnection? = nil

local Spawners: {
    [Model]: {
        Active: boolean, -- If TRUE, spawner will spawn / respawn and update NPCs
        MaxNPCs: number,
        AutoSpawn: boolean, -- If new NPCs should auto spawn NPCs
        CleanDelay: NumberRange, -- How long to wait before the NPC is destroyed fully. Only once this NPC is gone, can it respawn (if auto spawn is enabled)
        UsePathfinding: boolean, -- If TRUE, NPCs will use Robloxs' Pathfinding Service to get to their target positions
        PlayerDistance: number, -- Set to -1 if the system should not detect for nearby players
        
        PatrolStyle: NPCInfo.NPCPatrolStyle,
        -- Stationary = Don't move, ideal for NPCs
        -- Free = Move randomly around the areas the NPC has spawned
        -- Loop = Move through all the points in an endless loop
        -- BackNForth = Move through all the points in a loop, but once reached the last point, start walking back. Restart the cycle once reaching the first point again
        -- RandomPoints = Move between the points randomly
        
        IdleTIme: number, -- How long the NPC should pause when moving between patrol points or after killing a target 
        
        SpawnPoints: {CFrame}, -- The CFs a NPC can spawn at
        PatrolPoints: {Vector3}, -- The points a NPC can travel between
        AvailableNPCs: {{Choice: string, Chance: number}}, -- 
        NPCs: {NPC.NPC},

        OverrideChaseRange: number?, -- How far the NPC can chase a player from their original spawn position before stopping (This will override the chase range the NPC has by default)
    }
} = {}

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function UpdateSpawnersAndNPCs()
    for Model, Spawner in Spawners do
        if not Spawner then continue end
        if not Spawner.Active then continue end
            
        if #Spawner.NPCs < Spawner.MaxNPCs then
            if Spawner.AutoSpawn then
                NPCService:Spawn(Model)
            end
        end

        if #Spawner.NPCs <= 0 then continue end

        for n, NPC in ipairs(Spawner.NPCs) do
            if not NPC then continue end

            if not NPC.Death.ReadyToClean then
                NPC:Update()

            else
                NPC:Clean()
                table.remove(Spawner.NPCs, n)
                continue
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Apply damage to another NPC.
-- @Source = damage APPLYER.
-- @Victim = damage RECEIVER.
-- @DamageAmount = how much damage.
-- @DamageName = what the damage is called; e.g. "Thor's Hammer".
-- @DamageType = which kind of damage type it is, based on CustomEnum.DamageTyoes; if enabled in GlobalValues.
-- @CritPossible = if it should calculate potentially applying a crit.
function NPCService:ApplyDamage(Source: Player | Model | string, Victim: Player | Model, DamageAmount: number, DamageName: string, DamageType: string?, CritPossible: boolean?)
    if not Source or not Victim then return end

    local VictimModel = Victim
    if Victim:IsA("Player") then
        VictimModel = Victim.Character
    end

    if not VictimModel then return end

    if not VictimModel:FindFirstChild("Humanoid") then return end
    VictimModel.Humanoid:TakeDamage(DamageAmount)
end

function NPCService:AddSingleSpawner(SpawnerModel: Model)
    if not SpawnerModel then return end

    local SpawnPoints: {Vector3} = {}
    local PatrolPoints: {Vector3} = {}
    local AvailableNPCs: {[string]: number} = {}

    for _, Point: BasePart in SpawnerModel.SpawnPoints:GetChildren() do
        if not Point then continue end
        table.insert(SpawnPoints, Point.CFrame)
    end
    SpawnerModel.SpawnPoints:Destroy()

    for x = 1, #SpawnerModel.PatrolPoints:GetChildren() do
        local Point: BasePart = SpawnerModel.PatrolPoints:FindFirstChild(x)
        if not Point then continue end
        table.insert(PatrolPoints, Point.Position)
    end
    SpawnerModel.PatrolPoints:Destroy()

    for _, NPCVal: IntValue in SpawnerModel.AvailableNPCs:GetChildren() do
        if not NPCVal then continue end
        table.insert(AvailableNPCs, {Choice = NPCVal.Name, Chance = NPCVal.Value})
    end
    SpawnerModel.AvailableNPCs:Destroy()

    Spawners[SpawnerModel] = {
        Active = SpawnerModel:GetAttribute("Active"),
        MaxNPCs = SpawnerModel:GetAttribute("MaxNPCs"),
        AutoSpawn = SpawnerModel:GetAttribute("AutoSpawn"),
        CleanDelay = SpawnerModel:GetAttribute("CleanDelay"),
        UsePathfinding = SpawnerModel:GetAttribute("UsePathfinding"),
        PlayerDistance = SpawnerModel:GetAttribute("PlayerDistance"),
        PatrolStyle = SpawnerModel:GetAttribute("PatrolStyle"),
        IdleTIme = SpawnerModel:GetAttribute("IdleTime"),
        
        SpawnPoints = SpawnPoints,
        PatrolPoints = PatrolPoints,
        AvailableNPCs = AvailableNPCs,
        NPCs = {},

        OverrideChaseRange = SpawnerModel:GetAttribute("ChaseRange"),
    }

    if not SpawnerModel:GetAttribute("AutoSpawn") then return end
    NPCService:Spawn(SpawnerModel)
end

-- Finds all the NPCSpawners in a location
-- @SearchHere = Where to look for the spawners
-- @Return = If true, it will return an array of the spawners
function NPCService:AddMultipleSpawners(SearchHere: Workspace | Model | Folder, Return: boolean?): {[number]: Model}?
    if not SearchHere then return end

    local List: {[number]: Model} = {}

    for _, SpawnerModel: Model in SearchHere:GetChildren() do
        if not SpawnerModel then continue end
        if SpawnerModel.Name ~= "NPCSpawner" then continue end

        NPCService:AddSingleSpawner(SpawnerModel)

        if not Return then continue end
        List[SpawnerModel:GetAttribute("ID")] = SpawnerModel
    end

    if not Return then return end
    return List
end

function NPCService:Spawn(SpawnerModel: Model, NPCName: string?, ForceSpawn: boolean?)
    if not SpawnerModel then return end
    local Spawner = Spawners[SpawnerModel]
    if not Spawner then return end
    if (#Spawner.NPCs >= Spawner.MaxNPCs) and (not ForceSpawn) then return end

    NPCName = NPCName or Utility:RollPick(Spawner.AvailableNPCs)
    if not NPCName then return end

    local Module = script.AllNPCs:FindFirstChild(NPCName)
    if not Module then return end
    
    local Constructor: NPC.NPCConstructor = {
        Name = NPCName,
        Module = Module, 
        SpawnPoints = Spawner.SpawnPoints,
        PatrolPoints = Spawner.PatrolPoints,
        PatrolStyle = Spawner.PatrolStyle,
        UsePathfinding = Spawner.UsePathfinding,
        IdleTime = Spawner.IdleTIme,
        CleanDelay = Spawner.CleanDelay,
        OverrideChaseRange = Spawner.OverrideChaseRange,
    }

    local NewNPC = NPC.new(Constructor)
    if not NewNPC then return end

    table.insert(Spawner.NPCs, NewNPC)
end

function NPCService:Run()
    NPCService:Stop()

    RunHanlder = RunService.Heartbeat:Connect(function(DeltaTime: number)
        UpdateSpawnersAndNPCs()
    end)
end

function NPCService:Stop()
    if RunHanlder then
        RunHanlder:Disconnect()
    end
    RunHanlder = nil
end

function NPCService:Init()
    if not ServerGlobalValues.CleanupAssetDump then
        NPCService:AddMultipleSpawners(Workspace.AssetDump)
    end

    NPCInfo.NPCDied:Connect(function(NPCName: string)
        --print(NPCName .. " died!")
    end)
end

function NPCService:Deferred()
    NPCService:Run()
end

return NPCService