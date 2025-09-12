-- OmniRal

local CruncherController = {}

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local WepaonInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).Cruncher
local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local CruncherService = Remotes.CruncherService

local CameraController = require(StarterPlayer.StarterPlayerScripts.Source.General.CameraController)
local AnimationController = require(StarterPlayer.StarterPlayerScripts.Source.General.AnimationController)

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

CruncherController.BackgroundRun = false

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Keyframe: string, AnimName: string, Params: {}?)
    if Keyframe == "End" then
        if AnimName == "StartFire" then
            AnimationController:PlayNew(LocalPlayer.Character, "CruncherUsingAnimations", "Using", true, 1, AnimKeyframes)
        
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

function CruncherController:Use(DeltaTime: number, ThirdPersonCamera: boolean?): string?
    print("R: ", Reloading)
    if Reloading then
        return "Reloading"
    end

    if PlayerInfo.WeaponModel.Clips.Value <= 0 and PlayerInfo.WeaponModel.Mags.Value > 0 then
        return "OutOfClips"
    elseif PlayerInfo.WeaponModel.Clips.Value <= 0 and PlayerInfo.WeaponModel.Mags.Value <= 0 then
        return "OutOfAmmo"
    end

    UseTick += DeltaTime
    if UseTick < WepaonInfo.UseRate then return end
    UseTick = 0

    local AimTo
    if ThirdPersonCamera then
        AimTo = (CFrame.new(
            Camera.CFrame.Position,
            (Camera.CFrame * CFrame.new(0, 0, -10)).Position
            ) * CFrame.new(0, 0, -700))
    
        local UnitRay = Camera:ViewportPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2 + 0, 0)
        local CameraRay = Workspace:Raycast(UnitRay.Origin, UnitRay.Direction * 700, Params)
        if CameraRay then
            if CameraRay.Instance then
                AimTo = CFrame.new(CameraRay.Position)
            end
        end
    else
        AimTo = Mouse.Hit
    end
    
    CruncherService.Shoot:Fire(AimTo, ThirdPersonCamera)
    CameraController:Shake(
        40, 
        0.3, 
        Vector3.new(
            RNG:NextNumber(2, 3) * Sides[RNG:NextInteger(1, 2)],
            RNG:NextNumber(2, 3) * Sides[RNG:NextInteger(1, 2)],
            RNG:NextNumber(2, 3) * Sides[RNG:NextInteger(1, 2)]
        )
    )

    if not Using then
        Using = true
        AnimationController:PlayNew(LocalPlayer.Character, "CruncherUsingAnimations", "StartFire", true, 1, AnimKeyframes)
    end

    return
end

function CruncherController:StopUse(ForceStop: boolean?)
    if Reloading and not ForceStop then return end

    Using = false
    if not ForceStop then
        AnimationController:PlayNew(LocalPlayer.Character, "CruncherUsingAnimations", "StopFire", true, 1, AnimKeyframes)
    end
    CruncherService.StopShoot:Fire()
    print("Stopped using!")
end

function CruncherController:Reload()
    if Using then return end
    if Reloading then return end

    Reloading = true
    local Result = CruncherService.Reload:Fire()

    if Result == 1 then
        AnimationController:PlayNew(LocalPlayer.Character, "CruncherUsingAnimations", "Reloading", true, 1, AnimKeyframes)
    else
        Reloading = false
    end

    return Result
end

function CruncherController:CancelReload()
    if not Reloading then return end
    Reloading = false
    AnimationController:PlayNew(LocalPlayer.Character, "CruncherUsingAnimations", "Reloading", true, 1, AnimKeyframes)
end

function CruncherController:Load()
    AnimationController:LoadAnimations(LocalPlayer.Character, "CruncherBaseAnimations", WepaonInfo.HoldingAnimations.Base)
    AnimationController:LoadAnimations(LocalPlayer.Character, "CruncherUsingAnimations", WepaonInfo.HoldingAnimations.Using)

    AnimationController:PlayNew(LocalPlayer.Character, "CruncherBaseAnimations", "Idle", true, 1, AnimKeyframes)
    print("Cruncher loaded!")
end

function CruncherController:Unload()
    CruncherController:StopUse(true)

    if Reloading then
        CruncherController:CancelReload()
    end

    Using = false
    Reloading = false

    AnimationController:CutAnim("CruncherBaseAnimations")
    AnimationController:CutAnim("CruncherUsingAnimations")

    print("Cruncher unlaoded!")
end

return CruncherController