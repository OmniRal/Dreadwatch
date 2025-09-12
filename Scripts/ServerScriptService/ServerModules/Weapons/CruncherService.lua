-- OmniRal

local CruncherService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local WeaponService = require(ServerScriptService.Source.ServerModules.Weapons.WeaponService)
local ProjectileService = require(ServerScriptService.Source.ServerModules.General.ProjectileService)
local HealthService = require(ServerScriptService.Source.ServerModules.General.HealthService)
local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)

local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).Cruncher

local ItemInfo = require(ReplicatedStorage.Source.SharedModules.Info.ItemInfo)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local SHARD_DISTANCE = 200
local SHARD_SPEED = 300
local SHARD_SPREAD = 7

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FiringTasks = {}

local Assets = ServerStorage.Assets
local SharedAssets = ReplicatedStorage.Assets

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Player: Player, WeaponModel: any, Keyframe: string, AnimName: string, Params: {Jar: any})
    if Keyframe == "End" then
        if AnimName == "StartFire" then
            return
        elseif AnimName == "Reloading" then
            WeaponModel.Handle.Ambient.Volume = 0.025
        end

    elseif Keyframe == "GrabJar" then -- 1:03
        Params.Jar.Transparency = 0
        WeaponModel.Handle.GrabJar:Play()

    elseif Keyframe == "StartPouring" then -- 1:31
        Params.Jar.PPoint.Bolts.Enabled = true
        Params.Jar.PPoint.Nails.Enabled = true
        WeaponModel.Handle.Pour:Play()

    elseif Keyframe == "StopPouring" then -- 1:58
        WeaponService:IncrementWeaponMags(Player, "Cruncher", -1, WeaponInfo.MaxMags)
        WeaponService:IncrementWeaponClips(Player, "Cruncher", 30, WeaponInfo.MaxClips)
        WeaponModel.Mags.Value += -1
        WeaponModel.Clips.Value = WeaponInfo.MaxClips

        Params.Jar.PPoint.Bolts.Enabled = false
        Params.Jar.PPoint.Nails.Enabled = false

    elseif Keyframe == "ReleaseJar" then -- 2:25
        Params.Jar.Transparency = 1
        WeaponModel.Handle.ReleaseJar:Play()

    elseif Keyframe == "OpenLid" or Keyframe == "CloseLid" then
        WeaponModel.Handle[Keyframe]:Play()
    end 
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function CruncherService:Shoot(Player: Player, AimTo: CFrame, ThirdPersonCamera: boolean?): number?
    if not Player or not AimTo then return end

    local Character = Player.Character
    if not Character then return end
    local Human, Root, WeaponModel = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Weapon")
    if not Human or not Root or not WeaponModel then return end
    if Human.Health <= 0 then return end

    if WeaponModel.Clips.Value <= 0 and WeaponModel.Mags.Value > 0 then
        -- No clips.
        return 9

    elseif WeaponModel.Clips.Value <= 0 and WeaponModel.Mags.Value <= 0 then
        -- No clips or mags.
        return 8
    end

    WeaponModel.Clips.Value += -1
    WeaponService:IncrementWeaponClips(Player, "Cruncher", -1, WeaponInfo.MaxClips)

    local Shards = Assets.WeaponStuff.Cruncher.Shards

    ProjectileService:New(
        Player, 
        Shards, 
        CFrame.new(WeaponModel.Handle.Position), 
        AimTo, 
        SHARD_SPEED, 
        SHARD_DISTANCE, 
        SHARD_SPREAD, 
        5, 
        1,
        true, 
        function(Owner: Player | Model, Shard: BasePart, Hit: BasePart?) 
             Debris:AddItem(Shard, 3)
             if Hit then
                local HitModel = Hit:FindFirstAncestorOfClass("Model")
                if HitModel then
                    HealthService:ApplyDamage(Player, HitModel, 1, "Cruncher", true)
                else

                end
            end
        end
    )

    WeaponModel.Base.FirePoint.Fire:Emit(1)
    WeaponModel.Hole4.FireLines:Emit(10)
    WeaponModel.Base.FirePoint.FireLight:SetAttribute("Fired", true)
    SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.Fire, 2, 2.05)
    SoundControlService:TweenSoundVolume(WeaponModel.Handle.Shredding, 0.1, 0.25, true)
    WeaponService:ChangeAnimSpeed(WeaponModel, "Base", 3)

    return 1
end

function CruncherService:StopShoot(Player: Player)
    if not Player then return end

    local Character = Player.Character
    if not Character then return end
    local Human, Root, WeaponModel = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Weapon")
    if not Human or not Root or not WeaponModel then return end

    WeaponService:ChangeAnimSpeed(WeaponModel, "Base", 0)
    SoundControlService:TweenSoundVolume(WeaponModel.Handle.Shredding, 0, 0.25, false, false, true)
end

