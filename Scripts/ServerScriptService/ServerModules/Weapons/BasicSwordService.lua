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

local ModService = require(ServerScriptService.Source.ServerModules.General.ModService)
local WeaponService = require(ServerScriptService.Source.ServerModules.General.WeaponService)
local UnitManagerService = require(ServerScriptService.Source.ServerModules.General.UnitManagerService)
local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)

local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).BasicSword
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

function BasicSwordService:Use(Player: Player, SwingNum: number, HitList: {Model}): number?
    if not Player or not SwingNum or not HitList then return end

    for _, Unit in HitList do
        if not Unit then continue end
        ModService:RunThroughMods(
            Player,
            function()
                UnitManagerService:ApplyDamage(Player, Unit, RNG:NextInteger(WeaponInfo.Damage.Min, WeaponInfo.Damage.Max), "BasicSword")
            end,
            Unit.HumanoidRootPart.Position
        )
        
    end

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
    local MagSkin = Assets.Mags:FindFirstChild(SkinName)
    if not RightHand or not LeftHand or not MagSkin then return end

    WeaponModel.Handle.Anchored = false
    New.Instance("Weld", WeaponModel, "WeaponWeld", {
        Part0 = RightHand, Part1 = WeaponModel.Handle, C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0), C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)})

    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------

    for _, Sound in Assets.Sounds:GetChildren() do
        if not Sound then continue end
        Sound:Clone().Parent = WeaponModel.Handle
    end
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

    Remotes:CreateToServer("StopUse", {}, "Returns", function(Player: Player)
        BasicSwordService:StopUse(Player)
    end)
end

return BasicSwordService
