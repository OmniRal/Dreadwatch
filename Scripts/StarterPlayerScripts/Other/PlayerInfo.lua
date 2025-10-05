-- OmniRal

local PlayerInfo = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type UILockType = "None" | "ConfirmScreen" | "NewToyScreen" | "ToyEquipScreen"

PlayerInfo.Data = nil

PlayerInfo.Human = nil :: Humanoid?
PlayerInfo.Root = nil :: BasePart?
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