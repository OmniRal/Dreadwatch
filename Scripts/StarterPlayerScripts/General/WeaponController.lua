-- OmniRal
--!nocheck

local WeaponController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local DataService = Remotes.DataService
local WeaponService = Remotes.WeaponService

local WeaponEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.WeaponEnum)
local WeaponInfo = require(ReplicatedStorage.Source.SharedModules.Info.WeaponInfo)
local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)

local CameraController = require(StarterPlayer.StarterPlayerScripts.Source.General.CameraController)
local GameplayUIController = require(StarterPlayer.StarterPlayerScripts.Source.UIModules.GameplayUIController)

local SoundControlService = require(ReplicatedStorage.Source.SharedModules.Other.SoundControlService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local UseControlState = "None"

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Checks to see if the weapon can combo chain attacks and returns which attack to use.
local function CheckComboChain(Module: ModuleScript, Info: WeaponEnum.Weapon): string?
    if not Module or not Info then return end
    if Info.Style ~= "Melee" or not Info.MeleeData then return end
    if not Info.MeleeData.CanComboChain then return end

    if not Module.ComboStarted then
        Module.ComboStarted = true
        Module.ComboNum = 1
        return "1_A" -- Start combo.

    else
        if not Module.CanContinueCombo then return end

        Module.ComboNum += 1
        if Module.ComboNum > Info.MeleeData.ComboAmount then
            Module.ComboNum = 1
            return "1_B" -- Restart combo loop.
        end

        return tostring(Module.ComboNum) -- Continue combo.
    end
end

-- To use the standard attack of the weapon
local function UseWeapon(Action: string, InputState: Enum.UserInputState, InputObject: InputObject?)
    local Module = PlayerInfo.WeaponModule
    local Info : WeaponInfo.Weapon = WeaponInfo[PlayerInfo.CurrentWeapon]
    if not Module or not Info then return end

    if Action == "Use" .. PlayerInfo.CurrentWeapon then
       if InputState == Enum.UserInputState.Begin then
            if Info.UseType == "Single"  then
                -- Single use weapons such as swords that combo each time you press the attack button.
                local ComboID = CheckComboChain(Module, Info)
                local Result = Module:Use(nil, ComboID)

                --[[if Result == "OutOfClips" then
                    GameplayUIController:PlayAmmoAnim("Clips", "ClipsEmpty")
                
                    elseif Result == "OutOfAmmo" then
                    GameplayUIController:PlayAmmoAnim("Clips", "ClipsEmpty")
                    GameplayUIController:PlayAmmoAnim("Clips", "MagsEmpty")
                end]]
           
            elseif Info.UseType == "Auto" then
                -- Auto use / firing weapons such as machine guns.
                UseControlState = "AutoUse"
            end
       
       elseif InputState == Enum.UserInputState.End then
            -- 
            if Info.UseType == "Single"  then
               return

            elseif Info.UseType == "Auto" then
               UseControlState = "None"
               Module:StopUse()
            end
        end

    elseif Action == "UseAbility" .. PlayerInfo.CurrentWeapon then
        if InputState == Enum.UserInputState.Begin then
            local Result = Module:UseAbility(PlayerInfo.Data.CurrentWeaponAbility)
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
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function WeaponController:ToggleWeaponControls(Toggle: boolean, Weapon: string)
    UseControlState = "None"

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

        if Info.Abilities then
            local CurrentAbility = PlayerInfo.Data.CurrentWeaponAbility
            if Info.Abilities[CurrentAbility] then
                if Info.Abilities[CurrentAbility].Type == "Active" then
                    ContextActionService:BindAction("UseAbility" .. Weapon, UseWeapon, false, Enum.KeyCode.E, Enum.KeyCode.ButtonL2)
                end
            end
        end

        if Info.Reload then
            ContextActionService:BindAction("Reload" .. Weapon, ReloadWeapon, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
        end

        PlayerInfo.WeaponModule:Load()

    else
        if not PlayerInfo.WeaponModule then return end
        
        PlayerInfo.WeaponModule:Unload()
        ContextActionService:UnbindAction("Use" .. Weapon)
        ContextActionService:UnbindAction("Reload" .. Weapon)
        
        PlayerInfo.WeaponModule = nil
        PlayerInfo.CurrentWeapon = "None"
        PlayerInfo.WeaponModel = nil
        
    end
end

function WeaponController:SetCharacter()

end

function WeaponController:RunHeartbeat(DeltaTime: number)
    if not PlayerInfo.WeaponModule then return end

    if UseControlState == "AutoUse" then
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