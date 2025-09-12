-- OmniRal
--!nocheck

local TestBot = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Unit = require(ServerScriptService.Source.ServerModules.Classes.Unit)
local UnitInfo = require(ServerScriptService.Source.ServerModules.Info.UnitInfo).TestBot

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local SHOT_STEPS = 10
local SHOT_RANGE = 100
local SHOT_SPEED = 60

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Unit: Unit.Unit, AnimName: string, Keyframe: string)
    if Keyframe == "End" then
        return
    
    elseif Keyframe == "Damage" and AnimName == "Melee_Attack" then
        if not Unit.Root or not Unit.Target then return end
        if not Unit.Target.Human or not Unit.Target.Root then return end
        
        local AttackInfo = UnitInfo.EnemyStats.Attacks.Melee_Attack
        local Distance = (Unit.Root.Position - Unit.Target.Root.Position).Magnitude
        
        if Distance > AttackInfo.DamageRange then return end

        Unit.Target.Human:TakeDamage(RNG:NextNumber(AttackInfo.Damage.Min, AttackInfo.Damage.Max))

    elseif Keyframe == "Shoot" then
        local Shot = Instance.new("Part")
        Shot.Name = "Shot"
        Shot.Anchored = true
        Shot.CanCollide = false
        Shot.CanQuery = false
        Shot.CanTouch = false
        Shot.Material = Enum.Material.Neon
        Shot.Color = Color3.fromRGB(255, 50, 50)
        Shot.Shape = Enum.PartType.Ball
        Shot.Size = Vector3.new(1, 1, 1)
        Shot.CFrame = Unit.Root.CFrame * CFrame.new(0, 0.5, -1)
        Shot.Parent = Workspace

        local Direction = (Unit.Target.Root.Position - Unit.Root.Position).Unit

        local Params = RaycastParams.new()
        Params.FilterDescendantsInstances = {Unit}
        Params.FilterType = Enum.RaycastFilterType.Exclude
        Params.IgnoreWater = true

        task.spawn(function()
            local Hit = nil

            for x = 1, SHOT_STEPS do
                local Goal = CFrame.new(Shot.Position + (Direction * (SHOT_RANGE / SHOT_STEPS)))
                local Ray = Workspace:Raycast(Shot.Position, Direction * (SHOT_RANGE / SHOT_STEPS), Params)
                
                if Ray then
                    if Ray.Instance then
                        Hit = Ray.Instance
                        Goal = CFrame.new(Ray.Position)
                    end
                end

                local Distance = (Shot.Position - Goal.Position).Magnitude
                local TravelTime = Distance / SHOT_SPEED
                TweenService:Create(Shot, TweenInfo.new(TravelTime), {CFrame = Goal}):Play()
                task.wait(TravelTime)

                if not Hit then continue end

                break
            end

            if Hit then
                local Model = Hit:FindFirstAncestorWhichIsA("Model") 
                if Model then
                    if Model:FindFirstChild("Humanoid") then
                        local Damage = RNG:NextInteger(UnitInfo.EnemyStats.Attacks.Ranged_Attack.Damage.Min, UnitInfo.EnemyStats.Attacks.Ranged_Attack.Damage.Max)
                        Model.Humanoid:TakeDamage(Damage)
                    end
                end
            end

            Shot:Destroy()
        end)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function TestBot.Melee_Attack(Unit: Unit.Unit)
    warn("Melee attack!")
    Unit:PlayActionAnimation("Melee_Attack", nil, nil, AnimKeyframes)
end

function TestBot.Ranged_Attack(Unit: Unit.Unit)
    warn("Ranged attack!")
    Unit:PlayActionAnimation("Ranged_Attack", nil, nil, AnimKeyframes)
end

return TestBot