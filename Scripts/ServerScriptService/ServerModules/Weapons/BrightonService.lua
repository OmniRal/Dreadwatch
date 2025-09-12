-- OmniRal

local BrightonService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).Brighton

local WeaponService = require(ServerScriptService.Source.ServerModules.Weapons.WeaponService)
local ProjectileService = require(ServerScriptService.Source.ServerModules.General.ProjectileService)
local HealthService = require(ServerScriptService.Source.ServerModules.General.HealthService)
local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FIRE_DISTANCE = 200
local FIRE_SPEED = 300
local FIRE_SPREAD = 1

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets.WeaponStuff.Brighton

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Player: Player, WeaponModel: any, Keyframe: string, AnimName: string, Params: {HandMag: any})
    if Keyframe == "End" then
        return

    elseif Keyframe == "GrabMag" then
        SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.GrabNewMag, 1.1, 1.15)
    
    elseif Keyframe == "PullMag" then
        WeaponModel.MagBase.Transparency = 1
        WeaponModel.MagEnd.Transparency = 1
        Utility:ChangeModelTransparency(Params.HandMag, 0) 
        SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.PullOldMag, 1.25, 1.3)

    elseif Keyframe == "ThrowMag" then
        if Player.Character then
            local Root = Player.Character:FindFirstChild("HumanoidRootPart")
            if Root then
                task.delay(0.1, function()
                    local Copy = Params.HandMag:Clone()
                    Copy.PrimaryPart.AssemblyLinearVelocity = (Root.CFrame * CFrame.new(0, -math.pi / 3, 0)).LookVector * -40 + Vector3.new(0, 10, 0)
                    Copy.Parent = Workspace.Debris

                    New.Clean(Copy, "MagWeld")
                    for _, Part: BasePart in Copy:GetChildren() do
                        Part.CanCollide = true
                        Part.CollisionGroup = "Debris"
                    end

                    Utility:ChangeModelTransparency(Params.HandMag, 1)
                end)
            end
        end
        SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.ThrowOldMag, 2, 2.05)

    elseif Keyframe == "CheckPocket" then
        SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.CheckPocket, 1.2, 1.25)
    
    elseif Keyframe == "GotNewMag" then
        if Params.HandMag then
            Utility:ChangeModelTransparency(Params.HandMag, 0)
        end
        --SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.GotNewMag, 1, 1.05)

    elseif Keyframe == "NewMag" then
        SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.GotNewMag, 2, 2.05)

    elseif Keyframe == "InsertMag" then
        WeaponService:IncrementWeaponMags(Player, "Brighton", -1, WeaponInfo.MaxMags)
        WeaponService:IncrementWeaponClips(Player, "Brighton", 30, WeaponInfo.MaxClips)
        WeaponModel.Mags.Value += -1
        WeaponModel.Clips.Value = WeaponInfo.MaxClips

        WeaponModel.MagBase.Transparency = 0
        WeaponModel.MagEnd.Transparency = 0
        Utility:ChangeModelTransparency(Params.HandMag, 1)

        SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.InsertNewMag, 1.2, 1.25)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function BrightonService:Shoot(Player: Player, AimTo: Vector3, Spread: number, CameraCF: CFrame, ThirdPersonCamera: boolean?): number?
    if not Player or not AimTo then return end

    local Character = Player.Character
    if not Character then return end
    local Human, Root, WeaponModel = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Weapon")
    if not Human or not Root or not WeaponModel then return end
    if Human.Health <= 0 then return end

    if WeaponModel.Clips.Value <= 0 and WeaponModel.Mags.Value > 0 then return 9 end -- No clips
    if WeaponModel.Clips.Value <= 0 and WeaponModel.Mags.Value <= 0 then return 8 end -- No clips or mags

    WeaponModel.Clips.Value += -1
    WeaponService:IncrementWeaponClips(Player, "Brighton", -1, WeaponInfo.MaxClips)

    ProjectileService:New(
        Player, 
        WeaponModel.Tip.Position, 
        AimTo, 
        Spread, 
        {Assets.Bullet}, 
        CameraCF,
        FIRE_SPEED, 
        FIRE_DISTANCE, 
        1, 
        true, 
        function(Owner: Player | Model, Shard: BasePart, Hit: BasePart?) 
             Debris:AddItem(Shard, 3)

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

    WeaponModel:SetAttribute("Fired", 1)

    return 1
end

function BrightonService:StopShoot(Player: Player)
    if not Player then return end

    local Character = Player.Character
    if not Character then return end
    local Human, Root, WeaponModel = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Weapon")
    if not Human or not Root or not WeaponModel then return end
end

function BrightonService:Reload(Player: Player): number?
    local Character = Player.Character
    if not Character then return end
    local Human, Root, WeaponModel, HandMag = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Weapon"), Character:FindFirstChild("BrightonMag")
    if not Human or not Root or not WeaponModel or not HandMag then return end
    if Human.Health <= 0 then return end

    if WeaponModel.Mags.Value <= 0 then
        return 9 -- No mags left.
    end
    if WeaponModel.Clips.Value >= WeaponInfo.MaxClips then
        return 8 -- Clips full
    end

    WeaponModel.Clips.Value = 0

    WeaponService:PlayAnimation(Player, WeaponModel, "Using", "Reloading", true, 1, AnimKeyframes, {HandMag = HandMag})
    
    return 1
end

function BrightonService:Load(Player: Player, WeaponModel: any, SkinName: string)
    if not Player or not WeaponModel then return end
    if not Player.Character then return end

    local RightHand = Player.Character:FindFirstChild("RightHand")
    local LeftHand = Player.Character:FindFirstChild("LeftHand")
    local MagSkin = Assets.Mags:FindFirstChild(SkinName)
    if not RightHand or not LeftHand or not MagSkin then return end

    WeaponModel.Handle.Anchored = false
    New.Instance("Weld", WeaponModel, "WeaponWeld", {
        Part0 = RightHand, Part1 = WeaponModel.Handle, C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0), C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)})

    local HandMag = MagSkin:Clone()
    HandMag.Name = "BrightonMag"
    HandMag.Parent = Player.Character
    Utility:ChangeModelTransparency(HandMag, 1)
    New.Instance("Weld", HandMag, "MagWeld", {
        Part0 = LeftHand, Part1 = HandMag.Handle, C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0), C1 = CFrame.new(0, -0.25, 0.25)
    })

    ---------------------------------------------------------------------------

    local CurrentAmmo = WeaponService:GetWeaponAmmo(Player, "Brighton")
    if not CurrentAmmo then
        WeaponService:AddWeaponForAmmo(Player, "Brighton", WeaponInfo.MaxMags, WeaponInfo.MaxClips)
        CurrentAmmo = {Mags = WeaponInfo.MaxMags, Clips = WeaponInfo.MaxClips}
    end

    local Mags = New.Instance("IntValue", "Mags", WeaponModel, {Value = CurrentAmmo.Mags})
    local Clips = New.Instance("IntValue", "Clips", WeaponModel, {Value = CurrentAmmo.Clips})
    Mags:SetAttribute("Max", WeaponInfo.MaxMags)
    Clips:SetAttribute("Max", WeaponInfo.MaxClips)

    ---------------------------------------------------------------------------

    local FPDelay: thread? = nil
    local FirePoint = Assets.PPart.FirePoint:Clone()
    FirePoint.Parent = WeaponModel.Tip

    for _, Sound in Assets.Sounds:GetChildren() do
        if not Sound then continue end
        Sound:Clone().Parent = WeaponModel.Handle
    end

    WeaponService:LoadAnimations(WeaponModel, "Using", WeaponInfo.ModelAnimations.Using)

    ---------------------------------------------------------------------------

    WeaponModel:SetAttribute("Fired", 0)
    WeaponModel:GetAttributeChangedSignal("Fired"):Connect(function()
        if WeaponModel:GetAttribute("Fired") == 0 then
            return
        else
            WeaponModel:SetAttribute("Fired", 0)

            if FPDelay then
                task.cancel(FPDelay)
            end

            FirePoint.Fire:Emit(1)
            FirePoint.Shards:Emit(20)
            FirePoint.FireLight.Enabled = true
            WeaponModel.Tip.Color = Color3.fromRGB(244, 130, 29)

            SoundControlService:PlaySoundWithRNG(WeaponModel.Handle.Fire, 1.5, 1.55)

            FPDelay = task.delay(0.1, function()
                FirePoint.FireLight.Enabled = false
                WeaponModel.Tip.Color = Color3.fromRGB(17, 17, 17)
            end)
        end
    end)

    return true
end

function BrightonService:Unload(Player: Player, WeaponModel: any)
    if not Player or not WeaponModel then return end
    WeaponService:RemoveWeaponAnimations(WeaponModel)
    WeaponModel:Destroy()
end

function BrightonService:Init()
    Remotes:CreateToServer("Shoot", {"Vector3", "number", "CFrame", "boolean?"}, "Reliable", function(Player: Player, AimTo: Vector3, Spread: number, CameraCF: CFrame, FirstOrThirdPerson: boolean?)
        BrightonService:Shoot(Player, AimTo, Spread, CameraCF, FirstOrThirdPerson)
    end)

    Remotes:CreateToServer("StopShoot", {}, "Returns", function(Player: Player)
        BrightonService:StopShoot(Player)
    end)

    Remotes:CreateToServer("Reload", {}, "Returns", function(Player: Player)
        return BrightonService:Reload(Player)
    end)
end

return BrightonService
