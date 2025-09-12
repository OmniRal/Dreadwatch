-- OmniRal

local PlatformingController = {}

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local CoreGameService = Remotes.CoreGameService

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DASH_SPEED = 50

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local RootMotor = nil
local SideRootCFrame = CFrame.new(0, 0, 0)
local ForwardLeanVector = Vector3.new(0, 0, 0)

local AnglePart

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

local function HandleLeaning()
    if not RootMotor then return end

    local RootLook = PlayerInfo.Root.CFrame.LookVector
    local LookAngle = math.deg(math.atan2(RootLook.X, RootLook.Z))

    SideRootCFrame = SideRootCFrame:Lerp(CFrame.new(SideRootCFrame.Position) * CFrame.Angles(0, math.rad(LookAngle), 0), 0.1)
    local GoalSideRootCFrame = CFrame.new(SideRootCFrame.Position) * CFrame.Angles(0, math.rad(LookAngle), 0)
    local ProjectedVector = SideRootCFrame:PointToObjectSpace((GoalSideRootCFrame * CFrame.new(0, 0, -10)).Position) * Vector3.new(1, 0, 1)
    local AngleDiff = math.atan2(ProjectedVector.Z, ProjectedVector.X)
    local SideLeanAngle = math.clamp(math.rad(math.round(math.deg(AngleDiff) + 90)) / 4, -math.pi / 6, math.pi / 6)

    if PlayerInfo.Grounded.State then
        local NewForwardVector = PlayerInfo.Root.CFrame:VectorToObjectSpace(PlayerInfo.Grounded.Normal)
        ForwardLeanVector = ForwardLeanVector:Lerp(NewForwardVector, 0.1)
    end

    RootMotor.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.clamp(ForwardLeanVector.Z, -math.pi / 6, math.pi / 6), 0, -math.clamp(ForwardLeanVector.X, -math.pi / 6, math.pi / 6) - SideLeanAngle)
end

local function HandleWalkSpeed()
    if PlayerInfo.Dead then return end
    if not PlayerInfo.Human or not PlayerInfo.Root then return end

    local FinalSpeed = StarterPlayer.CharacterWalkSpeed
    local SweatEnabled = false

    if PlayerInfo.Holding and PlayerInfo.HoldingInfo then
        local WeightReductionSpeedMultiplier = 0

        if PlayerInfo.Holding:GetAttribute("Weight") == 2 then
            WeightReductionSpeedMultiplier = 0.2
        
        elseif PlayerInfo.Holding:GetAttribute("Weight") == 3 then
            WeightReductionSpeedMultiplier = 0.5

            SweatEnabled = true
        end

        FinalSpeed = math.clamp(FinalSpeed - (FinalSpeed * WeightReductionSpeedMultiplier), 0, DASH_SPEED)
    end

    PlayerInfo.Human.WalkSpeed = FinalSpeed

    if PlayerInfo.Root:FindFirstChild("Sweat") then
        if PlayerInfo.Root.Sweat.Enabled ~= SweatEnabled then
            CoreGameService:ToggleParticles({PlayerInfo.Root}, {{Name = "Sweat", Set = SweatEnabled}})
        end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------
-- Public API --
----------------

function PlatformingController:SetCharacter()
    local LowerTorso = LocalPlayer.Character:WaitForChild("LowerTorso", 30)
    RootMotor = LowerTorso:WaitForChild("Root", 30)
    SideRootCFrame = CFrame.new(PlayerInfo.Root.Position)
end

function PlatformingController:RunHeartbeat(DeltaTime: number)
    if PlayerInfo.Dead then return end
    if not PlayerInfo.Human or not PlayerInfo.Root then return end

    HandleLeaning()
    HandleWalkSpeed()
end

function PlatformingController:Init()
    UserInputService.JumpRequest:Connect(function()
        
    end)
end

function PlatformingController:Deferred()

end

return PlatformingController