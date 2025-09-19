-- OmniRal

local CoreGameService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local CharacterService = require(ServerScriptService.Source.ServerModules.Player.CharacterService)
local RelicService = require(ServerScriptService.Source.ServerModules.General.RelicService)
local BadgeService = require(ServerScriptService.Source.ServerModules.Player.BadgeService)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)
local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)
local HighlightService = require(ReplicatedStorage.Source.SharedModules.Other.HighlightService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerValues = {}
local GrabRequests = {} :: {
    [Player]: {
        Object: any,
        Time: number,
        Status: "Waiting" | "Cancelled" | "Complete" | "Void",
    }
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets
local SharedAssets = ReplicatedStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

function SpawnCharacter(Player: Player)
    if not Player then return end
    Player:LoadCharacter()
end

function ChangeObjectCollisions(Object: any, To: any, SetVelocity: Vector3?)
	for _, Part in pairs(Object:GetChildren()) do
		if ((Part.ClassName == "Part") or (Part.ClassName == "MeshPart")) and (not Part:GetAttribute("NoCollisions")) then
			Part.CanCollide = To
			Part.Massless = not To
			if SetVelocity then
				Part.Velocity = SetVelocity
				Part.RotVelocity = SetVelocity
			end
		end
	end
end

function RandomFunction()

end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function CoreGameService:CheckRespawnRequest(Player: Player, Delay: number)
    if not Player then return end
    if not PlayerValues[Player] then return end
    local ContinueSpawning = true

    if PlayerValues[Player].RespawnTime:Get() > 0 then
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

    Remotes:CreateToServer("RequestResetCharacter", {}, "Reliable", function(Player: Player)
        if not Player then return end
        if not Player.Character then return end
        local Human = Player.Character:FindFirstChild("Humanoid")
        if not Human then return end
        Human.Health = 0
    end)

    Remotes:CreateToServer("RequestSpawnCharacter", {}, "Returns", function(Player: Player, Delay: number)
        return self:CheckRespawnRequest(Player, Delay)
    end)

    Remotes:CreateToServer("ToggleParticles", {"any", "any"}, "Unreliable", function(Player: Player, Parts: {}, Particles: {})
        if not Player then return end

        for _, Part in pairs(Parts) do
            if Part then
                for _, Info in pairs(Particles) do
                    if Part:FindFirstChild(Info.Name) then
                        Part[Info.Name].Enabled = Info.Set
                    end
                end
            end
        end
    end)

    Remotes:CreateToClient("DropObject", {})

    PhysicsService:RegisterCollisionGroup("Players")
    PhysicsService:RegisterCollisionGroup("Logs")
    PhysicsService:RegisterCollisionGroup("NoClip")
    PhysicsService:CollisionGroupSetCollidable("Default", "Players", true)
    PhysicsService:CollisionGroupSetCollidable("Default", "Logs", false)
    PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
    PhysicsService:CollisionGroupSetCollidable("Players", "Logs", false)
    PhysicsService:CollisionGroupSetCollidable("Default", "NoClip", false)
end

function CoreGameService:Deferred()
    print("Core Game Service Deferred...")

    local PlaceId = game.PlaceId

    if PlaceId == 15353246109 then
        return
    end

    New.Clean(Workspace, "RemoveOnPlay")
    --RandomFunction()
end

function CoreGameService.PlayerAdded(Player: Player)
    PlayerValues[Player] = {
        --RespawnTime = New.Var(0)
    }
    Player.CharacterAdded:Connect(function(Character: any)
        CharacterService:LoadCharacter(Player)
        RelicService:UpdatePlayerAttributes(Player)


        --[[local Root = Character:WaitForChild("HumanoidRootPart")
        for _, Sound in pairs(Assets.Misc.CharacterSounds:GetChildren()) do
            print(Sound.Name, " added to ", Player.Name)
            Sound:Clone().Parent = Root
        end]]
        --[[local Human = Character:WaitForChild("Humanoid")
        PlayerValues[Player].DeathConnection = Human.Died:Connect(function()
            task.spawn(function()
                PlayerValues[Player].RespawnTime:Set(Players.RespawnTime)
                for x = Players.RespawnTime, 0, -1 do
                    task.wait(1)
                    PlayerValues[Player].RespawnTime:Set(x)
                end
                SpawnCharacter(Player)
                PlayerValues[Player].DeathConnection:Disconnect()
                PlayerValues[Player].DeathConnection = nil
            end)
        end)]]
    end)
    --SpawnCharacter(Player)

    CharacterService:LoadCharacter(Player)
    RelicService:UpdatePlayerAttributes(Player)
end

function CoreGameService.PlayerRemoving(Player: Player)
    if PlayerValues[Player] then
        PlayerValues[Player] = nil
    end
end

return CoreGameService