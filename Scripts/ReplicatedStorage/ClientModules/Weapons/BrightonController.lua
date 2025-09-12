-- OmniRal

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local BrightonService = Remotes.BrightonService

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)
local WepaonInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).Brighton

local CameraController = require(StarterPlayer.StarterPlayerScripts.Source.General.CameraController)
local AnimationController = require(StarterPlayer.StarterPlayerScripts.Source.General.AnimationController)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local BrightonController = {}

BrightonController.BackgroundRun = false

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local UseTick = 0
local Using = false
local Reloading = false

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
Params.FilterDescendantsInstances = {LocalPlayer.Character, Workspace.Projectiles}
Params.IgnoreWater = true

local RNG = Random.new()
local Sides = {-1, 1}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Keyframe: string, AnimName: string, Params: {}?)
    if Keyframe == "End" then
        if AnimName == "StartFire" then
            AnimationController:PlayNew(LocalPlayer.Character, "BrightonUsingAnimations", "Using", true, 1, AnimKeyframes)
        
        elseif AnimName == "Reloading" then
            Reloading = false
        end

    elseif Keyframe == "GrabJar" then -- 1:03

    elseif Keyframe == "StartPouring" then -- 1:31

    elseif Keyframe == "StopPouring" then -- 1:58

    elseif Keyframe == "ReleaseJar" then -- 2:25

    end 
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function BrightonController:Use(DeltaTime: number, FirstOrThirdPerson: boolean?): string?
    if Reloading then return "Reloading" end

    if PlayerInfo.WeaponModel.Clips.Value <= 0 and PlayerInfo.WeaponModel.Mags.Value > 0 then return "OutOfClips" end
    if PlayerInfo.WeaponModel.Clips.Value <= 0 and PlayerInfo.WeaponModel.Mags.Value <= 0 then return "OutOfAmmo" end

    UseTick += DeltaTime
    if UseTick < WepaonInfo.UseRate then return end
    UseTick = 0

    local AimTo
    if FirstOrThirdPerson then
        local UnitRay = Camera:ViewportPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2 + 0)
        local CameraRay = Workspace:Raycast(UnitRay.Origin, UnitRay.Direction * 1000, Params)
        if CameraRay then
            if CameraRay.Instance then
                AimTo = CameraRay.Position
            end
        end

        if CameraRay then
            AimTo = CameraRay.Position
        else
            AimTo = CameraRay.Origin + CameraRay.Direction * 1000
        end
    else
        AimTo = Mouse.Hit.Position
    end

    local Spread = 0
    local MainGui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
    if MainGui then
        if MainGui:FindFirstChild("Aimer") then
            local Radius = MainGui.Aimer.AbsoluteSize.X / 2
            local FocalLength = Camera.ViewportSize.Y / (2 * math.tan(math.rad(Camera.FieldOfView / 2)))
            Spread = math.atan(Radius / FocalLength)
        end
    end
    
    BrightonService.Shoot:Fire(AimTo, Spread, Camera.CFrame, FirstOrThirdPerson)
    CameraController:Shake(
        50, 
        0.2, 
        Vector3.new(
            RNG:NextNumber(1, 2) * Sides[RNG:NextInteger(1, 2)],
            RNG:NextNumber(1, 2) * Sides[RNG:NextInteger(1, 2)],
            RNG:NextNumber(1, 2) * Sides[RNG:NextInteger(1, 2)]
        )
    )

    if not Using then
        Using = true
        AnimationController:PlayNew(LocalPlayer.Character, "BrightonUsingAnimations", "StartFire", true, 1, AnimKeyframes)
    end

    return
end

function BrightonController:StopUse(ForceStop: boolean?)
    if Reloading and not ForceStop then return end

    Using = false
    if not ForceStop then
        AnimationController:PlayNew(LocalPlayer.Character, "BrightonUsingAnimations", "StopFire", true, 1, AnimKeyframes)
    end
    BrightonService.StopShoot:Fire()
    print("Stopped using!")
end

function BrightonController:Reload()
    if Using then return end
    if Reloading then return end

    Reloading = true
    local Result = BrightonService.Reload:Fire()

    if Result == 1 then
        AnimationController:PlayNew(LocalPlayer.Character, "BrightonUsingAnimations", "Reloading", true, 1, AnimKeyframes)
    else
        Reloading = false
    end

    return Result
end

function BrightonController:CancelReload()
    if not Reloading then return end
    Reloading = false
    AnimationController:PlayNew(LocalPlayer.Character, "BrightonUsingAnimations", "Reloading", true, 1, AnimKeyframes)
end

function BrightonController:Load()
    AnimationController:LoadAnimations(LocalPlayer.Character, "BrightonBaseAnimations", WepaonInfo.HoldingAnimations.Base)
    AnimationController:LoadAnimations(LocalPlayer.Character, "BrightonUsingAnimations", WepaonInfo.HoldingAnimations.Using)

    AnimationController:PlayNew(LocalPlayer.Character, "BrightonBaseAnimations", "Idle", true, 1, AnimKeyframes)
    print("Brighton loaded!")
end

function BrightonController:Unload()
    BrightonController:StopUse(true)

    if Reloading then
        BrightonController:CancelReload()
    end

    Using = false
    Reloading = false

    AnimationController:CutAnim("BrightonBaseAnimations")
    AnimationController:CutAnim("BrightonUsingAnimations")

    print("Brighton unlaoded!")
end

return BrightonController