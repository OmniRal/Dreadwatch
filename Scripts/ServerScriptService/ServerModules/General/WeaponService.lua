-- OmniRal

local WeaponService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local WeapnEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.WeaponEnum)
local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo)

local WeaponModules = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerAmmo : {
    [Player]: {[string]: {Mags: number, Clips: number}}
} = {}

local WeaponAnims : {
    [Model]: {
        [string]: {
            Tracks: {[string]: {Track: any, Set: boolean}},
            CurrentTrack: any,
            CanPlay: boolean,
        }
    }
} = {}

local Assets = ReplicatedStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function SetTestButtons()
    for _, Button in Workspace.WeaponButtons:GetChildren() do
        local Debounce, BaseColor = false, Button.BrickColor

        Button.Touched:Connect(function(Hit: any)
            if Debounce then return end
            if not Hit.Parent then return end
            if not Hit.Parent:FindFirstChild("Humanoid") then return end
            if Hit.Parent.Humanoid.Health <= 0 then return end
            local Player = Players:FindFirstChild(Hit.Parent.Name)
            if not Player then return end

            Debounce = true
            Button.BrickColor = BrickColor.new("White")

            if Button.Name == "LoadWeapon" then
                WeaponService:EquipWeapon(Player, Button:GetAttribute("WeaponName"), Button:GetAttribute("SkinName"), true)
            else
                WeaponService:UnloadWeapon(Player)
            end

            task.wait(2)
            Debounce = false
            Button.BrickColor = BaseColor
        end)
    end
end

-- Load new base character animations; such as idle and jumping.
local function NewBaseCharacterAnimations(Player: Player, Animations: {Name: string, ID: number})
    if not Player or not Animations then return end
    if not Player.Character then return end

    local Human, Animate = Player.Character:FindFirstChild("Humanoid"), Player.Character:FindFirstChild("Animate")
    if not Human or not Animate then return end

    task.spawn(function()
        for x = 1, 3 do
            for _, OldTrack in pairs(Human:GetPlayingAnimationTracks()) do
                OldTrack:Stop()
            end
            task.wait()
        end
    
        for Name, ID in pairs(Animations) do
            local Val = Animate:FindFirstChild(Name)
            if Val then
                for _, ThisAnimation in pairs(Val:GetChildren()) do
                    if ThisAnimation:GetAttribute("Original") == nil then
                        ThisAnimation:SetAttribute("Original", ThisAnimation.AnimationId)
                    end
                    ThisAnimation.AnimationId = "rbxassetid://" .. ID
                end
            end
        end
    end)
end

-- Reset previously changed base character animations back to their original IDs.
local function SetOriginalCharacterAnimations(Player: Player)
    if not Player then return end
    if not Player.Character then return end

    local Human, Animate = Player.Character:FindFirstChild("Humanoid"), Player.Character:FindFirstChild("Animate")
    if not Human or not Animate then return end

    for _, OldTrack in pairs(Human:GetPlayingAnimationTracks()) do
        OldTrack:Stop()
    end

    local Animations = {"idle", "walk", "run", "jump", "fall"}
    for _, Name in pairs(Animations) do
        local Val = Animate:FindFirstChild(Name)
        if Val then
            for _, ThisAnimation in pairs(Val:GetChildren()) do
                if ThisAnimation:GetAttribute("Original") then
                    ThisAnimation.AnimationId = ThisAnimation:GetAttribute("Original")
                end
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Ammo --

function WeaponService:AddWeaponForAmmo(Player: Player, WeaponName: string, Mags: number, Clips: number)
    if not PlayerAmmo[Player] then return end
    PlayerAmmo[Player][WeaponName] = {
        Mags = Mags,
        Clips = Clips,
    }
end

function WeaponService:IncrementWeaponClips(Player: Player, WeaponName: string, By: number, Max: number)
    if not PlayerAmmo[Player] then return end
    if not PlayerAmmo[Player][WeaponName] then return end
    PlayerAmmo[Player][WeaponName].Clips = math.clamp(PlayerAmmo[Player][WeaponName].Clips + By, 0, Max)
end

function WeaponService:IncrementWeaponMags(Player: Player, WeaponName: string, By: number, Max: number)
    if not PlayerAmmo[Player] then return end
    if not PlayerAmmo[Player][WeaponName] then return end
    PlayerAmmo[Player][WeaponName].Mags = math.clamp(PlayerAmmo[Player][WeaponName].Mags + By, 0, Max)
end

function WeaponService:GetWeaponAmmo(Player: Player, WeaponName: string): {Mags: number, Clips: number}?
    if not PlayerAmmo[Player] then return end
    if not PlayerAmmo[Player][WeaponName] then return end
    return PlayerAmmo[Player][WeaponName]
end

function WeaponService:ClearWeaponAmmo(Player: Player, WeaponName: string?)
    if not PlayerAmmo[Player] or not WeaponName then return end
    if not PlayerAmmo[Player][WeaponName] then return end
    PlayerAmmo[Player][WeaponName] = nil
end

function WeaponService:ClearAllWeaponsAmmo(Player: Player)
    if not PlayerAmmo[Player] then return end
    PlayerAmmo[Player] = {}
end

-- Ammo --

-- Animations --

function WeaponService:RemoveWeaponAnimations(Model: any)
    if not Model then return end
    if not WeaponAnims[Model] then return end
    WeaponAnims[Model] = nil
end

function WeaponService:CutAnim(Model: any, KeyName: string)
    if not WeaponAnims[Model] then return end
    if not WeaponAnims[Model][KeyName] then return end
    if not WeaponAnims[Model][KeyName].CurrentTrack then return end
    WeaponAnims[Model][KeyName].CurrentTrack:Stop()
    WeaponAnims[Model][KeyName].CurrentTrack = nil
    WeaponAnims[Model][KeyName].CanPlay = true