function CruncherService:Reload(Player: Player): number?
    local Character = Player.Character
    if not Character then return end
    local Human, Root, WeaponModel, Jar = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Weapon"), Character:FindFirstChild("Jar")
    if not Human or not Root or not WeaponModel or not Jar then return end
    if Human.Health <= 0 then return end

    if WeaponModel.Mags.Value <= 0 then
        return 9 -- No mags left.
    end
    if WeaponModel.Clips.Value >= WeaponInfo.MaxClips then
        return 8 -- Clips full
    end

    if WeaponModel.Clips.Value > 0 then
        local Time = WeaponModel.Clips.Value * 0.01
        TweenService:Create(WeaponModel.Clips, TweenInfo.new(Time, Enum.EasingStyle.Linear), {Value = 0}):Play()
        WeaponService:ChangeAnimSpeed(WeaponModel, "Base", 0.5)
        WeaponModel.Hole4.Debris.Enabled = true
        task.delay(Time, function()
            WeaponService:ChangeAnimSpeed(WeaponModel, "Base", 0)
            WeaponModel.Hole4.Debris.Enabled = false
        end)
    end

    WeaponService:PlayAnimation(Player, WeaponModel, "Using", "Reloading", true, 1, AnimKeyframes, {Jar = Jar})
    WeaponModel.Handle.Ambient.Volume = 0
    
    return 1
end

function CruncherService:Load(Player: Player, WeaponModel: any)
    if not Player or not WeaponModel then return end
    if not Player.Character then return end

    local RightHand = Player.Character:FindFirstChild("RightHand")
    local LeftHand = Player.Character:FindFirstChild("LeftHand")
    if not RightHand or not LeftHand then return end

    WeaponModel.Handle.Anchored = false
    New.Instance("Weld", WeaponModel, "WeaponWeld", {
        Part0 = RightHand, Part1 = WeaponModel.Handle, C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0), C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)})

    local Jar = Assets.WeaponStuff.Cruncher.Jar:Clone()
    Jar.Transparency = 1
    Jar.Parent = Player.Character
    New.Instance("Weld", Jar, "JarWeld", {
        Part0 = LeftHand, Part1 = Jar, C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0), C1 = CFrame.new(0, -0.1, 0.475) * CFrame.Angles(0, 0, 0)})

    local CurrentAmmo = WeaponService:GetWeaponAmmo(Player, "Cruncher")
    if not CurrentAmmo then
        WeaponService:AddWeaponForAmmo(Player, "Cruncher", WeaponInfo.MaxMags, WeaponInfo.MaxClips)
        CurrentAmmo = {Mags = WeaponInfo.MaxMags, Clips = WeaponInfo.MaxClips}
    end

    local Mags = New.Instance("IntValue", "Mags", WeaponModel, {Value = CurrentAmmo.Mags})
    local Clips = New.Instance("IntValue", "Clips", WeaponModel, {Value = CurrentAmmo.Clips})
    Mags:SetAttribute("Max", WeaponInfo.MaxMags)
    Clips:SetAttribute("Max", WeaponInfo.MaxClips)

    local OffDelay = nil
    WeaponModel.Base.FirePoint.FireLight:SetAttribute("Fired", false)
    WeaponModel.Base.FirePoint.FireLight:GetAttributeChangedSignal("Fired"):Connect(function()
        if not WeaponModel.Base.FirePoint.FireLight:GetAttribute("Fired") then return end
        WeaponModel.Base.FirePoint.FireLight:SetAttribute("Fired", false)
        
        if OffDelay then
            task.cancel(OffDelay)
        end

        WeaponModel.Base.FirePoint.FireLight.Enabled = true
        WeaponModel.Hole4.Color = Color3.fromRGB(244, 130, 29)
        OffDelay = task.delay(0.1, function()
            WeaponModel.Base.FirePoint.FireLight.Enabled = false
            WeaponModel.Hole4.Color = Color3.fromRGB(17, 17, 17)
        end)
    end)

    Assets.WeaponStuff.Cruncher.PPart.FirePoint:Clone().Parent = WeaponModel.Base
    Assets.WeaponStuff.Cruncher.PPart.FireLines:Clone().Parent = WeaponModel.Hole4
    Assets.WeaponStuff.Cruncher.PPart.Debris:Clone().Parent = WeaponModel.Hole4

    WeaponService:LoadAnimations(WeaponModel, "Base", WeaponInfo.ModelAnimations.Base)
    WeaponService:LoadAnimations(WeaponModel, "Using", WeaponInfo.ModelAnimations.Using)
    WeaponService:PlayAnimation(Player, WeaponModel, "Base", "Grinding", false, 0)

    for _, Sound in Assets.WeaponStuff.Cruncher.Sounds:GetChildren() do
        if not Sound then continue end
        Sound:Clone().Parent = WeaponModel.Handle
    end
    WeaponModel.Handle.Ambient:Play()

    return true
end

function CruncherService:Unload(Player: Player, WeaponModel: any)
    if not Player or not WeaponModel then return end
    WeaponService:RemoveWeaponAnimations(WeaponModel)
    New.Clean(Player.Character, "Jar")
    WeaponModel:Destroy()
end

function CruncherService:Init()
    Remotes:CreateToServer("Shoot", {"CFrame", "boolean?"}, "Reliable", function(Player: Player, AimTo: CFrame, ThirdPersonCamera: boolean?)
        CruncherService:Shoot(Player, AimTo, ThirdPersonCamera)
    end)

    Remotes:CreateToServer("StopShoot", {}, "Returns", function(Player: Player)
        CruncherService:StopShoot(Player)
    end)

    Remotes:CreateToServer("Reload", {}, "Returns", function(Player: Player)
        return CruncherService:Reload(Player)
    end)
end

return CruncherService
