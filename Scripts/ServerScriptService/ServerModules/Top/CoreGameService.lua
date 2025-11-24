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

local LevelService = require(ServerScriptService.Source.ServerModules.General.LevelService)
local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local ServerGlobalValues = require(ServerScriptService.Source.ServerModules.Top.ServerGlobalValues)
local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

local SignalService = require(ServerScriptService.Source.ServerModules.General.SignalService)
local CharacterService = require(ServerScriptService.Source.ServerModules.Player.CharacterService)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerDied = SignalService.PlayerDied

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlaceSetupStarted = false
local PlaceSetupComplete = false

local PlayerOrder: {Player} = {}
local PlayerValues: {
    [Player]: {
        RespawnTime: number,
        LastDiedLocation: CFrame?,
    }
} = {}
local HandlingPlayerLeaving = false

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
            if ServerGlobalValues.InLevel and not ServerGlobalValues.AllowLevelRespawning then return end

            PValues.RespawnTime = Players.RespawnTime

            for x = Players.RespawnTime, 0, -1 do
                task.wait(1)
                PValues.RespawnTime -= 1
            end

            SpawnCharacter(Player)

            PValues.DeathConnection:Disconnect()
            PValues.DeathConnection = nil
        end)

        PlayerDied:Fire(Player)
    end)
end

-- Checks to see to decide if the place will be a lobby or a level based on the first players join data
local function CheckLoadLevel(Player: Player): (boolean, number?)
    if PlaceSetupStarted or PlaceSetupComplete then return false end
    if not Player then return false end

    PlaceSetupStarted = true

    local JoinData = Player:GetJoinData()
    if not JoinData then
        -- No join data exists, assume its a lobby
        PlaceSetupComplete = true
        return true
    end

    if ServerGlobalValues.StartLevelInfo.TestingMode and not ServerGlobalValues.StartLevelInfo.TestWithoutPlayers then
        PlaceSetupComplete = true
        return true, ServerGlobalValues.StartLevelInfo.ID
    end

    print("Got join data from", Player, " :", JoinData)

    local TeleportData: CustomEnum.TeleportData = JoinData.TeleportData
    if not TeleportData then return false end
    if not TeleportData.MissionID or not TeleportData.ExpectedPlayers then return false end
    -- May need fail safe here if a players teleport data is corrupted; send them back to their lobby ideally

    PlaceSetupComplete = true

    return true, TeleportData.MissionID
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

function CoreGameService:RequestSpawnLocation(Player: Player, BeingRevived: boolean?): CFrame?
    if not Player then return end
    local PValues = PlayerValues[Player]
    if not PValues then return end

    if not ServerGlobalValues.InLevel then
        -- If the place is a LOBBY, send a random lobby spawn
        return LobbySpawns[RNG:NextInteger(1, #LobbySpawns)]
        
    else
        -- If the place is a LEVEL, send an appropriate place to respawn in the level
        local RespawnHere = CFrame.new(0, 0, 0)
        local CurrentLevel = ServerGlobalValues.CurrentLevel
        local Order_ID = Player:GetAttribute("Order_ID") :: number?

        if CurrentLevel and CurrentLevel.AvailableSpawns and Order_ID then
            RespawnHere = CurrentLevel.AvailableSpawns[Order_ID] -- Make sure the players who are respawning at the same time, never spawn ontop of each other
        end

        if BeingRevived then
            RespawnHere = PValues.LastDiedLocation
        end

        return RespawnHere
    end
end

-- Handle when the player requests to the server to respawn
function CoreGameService:RequestSpawning(Player: Player, Delay: number): boolean
    if not Player then return false end

    local PValues = PlayerValues[Player]
    if not PValues then return false end

    if PValues.RespawnTime > 0 then return false end -- If there's time left in respawning, deny request

    if Player.Character then
        local Human = Player.Character:FindFirstChild("Humanoid")
        if Human and Human.Health > 0 then
           return false -- If the player is alive, deny request
        end
    end

    task.delay(Delay, function()
        SpawnCharacter(Player)
    end)

    return true
end

function CoreGameService:Init()
    print("Core Game Service Init...")

    SetupLobby()
    SetupCollisions()
    
    Remotes:CreateToClient("DropObject", {})

    Remotes:CreateToServer("RequestSpawning", {}, "Returns", function(Player: Player, Delay: number)
        return CoreGameService:RequestSpawning(Player, Delay)
    end)

    Remotes:CreateToServer("RequestResetCharacter", {}, "Unreliable", function(Player: Player)
        if not Player or not Player.Character then return end
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

    if ServerGlobalValues.CleanupAssetDump then
        New.Clean(Workspace, "AssetDump")
    end

    Utility:ChangeModelTransparency(Workspace.TempRoom, 1)

    --RandomFunction()
end

function CoreGameService.PlayerAdded(Player: Player)
    table.insert(PlayerOrder, Player)

    local CreateNew, ID = CheckLoadLevel(Player)
    if CreateNew then
        ServerGlobalValues.InLevel = true
        Workspace.Lobby:Destroy() -- Get rid of the entire lobby folder
        warn("PLAYER ORDER:", PlayerOrder)
        LevelService.LoadLevel(PlayerOrder, ID)
    end

    local Order_ID = table.find(PlayerOrder, Player) -- Incase two players enter at the same time
    Player:SetAttribute("Order_ID", Order_ID)

    PlayerValues[Player] = {
        RespawnTime = 0,
        LastDiedLocation = nil,
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
        SetupRespawning(Player, Player.Character)
    end)
end

function CoreGameService.PlayerRemoving(Player: Player)
    task.spawn(function()
        while HandlingPlayerLeaving do task.wait() end -- Prevent player order from getting messed up when two players may leave at the same time
        HandlingPlayerLeaving = true

        local Index = table.find(PlayerOrder, Player)
        if Index then
            table.remove(PlayerOrder, Index)
        end

        if PlayerValues[Player] then
            PlayerValues[Player] = nil
        end

        HandlingPlayerLeaving = false
    end)
end

return CoreGameService