end

function WeaponService:ChangeAnimSpeed(Model: any, KeyName: string, Speed: number)
    if not WeaponAnims[Model] then return end
    if not WeaponAnims[Model][KeyName] then return end
    if not WeaponAnims[Model][KeyName].CurrentTrack then return end
    WeaponAnims[Model][KeyName].CurrentTrack:AdjustSpeed(Speed)
end

function WeaponService:PlayAnimation(Player: Player, Model: any, KeyName: string, AnimName: string, Override: boolean, Speed: number, KeyframeFunc: any, ExtraKeyParams: {}?)
    if not Model then return end
    if not WeaponAnims[Model] then return end
    if not WeaponAnims[Model][KeyName] then return end
    if not WeaponAnims[Model][KeyName].Tracks[AnimName] then return end

    local Table = WeaponAnims[Model][KeyName]
    if Table.CanPlay or Override then
        if Table.CurrentTrack then
            Table.CurrentTrack:Stop()
            Table.CurrentTrack = nil
        end

        if not Table.Tracks[AnimName].Set then
            Table.Tracks[AnimName].Set = true

            if KeyframeFunc then
                Table.Tracks[AnimName].Track.KeyframeReached:Connect(function(Keyframe: string)
                    KeyframeFunc(Player, Model, Keyframe, AnimName, ExtraKeyParams)
                end)
            end
        end

        Table.CurrentTrack = Table.Tracks[AnimName].Track
        Table.CurrentTrack:Play()
        Table.CurrentTrack:AdjustSpeed(Speed)
    end
end

function WeaponService:LoadAnimations(Model: any, KeyName: string, AnimationsList: {[string]: {ID: number, Priority: Enum.AnimationPriority}})
    if not Model or not AnimationsList then return end
    if not Model:FindFirstChild("AnimationController") then
        New.Instance("AnimationController", Model)
    end
    if not WeaponAnims[Model] then
        WeaponAnims[Model] = {}
    end

    WeaponAnims[Model][KeyName] = {
        Tracks = {},
        CurrentTrack = nil,
        CanPlay = true,
    }

    for Name, ID in pairs(AnimationsList) do
        local NewAnimation = Instance.new("Animation")
        NewAnimation.AnimationId = "rbxassetid://" .. AnimationsList[Name].ID
        local NewTrack = Model.AnimationController:LoadAnimation(NewAnimation)
        NewTrack.Priority = AnimationsList[Name].Priority

        WeaponAnims[Model][KeyName].Tracks[Name] = {Track = NewTrack, Set = false}
    end
end

-- Animations --

function WeaponService:EquipWeapon(Player: Player, WeaponName: string, SkinName: string?, LoadWeapon: boolean?)
    if not Player then return end

    DataService:SetWeapon(Player, WeaponName, SkinName)
    if not LoadWeapon then return end
    WeaponService:LoadWeapon(Player, WeaponName, SkinName)
end

function WeaponService:LoadWeapon(Player: Player, WeaponName: string, SkinName: string?)
    if not Player then return end
    if not Player.Character then return end
    if not Assets.Weapons:FindFirstChild(WeaponName) then return end
    local Module, Info = WeaponModules[WeaponName], WeaponInfo[WeaponName]
    if not Module or not Info then return end
    
    if not SkinName then
        SkinName = "Default"
    end
    if not Assets.Weapons[WeaponName][SkinName] then return end

    --[[local PlayerData = DataService:GetProfileTable(Player)
    assert(PlayerData ~= nil, Player.Name .. " data does not exist to load weapon!")]]

    WeaponService:UnloadWeapon(Player)

    local NewWeapon = Assets.Weapons[WeaponName][SkinName]:Clone()
    NewWeapon.Name = "Weapon"
    NewWeapon:SetAttribute("WeaponName", WeaponName)
    NewWeapon:SetAttribute("SkinName", SkinName)
    NewWeapon.Parent = Player.Character

    local Success = Module:Load(Player, NewWeapon, SkinName)
    if Success then
        if Info.BaseAnimations then
            NewBaseCharacterAnimations(Player, Info.BaseAnimations)
        end

        Remotes.WeaponService.Loaded:Fire(Player, WeaponName)
    else
        NewWeapon:Destroy()
    end
end

function WeaponService:UnloadWeapon(Player: Player)
    if not Player then return end
    if not Player.Character then return end

    local OldWeapon = Player.Character:FindFirstChild("Weapon")
    if not OldWeapon then return end
    
    local WeaponName = OldWeapon:GetAttribute("WeaponName")
    local Module, Info = WeaponModules[WeaponName], WeaponInfo[WeaponName]
    if not Module then return end
    
    if Info.BaseAnimations then
        SetOriginalCharacterAnimations(Player)
    end
    Module:Unload(Player, OldWeapon)

    Remotes.WeaponService.Unloaded:Fire(Player, WeaponName)

    task.wait()
end

function WeaponService:Init()
    Remotes:CreateToClient("Loaded", {"string"}, "Reliable")
    Remotes:CreateToClient("Unloaded", {"string"}, "Reliable")

    for _, Module in ServerScriptService.Source.ServerModules.Weapons:GetChildren() do
        if Module.Name == "WeaponService" then continue end
        WeaponModules[string.sub(Module.Name, 1, string.len(Module.Name) - 7)] = require(Module) 
    end

    SetTestButtons()
end

function WeaponService.PlayerAdded(Player: Player)
    PlayerAmmo[Player] = {}
end

function WeaponService.PlayerRemoving(Player: Player)
    PlayerAmmo[Player] = nil
end

return WeaponService