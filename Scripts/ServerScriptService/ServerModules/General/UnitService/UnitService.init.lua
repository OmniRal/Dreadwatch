-- OmniRal
--!nocheck

local UnitService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local New = require(ReplicatedStorage.Source.Pronghorn.New)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UnitInfo = require(ServerScriptService.Source.ServerModules.Info.UnitInfo)
local Unit = require(ServerScriptService.Source.ServerModules.Classes.Unit)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RunHanlder: RBXScriptConnection? = nil

local Spawners: {
    [Model]: {
        Active: boolean, -- If TRUE, spawner will spawn / respawn and update units
        MaxUnits: number,
        AutoSpawn: boolean, -- If new units should auto spawn units
        CleanDelay: NumberRange, -- How long to wait before the unit is destroyed fully. Only once this unit is gone, can it respawn (if auto spawn is enabled)
        UsePathfinding: boolean, -- If TRUE, units will use Robloxs' Pathfinding Service to get to their target positions
        PlayerDistance: number, -- Set to -1 if the system should not detect for nearby players
        
        PatrolStyle: UnitInfo.UnitPatrolStyle,
        -- Stationary = Don't move, ideal for NPCs
        -- Free = Move randomly around the areas the Unit has spawned
        -- Loop = Move through all the points in an endless loop
        -- BackNForth = Move through all the points in a loop, but once reached the last point, start walking back. Restart the cycle once reaching the first point again
        -- RandomPoints = Move between the points randomly
        
        IdleTIme: number, -- How long the unit should pause when moving between patrol points or after killing a target 
        
        SpawnPoints: {CFrame}, -- The CFs a unit can spawn at
        PatrolPoints: {Vector3}, -- The points a unit can travel between
        AvailableUnits: {{Choice: string, Chance: number}}, -- 
        Units: {Unit.Unit},

        OverrideChaseRange: number?, -- How far the unit can chase a player from their original spawn position before stopping (This will override the chase range the unit has by default)
    }
} = {}

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function UnitService:AddSingleSpawner(SpawnerModel: Model)
    if not SpawnerModel then return end

    local SpawnPoints: {Vector3} = {}
    local PatrolPoints: {Vector3} = {}
    local AvailableUnits: {[string]: number} = {}

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

    for _, UnitVal: IntValue in SpawnerModel.AvailableUnits:GetChildren() do
        if not UnitVal then continue end
        table.insert(AvailableUnits, {Choice = UnitVal.Name, Chance = UnitVal.Value})
    end
    SpawnerModel.AvailableUnits:Destroy()

    Spawners[SpawnerModel] = {
        Active = SpawnerModel:GetAttribute("Active"),
        MaxUnits = SpawnerModel:GetAttribute("MaxUnits"),
        AutoSpawn = SpawnerModel:GetAttribute("AutoSpawn"),
        CleanDelay = SpawnerModel:GetAttribute("CleanDelay"),
        UsePathfinding = SpawnerModel:GetAttribute("UsePathfinding"),
        PlayerDistance = SpawnerModel:GetAttribute("PlayerDistance"),
        PatrolStyle = SpawnerModel:GetAttribute("PatrolStyle"),
        IdleTIme = SpawnerModel:GetAttribute("IdleTime"),
        
        SpawnPoints = SpawnPoints,
        PatrolPoints = PatrolPoints,
        AvailableUnits = AvailableUnits,
        Units = {},

        OverrideChaseRange = SpawnerModel:GetAttribute("ChaseRange"),
    }

    if not SpawnerModel:GetAttribute("AutoSpawn") then return end
    --UnitService:Spawn(SpawnerModel)
end

function UnitService:AddMultipleSpawners(Check: Workspace | Model | Folder)
    if not Check then return end
    for _, SpawnerModel: Model in Check:GetChildren() do
        if not SpawnerModel then continue end
        if SpawnerModel.Name ~= "UnitSpawner" then continue end
        UnitService:AddSingleSpawner(SpawnerModel)
    end
end

function UnitService:Spawn(SpawnerModel: Model, UnitName: string?, ForceSpawn: boolean?)
    if not SpawnerModel then return end
    local Spawner = Spawners[SpawnerModel]
    if not Spawner then return end
    if (#Spawner.Units >= Spawner.MaxUnits) and (not ForceSpawn) then return end

    UnitName = UnitName or Utility:RollPick(Spawner.AvailableUnits)
    if not UnitName then return end

    local Module = script:FindFirstChild(UnitName)
    if not Module then return end
    
    local Constructor: Unit.UnitConstructor = {
        Name = UnitName,
        Module = Module, 
        SpawnPoints = Spawner.SpawnPoints,
        PatrolPoints = Spawner.PatrolPoints,
        PatrolStyle = Spawner.PatrolStyle,
        UsePathfinding = Spawner.UsePathfinding,
        IdleTime = Spawner.IdleTIme,
        CleanDelay = Spawner.CleanDelay,
        OverrideChaseRange = Spawner.OverrideChaseRange,
    }

    local NewUnit = Unit.new(Constructor)
    if not NewUnit then return end

    table.insert(Spawner.Units, NewUnit)
end

function UnitService:Run()
    UnitService:Stop()

    RunHanlder = RunService.Heartbeat:Connect(function(DeltaTime: number)
        for Model, Spawner in Spawners do
            if not Spawner then continue end
            if not Spawner.Active then continue end
            
            if #Spawner.Units < Spawner.MaxUnits then
                if Spawner.AutoSpawn then
                    UnitService:Spawn(Model)
                end
            end

            if #Spawner.Units <= 0 then continue end

            for n, Unit in ipairs(Spawner.Units) do
                if not Unit then continue end

                if not Unit.Death.ReadyToClean then
                    Unit:Update()

                else
                    Unit:Clean()
                    table.remove(Spawner.Units, n)
                    continue
                end
            end
        end
    end)
end

function UnitService:Stop()
    if RunHanlder then
        RunHanlder:Disconnect()
    end
    RunHanlder = nil
end

function UnitService:Init()
    UnitService:AddMultipleSpawners(workspace)

    UnitInfo.UnitDied:Connect(function(UnitName: string)
        print(UnitName .. " died!")
    end)
end

function UnitService:Deferred()
    UnitService:Run()
end

return UnitService