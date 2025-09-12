-- OmniRal

local RustyService = {}

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
local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).Cruncher
local ItemInfo = require(ReplicatedStorage.Source.SharedModules.Info.ItemInfo)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local WeaponService = require(ServerScriptService.Source.ServerModules.Weapons.WeaponService)
local ProjectileService = require(ServerScriptService.Source.ServerModules.General.ProjectileService)
local HealthService = require(ServerScriptService.Source.ServerModules.General.HealthService)
local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)

local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local SWING_INFO = {
    {Damage = 10, Range = 9},
    {Damage = 7, Range = 8},
    {Damage = 8, Range = 8}
} :: {{Damage: number, Range: number}}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FiringTasks = {}

local Assets = ServerStorage.Assets
local SharedAssets = ReplicatedStorage.Assets

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Player: Player, WeaponModel: any, Keyframe: string, AnimName: string, Params: {Jar: any})

end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RustyService:Swing(Player: Player, AimTo: CFrame, ThirdPersonCamera: boolean?): number?
    if not Player or not AimTo then return end

    local Character = Player.Character
    if not Character then return end
    local Human, Root, WeaponModel = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Weapon")
    if not Human or not Root or not WeaponModel then return end
    if Human.Health <= 0 then return end

    return 1
end

function RustyService:Hit(Player: Player, SwingNum: number)
    if not Player or not SwingNum then return end
    if not Player.Character then return end
    local Root = Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
    if not Root then return end
    
    local FrontCFrame = Root.CFrame * CFrame.new(0, 0, -2)
    local Damage, Range = SWING_INFO[SwingNum].Damage, SWING_INFO[SwingNum].Range

    local BotHitList, ItemHitList = Utility:CheckForUnits("Bots", {}, FrontCFrame, Range), Utility:CheckForItems({}, FrontCFrame, Range)
    
    if #BotHitList > 0 then

    end

    if #ItemHitList > 0 then
        for _, Item in ItemHitList do
            if not Item then continue end
            HealthService:ApplyDamage(Player, Item, Damage, "Rusty")
        end
    end
end

function RustyService:Load(Player: Player, WeaponModel: any)
    if not Player or not WeaponModel then return end
    if not Player.Character then return end

    local RightHand = Player.Character:FindFirstChild("RightHand")
    local LeftHand = Player.Character:FindFirstChild("LeftHand")
    if not RightHand or not LeftHand then return end

    WeaponModel.Handle.Anchored = false
    New.Instance("Weld", WeaponModel, "WeaponWeld", {
        Part0 = RightHand, Part1 = WeaponModel.Handle, C0 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0), C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)})

    local Mags = New.Instance("IntValue", "Mags", WeaponModel, {Value = -2})
    local Clips = New.Instance("IntValue", "Clips", WeaponModel, {Value = -2})
    Mags:SetAttribute("Max", WeaponInfo.MaxMags)
    Clips:SetAttribute("Max", WeaponInfo.MaxClips)

    --[[for _, Sound in Assets.WeaponStuff.Cruncher.Sounds:GetChildren() do
        if not Sound then continue end
        Sound:Clone().Parent = WeaponModel.Handle
    end
    WeaponModel.Handle.Ambient:Play()]]

    return true
end

function RustyService:Unload(Player: Player, WeaponModel: any)
    if not Player or not WeaponModel then return end
    WeaponService:RemoveWeaponAnimations(WeaponModel)
    WeaponModel:Destroy()
end

function RustyService:Init()
    Remotes:CreateToServer("Swing", {"CFrame", "boolean?"}, "Reliable", function(Player: Player, AimTo: CFrame, ThirdPersonCamera: boolean?)
        RustyService:Swing(Player, AimTo, ThirdPersonCamera)
    end)

    Remotes:CreateToServer("Hit", {"number"}, "Reliable", function(Player: Player, SwingNum: number)
        RustyService:Hit(Player, SwingNum)
    end)
end

return RustyService
