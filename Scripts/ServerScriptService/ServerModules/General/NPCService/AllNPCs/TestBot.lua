-- OmniRal
--!nocheck

local TestBot = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local NPC = require(ServerScriptService.Source.ServerModules.Classes.NPC)
local NPCInfo = require(ServerScriptService.Source.ServerModules.Info.NPCInfo).TestBot
local NPCService = require(ServerScriptService.Source.ServerModules.General.NPCService)

local UnitManagerService = require(ServerScriptService.Source.ServerModules.General.UnitManagerService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local SHOT_STEPS = 10
local SHOT_RANGE = 100
local SHOT_SPEED = 60

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(NPC: NPC.NPC, AnimName: string, Keyframe: string)
    if Keyframe == "End" then
        return
    
    elseif Keyframe == "Damage" and AnimName == "Melee_Attack" then
        if not NPC.Root or not NPC.Target then return end
        if not NPC.Target.Human or not NPC.Target.Root then return end
        
        local AttackInfo = NPCInfo.EnemyStats.Attacks.Melee_Attack
        local Distance = (NPC.Root.Position - NPC.Target.Root.Position).Magnitude
        
        if Distance > AttackInfo.DamageRange then return end

        --UnitManagerService:ApplyDamage(NPC.Model, NPC.Target.Player or NPC.Target.Model, RNG:NextNumber(AttackInfo.Damage.Min, AttackInfo.Damage.Max), "Basic Swipe")
        --NPC.Target.Human:TakeDamage(RNG:NextNumber(AttackInfo.Damage.Min, AttackInfo.Damage.Max))

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
        Shot.CFrame = NPC.Root.CFrame * CFrame.new(0, 0.5, -1)
        Shot.Parent = Workspace

        local Direction = (NPC.Target.Root.Position - NPC.Root.Position).NPC

        local Params = RaycastParams.new()
        Params.FilterDescendantsInstances = {NPC}
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
                        local Damage = RNG:NextInteger(NPCInfo.EnemyStats.Attacks.Ranged_Attack.Damage.Min, NPCInfo.EnemyStats.Attacks.Ranged_Attack.Damage.Max)
                        --Model.Humanoid:TakeDamage(Damage)
                        NPCService:ApplyDamage(NPC.Model, Model, Damage, "Jizzed")
                    end
                end
            end

            Shot:Destroy()
        end)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function TestBot.Melee_Attack(NPC: NPC.NPC)
    --warn("Melee attack!")
    NPC:PlayActionAnimation("Melee_Attack", nil, nil, AnimKeyframes)
end

function TestBot.Ranged_Attack(NPC: NPC.NPC)
    --warn("Ranged attack!")
    NPC:PlayActionAnimation("Ranged_Attack", nil, nil, AnimKeyframes)
end

return TestBot