-- OmniRal

local RustyController = {}

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local WepaonInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo).Rusty
local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local RustyService = Remotes.RustyService

local CameraController = require(StarterPlayer.StarterPlayerScripts.Source.General.CameraController)
local AnimationController = require(StarterPlayer.StarterPlayerScripts.Source.General.AnimationController)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local UseTick = 0
local Using = false
local SwingState = "None"
local AttackActive = false
local CanPerformNextSwing = false
local PerformNextSwing = false

local BotHitList, ItemHitList = {}, {}
local HitsMade = {}

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
Params.FilterDescendantsInstances = {LocalPlayer.Character, Workspace.Projectiles}
Params.IgnoreWater = true

local RNG = Random.new()
local Sides = {-1, 1}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

RustyController.BackgroundRun = true

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function AnimKeyframes(Keyframe: string, AnimName: string, Params: {}?)
    if Keyframe == "StartSwing" then
        AttackActive = true
        local SwingNum = 1
        if SwingState == "Swing2" then
            SwingNum = 2
        elseif SwingState == "Swing1B" then
            SwingNum = 3
        end
        RustyService.Hit:Fire(SwingNum)
    
    elseif Keyframe == "FinishSwing" then
        AttackActive = false

    elseif Keyframe == "End" then
        if not PerformNextSwing then
            CanPerformNextSwing = false
            SwingState = "None"
        
        else
            local NextSwing = "None"
            if SwingState == "Swing1" or SwingState == "Swing1B" then
                NextSwing = "Swing2"
            elseif SwingState == "Swing2" then
                NextSwing = "Swing1B"
            end

            CanPerformNextSwing = true
            SwingState = NextSwing
            AnimationController:PlayNew(LocalPlayer.Character, "RustyUsingAnimations", NextSwing, true, 1, AnimKeyframes)
        end

        PerformNextSwing = false
        AttackActive = false
        table.clear(BotHitList)
        table.clear(ItemHitList)
        table.clear(HitsMade)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function RustyController:Use(DeltaTime: number, ThirdPersonCamera: boolean?): string?
    if SwingState == "None" then
        CanPerformNextSwing = true
        SwingState = "Swing1"
        table.clear(BotHitList)
        table.clear(ItemHitList)
        table.clear(HitsMade)

        AnimationController:PlayNew(LocalPlayer.Character, "RustyUsingAnimations", "Swing1", true, 1, AnimKeyframes)
    
    else
        if not PerformNextSwing and CanPerformNextSwing then
            PerformNextSwing = true
        end
    end

    return
end

function RustyController:StopUse(ForceStop: boolean?)
    if not ForceStop then return end

    Using = false
    if not ForceStop then
    
    end
end

function RustyController:RunHeartbeat(DeltaTime: number)
    if AttackActive then
        if PlayerInfo.Dead or not PlayerInfo.Root then return end
        local FrontCFrame = (PlayerInfo.Root.CFrame * CFrame.new(0, 0, -2))

        BotHitList = Utility:CheckForUnits("Bots", BotHitList, FrontCFrame, 10)
        ItemHitList = Utility:CheckForItems(ItemHitList, FrontCFrame, 10)

        for _, Bot in BotHitList do

        end

        for _, Item in ItemHitList do
            if table.find(HitsMade, Item) then continue end
            
        end
    end
end

function RustyController:Load()
    AnimationController:LoadAnimations(LocalPlayer.Character, "RustyBaseAnimations", WepaonInfo.HoldingAnimations.Base)
    AnimationController:LoadAnimations(LocalPlayer.Character, "RustyUsingAnimations", WepaonInfo.HoldingAnimations.Using)

    AnimationController:PlayNew(LocalPlayer.Character, "RustyBaseAnimations", "Idle", true, 1, AnimKeyframes)
    print("Rusty loaded!")
end

function RustyController:Unload()
    RustyController:StopUse(true)

    Using = false
    SwingState = "None"
    AttackActive = false
    CanPerformNextSwing = false
    PerformNextSwing = false

    AnimationController:CutAnim("RustyBaseAnimations")
    AnimationController:CutAnim("RustyUsingAnimations")

    print("Rusty unlaoded!")
end

return RustyController