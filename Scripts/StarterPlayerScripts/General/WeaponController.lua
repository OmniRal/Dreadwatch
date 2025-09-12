-- OmniRal

local WeaponController = {}

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")


local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DataService = Remotes.DataService
local WeaponService = Remotes.WeaponService

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)
local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo)

local CameraController = require(StarterPlayer.StarterPlayerScripts.Source.General.CameraController)
local GameplayUIController = require(StarterPlayer.StarterPlayerScripts.Source.UIModules.GameplayUIController)

local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local WeaponUseStateControl = "None"

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function UseWeapon(Action: string, InputState: Enum.UserInputState, InputObject: InputObject?)
    if Action == "Use" .. PlayerInfo.CurrentWeapon then
       local Module = PlayerInfo.WeaponModule
       local Info : WeaponInfo.Weapon = WeaponInfo[PlayerInfo.CurrentWeapon]
       if not Module or not Info then return end

       if InputState == Enum.UserInputState.Begin then
            if Info.UseType == "Single"  then
                local Result = Module:Use()
                
                if Result == "OutOfClips" then
                    GameplayUIController:PlayAmmoAnim("Clips", "ClipsEmpty")
                
                    elseif Result == "OutOfAmmo" then
                    GameplayUIController:PlayAmmoAnim("Clips", "ClipsEmpty")
                    GameplayUIController:PlayAmmoAnim("Clips", "MagsEmpty")
                end
           
           elseif Info.UseType == "Auto" then
               WeaponUseStateControl = "AutoFire"
           end
       
       elseif InputState == Enum.UserInputState.End then
           if Info.UseType == "Single"  then
               return          
           elseif Info.UseType == "Auto" then
               WeaponUseStateControl = "None"
               Module:StopUse()
           end
       end
   end
end

local function ReloadWeapon(Action: string, InputState: Enum.UserInputState, InputObject: InputObject)
    if Action == "Reload" .. PlayerInfo.CurrentWeapon then
        local Module = PlayerInfo.WeaponModule
        local Info : WeaponInfo.Weapon = WeaponInfo[PlayerInfo.CurrentWeapon] 
        if not Module or not Info then return end

        if InputState == Enum.UserInputState.Begin then
            local Result = Module:Reload()

            if Result == 9 then
                GameplayUIController:PlayAmmoAnim("Mags", "MagsEmpty")
            elseif Result == 8 then
                GameplayUIController:PlayAmmoAnim("Clips", "ClipsMax")
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function WeaponController:ToggleWeaponControls(Toggle: boolean, Weapon: string)
    WeaponUseStateControl = "None"

    if Toggle then
        if PlayerInfo.WeaponModule then
            PlayerInfo.WeaponModule:Unload()
        end

        local NeededModule = ReplicatedStorage.Source.ClientModules.Weapons:FindFirstChild(Weapon .. "Controller")
        if not NeededModule then return end

        local Info: WeaponInfo.Weapon = WeaponInfo[Weapon]

        PlayerInfo.WeaponModule = require(NeededModule)
        PlayerInfo.CurrentWeapon = Weapon
        PlayerInfo.WeaponModel = LocalPlayer.Character:FindFirstChild("Weapon", 3)

        ContextActionService:BindAction("Use" .. Weapon, UseWeapon, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
        if Info.Reload then
            ContextActionService:BindAction("Reload" .. Weapon, ReloadWeapon, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
        end

        PlayerInfo.WeaponModule:Load()

        GameplayUIController:UpdateWeaponFrame(
            Info.Icon,
            if Info.MaxClips ~= nil then true else false,
            if Info.MaxMags ~= nil then true else false
        )
        
    else
        if not PlayerInfo.WeaponModule then return end
        
        PlayerInfo.WeaponModule:Unload()
        ContextActionService:UnbindAction("Use" .. Weapon)
        
        PlayerInfo.WeaponModule = nil
        PlayerInfo.CurrentWeapon = "None"
        PlayerInfo.WeaponModel = nil
        GameplayUIController:UpdateWeaponFrame()
        
    end
end

function WeaponController:SetCharacter()

end

function WeaponController:RunHeartbeat(DeltaTime: number)
    if not PlayerInfo.WeaponModule then return end

    if WeaponUseStateControl == "AutoFire" then
        if not PlayerInfo.WeaponModule then return end
        local CameraType = CameraController.CameraType:Get()
        local Result = PlayerInfo.WeaponModule:Use(DeltaTime, if CameraType == "FirstPerson" or CameraType == "ThirdPerson" then true else false)
        
        if Result == "OutOfClips" then
            UseWeapon("Use" .. PlayerInfo.CurrentWeapon, Enum.UserInputState.End)
            GameplayUIController:PlayAmmoAnim("Clips", "ClipsEmpty")

        elseif Result == "OutOfAmmo" then
            UseWeapon("Use" .. PlayerInfo.CurrentWeapon, Enum.UserInputState.End)
            GameplayUIController:PlayAmmoAnim("Clips", "ClipsEmpty")
            GameplayUIController:PlayAmmoAnim("Mags", "MagsEmpty")
        end
    end

    if PlayerInfo.WeaponModule.BackgroundRun then
        PlayerInfo.WeaponModule:RunHeartbeat(DeltaTime)
    end
end

function WeaponController:Init()
    WeaponService.Loaded:Connect(function(WeaponName: string)
        WeaponController:ToggleWeaponControls(true, WeaponName)
    end)

    WeaponService.Unloaded:Connect(function(WeaponName: string)
        WeaponController:ToggleWeaponControls(false, WeaponName)
    end)
end

return WeaponController