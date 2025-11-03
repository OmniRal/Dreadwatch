-- OmniRal

local BasicSwordService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).BasicSword

local RelicService = require(ServerScriptService.Source.ServerModules.General.RelicService)
local WeaponService = require(ServerScriptService.Source.ServerModules.General.WeaponService)
local AbilityService = require(ServerScriptService.Source.ServerModules.General.AbilityService)
local UnitValuesService = require(ServerScriptService.Source.ServerModules.General.UnitValuesService)
local UnitManagerService = require(ServerScriptService.Source.ServerModules.General.UnitManagerService)
local ProjectileService = require(ServerScriptService.Source.ServerModules.General.ProjectileService)
local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FIRE_DISTANCE = 50
local FIRE_SPEED = 50
local FIRE_SPREAD = 1

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerWeaponValues: {
    [Player]: {
        ShootStart: Vector3,
        ShootGoal: Vector3,
        ConsecutiveHits: number,
    }
} = {}

local Assets = ServerStorage.Assets.WeaponStuff.BasicSword
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Player: Player, WeaponModel: any, Keyframe: string, AnimName: string, Params: {})
    if Keyframe == "End" then
        return

    elseif Keyframe == "Shoot" then
        
        ProjectileService:New(
            Player, 
            PlayerWeaponValues[Player].ShootStart, 
            PlayerWeaponValues[Player].ShootGoal, 
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
                            local Damage = RNG:NextInteger(WeaponInfo.Damage.Min, WeaponInfo.Damage.Max)
                            HitModel.Humanoid:TakeDamage(Damage)
                        end
                        --HealthService:ApplyDamage(Player, HitModel, 1, "Brighton", true)
                    end
                end
            end
        )
    
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function BasicSwordService:Use(Player: Player, SwingNum: number, HitList: {Model}): number?
    if not Player or not SwingNum or not HitList then return end

    local DamageOffset = UnitValuesService:GetAttributes(Player, "Damage")

    for _, Unit in HitList do
        if not Unit then continue end
        RelicService:RunThroughMods(
            Player,
            function()
                UnitManagerService:ApplyDamage(Player, Unit, RNG:NextInteger(WeaponInfo.Damage.Min, WeaponInfo.Damage.Max) + DamageOffset, "BasicSword")
            end,
            Unit.HumanoidRootPart.Position
        )

        PlayerWeaponValues[Player].ConsecutiveHits += 1
        if PlayerWeaponValues[Player].ConsecutiveHits >= 4 then
                PlayerWeaponValues[Player].ConsecutiveHits = 0
            if BasicSwordService:UseAwakened(Player) == 1 then
                Unit.HumanoidRootPart.AssemblyLinearVelocity += Vector3.new(0, 100, 0)
            end
        end
    end

    return 1
end

function BasicSwordService:UseInnate(Player: Player): number
    local Alive, _, Root, WeaponModel = Utility:CheckPlayerAlive(Player, {"Weapon"})
    if not Alive or not WeaponModel then return -9 end -- Dead
    if AbilityService:OnCooldown(Player, "BasicSword", "Innate") then return -8 end -- On cooldown

    PlayerWeaponValues[Player].ShootStart = Root.Position
    PlayerWeaponValues[Player].ShootGoal = (Root.CFrame * CFrame.new(0, 0, -50)).Position

    AbilityService:SetCooldown(Player, "BasicSword", "Innate")
    WeaponService:PlayAnimation(Player, WeaponModel, "Using", "Innate", true, 1, AnimKeyframes, {})

    return 1
end

function BasicSwordService:UseAwakened(Player: Player)
    if AbilityService:OnCooldown(Player, "BasicSword", "Awakened") then return -8 end -- On cooldown

    AbilityService:SetCooldown(Player, "BasicSword", "Awakened")

    return 1
end

function BasicSwordService:StopUse(Player: Player): number?
    print("Stopped using")

    return 1
end

function BasicSwordService:Load(Player: Player, WeaponModel: any, SkinName: string)
    if not Player or not WeaponModel then return end
    if not Player.Character then return end

    local RightHand = Player.Character:FindFirstChild("RightHand")
    local LeftHand = Player.Character:FindFirstChild("LeftHand")
    if not RightHand or not LeftHand then return end

    WeaponModel.Handle.Anchored = false
    New.Instance("Weld", WeaponModel, "WeaponWeld", {
        Part0 = RightHand, Part1 = WeaponModel.Handle, C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0), C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)})

    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------

    --[[for _, Sound in Assets.Sounds:GetChildren() do
        if not Sound then continue end
        Sound:Clone().Parent = WeaponModel.Handle
    end]]

    WeaponService:LoadAnimations(WeaponModel, "Using", WeaponInfo.ModelAnimations.Using)

    ---------------------------------------------------------------------------

    return true
end

function BasicSwordService:Unload(Player: Player, WeaponModel: any)
    if not Player or not WeaponModel then return end
    WeaponService:RemoveWeaponAnimations(WeaponModel)
    WeaponModel:Destroy()
end

function BasicSwordService:Init()
    Remotes:CreateToServer("Use", {"number", "table"}, "Reliable", function(Player: Player, SwingNum: number, HitList: {Model})
        BasicSwordService:Use(Player, SwingNum, HitList)
    end)

    Remotes:CreateToServer("StopUse", {}, "Reliable", function(Player: Player)
        BasicSwordService:StopUse(Player)
    end)

    Remotes:CreateToServer("UseAbility", {"number"}, "Returns", function(Player: Player, AbilityNum: number)
        if AbilityNum == 1 then
            return BasicSwordService:UseInnate(Player)

        else
            return BasicSwordService:UseAwakened(Player)
        end
    end)
end

function BasicSwordService.PlayerAdded(Player: Player)
    PlayerWeaponValues[Player] = {
        ShootStart = Vector3.zero,
        ShootGoal = Vector3.zero,
        ConsecutiveHits = 0,
    }
end   
    
function BasicSwordService.PlayerRemoving(Player: Player)
    if not PlayerWeaponValues[Player] then return end
    PlayerWeaponValues[Player] = nil
end

return BasicSwordService
