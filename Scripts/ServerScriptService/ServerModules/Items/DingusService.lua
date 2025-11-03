-- OmniRal

local DingusService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local RelicInfo = require(ReplicatedStorage.Source.SharedModules.Info.RelicInfo).Dingus

local AbilityService = require(ServerScriptService.Source.ServerModules.General.AbilityService)
local ProjectileService = require(ServerScriptService.Source.ServerModules.General.ProjectileService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FIRE_DISTANCE = 50
local FIRE_SPEED = 50
local FIRE_SPREAD = 1

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets.RelicStuff.Dingus
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function DingusService:UseActive(Player: Player, ShootStart: Vector3, ShootGoal: Vector3): number
    if AbilityService:OnCooldown(Player, "Dingus", "Active") then return CustomEnum.ReturnCodes.OnCooldown end

    AbilityService:SetCooldown(Player, "Dingus", "Active")

    ProjectileService:New(
        Player, 
        ShootStart, 
        ShootGoal, 
        0, 
        {Assets.Ball}, 
        CFrame.new(0, 0, 0),
        FIRE_SPEED, 
        FIRE_DISTANCE, 
        1, 
        true, 
        function(Owner: Player | Model, Ball: BasePart, Hit: BasePart?) 
            Debris:AddItem(Ball, 3)
            Ball.Transparency = 1
            
            if Hit then
                local HitModel = Hit:FindFirstAncestorOfClass("Model")
                if HitModel then
                    if HitModel:FindFirstChild("Humanoid") then
                        local Damage = RNG:NextInteger(RelicInfo.Ability.Damage.Min, RelicInfo.Ability.Damage.Max)
                        HitModel.Humanoid:TakeDamage(Damage)
                    end
                    --HealthService:ApplyDamage(Player, HitModel, 1, "Brighton", true)
                end
            end
        end
    )

    return 1
end

function DingusService:Init()
	print("DingusService initialized...")
end

function DingusService:Deferred()
    print("DingusService deferred...")
end

return DingusService