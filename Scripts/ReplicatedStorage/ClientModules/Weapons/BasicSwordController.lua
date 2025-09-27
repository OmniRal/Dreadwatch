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

BasicSwordController.BackgroundRun = true

BasicSwordController.ComboNum = 1
BasicSwordController.ComboStarted = false
BasicSwordController.CanContinueCombo = false
BasicSwordController.AttackActive = false

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local Using = false
local AttackActive = false
local SwingHitList = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function ResetSwingValues()
    BasicSwordController.ComboNum = 1
    BasicSwordController.ComboStarted = false
    BasicSwordController.CanContinueCombo = false

    AttackActive = false
    table.clear(SwingHitList)
end

local function AnimKeyframes(Keyframe: string, AnimName: string, Params: {}?)
    if Keyframe == "End" then
        Using = false
        ResetSwingValues()

    elseif Keyframe == "AttackStart" then
        AttackActive = true
        BasicSwordController.CanContinueCombo = true

    elseif Keyframe == "AttackEnd" then
        AttackActive = false
        BasicSwordController.CanContinueCombo = false

    elseif Keyframe == "Shoot" then
        warn("Jizzed Locally!")
    end 
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function BasicSwordController:Use(DeltaTime: number, ComboID: string?): string?
    if not ComboID then return end

    Using = true
    BasicSwordController.CanContinueCombo = false
    AnimationController:PlayNew(LocalPlayer.Character, "BasicSwordUsingAnimations", "Swing_" .. ComboID, true, 1, AnimKeyframes)

    return
end

function BasicSwordController:UseAbility(AbilityName: "Innate" | "Awakened"): number?
    warn(3)
    local Result: number = BasicSwordService:UseAbility(if AbilityName == "Innate" then 1 else 2)
    
    if AbilityName == "Innate" then
        -- Inate
        warn(4)
        if Result == 1 then
            AnimationController:PlayNew(LocalPlayer.Character, "BasicSwordUsingAnimations", "Innate", true, 1, AnimKeyframes)
        end

    elseif AbilityName == "Awakened" then
        -- Awakened

    end

    return Result
end

function BasicSwordController:StopUse(ForceStop: boolean?)
    if not ForceStop then return end

    Using = false
    ResetSwingValues()
    if not ForceStop then
        AnimationController:PlayNew(LocalPlayer.Character, "BasicSwordUsingAnimations", "StopFire", true, 1, AnimKeyframes)
    end

    BasicSwordService.StopUse:Fire()
    print("Stopped using!")
end

function BasicSwordController:RunHeartbeat(DeltaTime: number)
    if PlayerInfo.Dead or not PlayerInfo.Root then return end
    if not AttackActive then return end

    local NewHits = {}
    for _, Unit in Workspace.Units:GetChildren() do
        if not Unit then continue end
        if Unit == LocalPlayer.Character then continue end
        if table.find(SwingHitList, Unit) then continue end

        local Human : Humanoid, Root : BasePart = Unit:FindFirstChild("Humanoid"), Unit:FindFirstChild("HumanoidRootPart")
        if not Human or not Root then continue end
        if Human.Health <= 0 then continue end

        local Distance = (PlayerInfo.Root.Position - Root.Position).Magnitude
        if Distance > 15 then continue end

        table.insert(SwingHitList, Unit)
        table.insert(NewHits, Unit)
    end

    if #NewHits <= 0 then return end

    BasicSwordService:Use(BasicSwordController.ComboNum, NewHits)
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