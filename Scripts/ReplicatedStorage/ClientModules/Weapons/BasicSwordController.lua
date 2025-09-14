-- OmniRal

local BasicSwordController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local BasicSwordService = Remotes.BasicSwordService

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)
local WepaonInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).BasicSword

local CameraController = require(StarterPlayer.StarterPlayerScripts.Source.General.CameraController)
local AnimationController = require(StarterPlayer.StarterPlayerScripts.Source.General.AnimationController)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

BasicSwordController.BackgroundRun = false

BasicSwordController.ComboNum = 1
BasicSwordController.ComboStarted = false
BasicSwordController.CanContinueCombo = false
BasicSwordController.AttackActive = false

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local Using = false

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Keyframe: string, AnimName: string, Params: {}?)
    if Keyframe == "End" then
        Using = false
        BasicSwordController.ComboNum = 1
        BasicSwordController.ComboStarted = false
        BasicSwordController.CanContinueCombo = false

    elseif Keyframe == "AttackStart" then
        BasicSwordController.CanContinueCombo = true

    elseif Keyframe == "AttackEnd" then
        BasicSwordController.CanContinueCombo = false

    end 
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function BasicSwordController:Use(DeltaTime: number, FirstOrThirdPerson: boolean?, ComboID: string?): string?
    if not ComboID then return end

    Using = true
    BasicSwordController.CanContinueCombo = false
    AnimationController:PlayNew(LocalPlayer.Character, "BasicSwordUsingAnimations", "Swing_" .. ComboID, true, 1, AnimKeyframes)

    return
end

function BasicSwordController:StopUse(ForceStop: boolean?)
    if not ForceStop then return end

    Using = false
    if not ForceStop then
        AnimationController:PlayNew(LocalPlayer.Character, "BasicSwordUsingAnimations", "StopFire", true, 1, AnimKeyframes)
    end

    BasicSwordService.StopUse:Fire()
    print("Stopped using!")
end

function BasicSwordController:Load()
    AnimationController:LoadAnimations(LocalPlayer.Character, "BasicSwordBaseAnimations", WepaonInfo.HoldingAnimations.Base)
    AnimationController:LoadAnimations(LocalPlayer.Character, "BasicSwordUsingAnimations", WepaonInfo.HoldingAnimations.Using)

    AnimationController:PlayNew(LocalPlayer.Character, "BasicSwordBaseAnimations", "Idle", true, 1, AnimKeyframes)
    print("BasicSword loaded!")
end

function BasicSwordController:Unload()
    BasicSwordController:StopUse(true)

    Using = false

    AnimationController:CutAnim("BasicSwordBaseAnimations")
    AnimationController:CutAnim("BasicSwordUsingAnimations")

    print("BasicSword unlaoded!")
end

return BasicSwordController