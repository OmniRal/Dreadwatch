-- OmniRal

local CoreGameService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local GlobalValues = require(ReplicatedStorage.Source.SharedModules.Top.GlobalValues)
local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

local CharacterService = require(ServerScriptService.Source.ServerModules.Player.CharacterService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local TESTING_MISSION = false -- When false, players will spawn in the lobby area, otherwise it will run a mission
local TEST_MISSION_ID = 0
local PLAYERS_NEEDED_FOR_TEST = {"OmniRal"}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlaceSetupStarted = false
local PlaceSetupComplete = false

local PlayerValues: {
    [Player]: {
        RespawnTime: number
    }
} = {}

local Lobby = Workspace:WaitForChild("Lobby")
local LobbySpawns: {CFrame} = {}

local Assets = ServerStorage.Assets
local SharedAssets = ReplicatedStorage.Assets

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function SpawnCharacter(Player: Player)
    if not Player then return end
    Player:LoadCharacter()
end

local function SetupRespawning(Player: Player, Character: any)
    if Players.CharacterAutoLoads then return end

    local PValues = PlayerValues[Player]
    if not PValues then return end

    local Human = Character:WaitForChild("Humanoid")

    -- CHeck for when the player dies in order to respawn them
    PValues.DeathConnection = Human.Died:Connect(function()
        task.spawn(function()
            PValues.RespawnTime = Players.RespawnTime

            for x = Players.RespawnTime, 0, -1 do
                task.wait(1)
                PValues.RespawnTime -= 1
            end

            SpawnCharacter(Player)

            PValues.DeathConnection:Disconnect()
            PValues.DeathConnection = nil
        end)
    end)
end

-- Checks to see to decide if the place will be a lobby or a level based on the first players join data
local function CheckLoadLevel(Player: Player)
    if PlaceSetupStarted or PlaceSetupComplete then return end
    if not Player then return end

    PlaceSetupStarted = true

    local JoinData = Player:GetJoinData()
    if not JoinData then
        -- No join data exists, assume its a lobby
        PlaceSetupComplete = true
        return 
    end

    print("Got join data from", Player, " :", JoinData)

    local TeleportData: CustomEnum.TeleportData = JoinData.TeleportData
    if not TeleportData then return end
    if not TeleportData.MissionID or not TeleportData.ExpectedPlayers then return end
    -- May need fail safe here if a players teleport data is corrupted; send them back to their lobby ideally

    GlobalValues.InLevel = true
    Workspace.Lobby:Destroy() -- Get rid of the entire lobby folder

    PlaceSetupComplete = true
    
    return
end

local function SetupLobby()
    for _, Spawn: BasePart in Lobby:GetChildren() do
        if Spawn.Name ~= "LobbySpawn" then continue end
        table.insert(LobbySpawns, Spawn.CFrame * CFrame.new(0, 3, 0))
        Spawn:Destroy()
    end
end

local function SetupCollisions()
    PhysicsService:RegisterCollisionGroup("Players")
    PhysicsService:RegisterCollisionGroup("NoClip")
    PhysicsService:CollisionGroupSetCollidable("Default", "Players", true)
    PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
    PhysicsService:CollisionGroupSetCollidable("Default", "NoClip", false)
end

local function ToggleParticles(Player: Player, Parts: {BasePart}, Particles: {{Name: string, Set: boolean}})
    if not Player then return end

    for _, Part in pairs(Parts) do
        if not Part then continue end
            
        for _, Info in pairs(Particles) do
            if not Part:FindFirstChild(Info.Name) then continue end
            Part[Info.Name].Enabled = Info.Set
        end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function CoreGameService:RequestSpawnLocation(Player: Player): CFrame?
    if not Player then return end

    if not GlobalValues.InLevel then
        -- If the place is a LOBBY, send a random lobby spawn
        return LobbySpawns[RNG:NextInteger(1, #LobbySpawns)]
        
    else
        -- If the place is a LEVEL, send an appropriate place to respawn in the level
        -- Still needs to be completed
        return CFrame.new(0, 0, 0)
    end
end

function CoreGameService:CheckRespawnRequest(Player: Player, Delay: number)
    if not Player then return end

    local PValues = PlayerValues[Player]
    if not PValues then return end

    local ContinueSpawning = true

    if PValues.RespawnTime > 0 then
        ContinueSpawning = false
    end

    if Player.Character then
        local Human = Player.Character:FindFirstChild("Humanoid")
        if Human then
            if Human.Health > 0 then
                ContinueSpawning = false
            end
        end
    end

    if ContinueSpawning then
        task.delay(Delay, function()
            SpawnCharacter(Player)
        end)
    end

    return ContinueSpawning
end

function CoreGameService:Init()
    print("Core Game Service Init...")

    SetupLobby()
    SetupCollisions()
    
    Remotes:CreateToClient("DropObject", {})

    Remotes:CreateToServer("RequestSpawnCharacter", {}, "Returns", function(Player: Player, Delay: number)
        return CoreGameService:CheckRespawnRequest(Player, Delay)
    end)

    Remotes:CreateToServer("RequestResetCharacter", {}, "Unreliable", function(Player: Player)
        if not Player then return end
        if not Player.Character then return end
        local Human = Player.Character:FindFirstChild("Humanoid")
        if not Human then return end

        Human.Health = 0
    end)

    Remotes:CreateToServer("ToggleParticles", {"any", "any"}, "Unreliable", function(Player: Player, Parts: {BasePart}, Particles: {{Name: string, Set: boolean}})
        ToggleParticles(Player, Parts, Particles)
    end)
end

function CoreGameService:Deferred()
    print("Core Game Service Deferred...")

    local PlaceId = game.PlaceId

    if PlaceId == 15353246109 then
        return
    end

    --New.Clean(Workspace, "RemoveOnPlay")
    --RandomFunction()
end

function CoreGameService.PlayerAdded(Player: Player)
    CheckLoadLevel(Player)

    PlayerValues[Player] = {
        RespawnTime = 0
    }
    
    Player.CharacterAdded:Connect(function(Character: any)
        CharacterService:SetupCharacter(Player, CoreGameService:RequestSpawnLocation(Player))

        SetupRespawning(Player, Character)
    end)

    if not Players.CharacterAutoLoads then
        SpawnCharacter(Player)
    end

    -- Sometimes Player.CharacterAdded doesn't fire when the player first enters the server
    -- Defer this to make sure LoadCharacter doesn't run twice
    task.defer(function()
        CharacterService:SetupCharacter(Player, CoreGameService:RequestSpawnLocation(Player))
    end)
end

function CoreGameService.PlayerRemoving(Player: Player)
    if not PlayerValues[Player] then return end
    PlayerValues[Player] = nil
end

return CoreGameService