-- OmniRal

local PlayerInfo = {}

local Workspace = game:GetService("Workspace")

export type UILockType = "None" | "ConfirmScreen" | "NewToyScreen" | "ToyEquipScreen"

PlayerInfo.Data = nil

PlayerInfo.Human = nil
PlayerInfo.Root = nil
PlayerInfo.Dead = false
PlayerInfo.UnitAttributes = nil
PlayerInfo.IsRunning = false

PlayerInfo.MoveVector = Vector3.new(0, 0, 0)

PlayerInfo.Music = nil
PlayerInfo.Sounds = nil

PlayerInfo.Grounded = {
    State = false,
    Surface = nil,
    Position = Vector3.new(0, 0, 0),
    Normal = Vector3.new(0, 0, 0),
    LastCheck = os.clock(),
    Rate = 0.2,
}

PlayerInfo.CurrentWeapon = nil
PlayerInfo.WeaponModule = nil
PlayerInfo.WeaponModel = nil

PlayerInfo.Vehicle = nil
PlayerInfo.VehicleInfo = nil
PlayerInfo.Driving = false

return PlayerInfo