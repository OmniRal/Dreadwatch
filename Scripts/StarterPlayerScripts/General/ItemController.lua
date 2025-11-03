-- OmniRal

local ItemController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)

local ItemService = Remotes.ItemService

local PlayerInfo = require(StarterPlayer.StarterPlayerScripts.Source.Other.PlayerInfo)
local ItemInfo = require(ReplicatedStorage.Source.SharedModules.Info.ItemInfo)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function UseItem(Action: string, InputState: Enum.UserInputState, InputObject: InputObject?)
    warn(1)
    if InputState ~= Enum.UserInputState.Begin then return end
    warn(2)
    if PlayerInfo.Dead or not PlayerInfo.Root then return end
    
    local SlotNum = tonumber(string.sub(Action, 9, 9))
    local Result_1, Result_2 = ItemService:UseActive(SlotNum, PlayerInfo.Root.Position, Mouse.Hit.Position)

    warn("Result : ", Result_1, Result_2)
    return Result_1, Result_2
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function ItemController:SetCharacter()
    ItemController:ToggleControls(true)
end

function ItemController:ToggleControls(Set: boolean)

    if Set then
        ContextActionService:BindAction("UseItem_1", UseItem, false, Enum.KeyCode.One)
        ContextActionService:BindAction("UseItem_2", UseItem, false, Enum.KeyCode.Two)
        ContextActionService:BindAction("UseItem_3", UseItem, false, Enum.KeyCode.Three)

    else
        ContextActionService:UnbindAction("UseItem_1")
        ContextActionService:UnbindAction("UseItem_2")
        ContextActionService:UnbindAction("UseItem_3")
    end
end

function ItemController:Init()
    ItemService.Equipped:Connect(function(ItemName: string)
        print("Equipped ", ItemName)
    end)

    ItemService.Unequipped:Connect(function(ItemName: string)
        print("Unequipped ", ItemName)
    end)

	print("ItemController initialized...")
end

function ItemController:Deferred()
    print("ItemController deferred...")
end

return ItemController