-- OmniRal

local ItemService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local AbilityService = require(ServerScriptService.Source.ServerModules.General.AbilityService)
local UnitValuesService = require(ServerScriptService.Source.ServerModules.General.UnitValuesService)
local ServerGlobalValues = require(ServerScriptService.Source.ServerModules.Top.ServerGlobalValues)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local UnitEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.UnitEnum)
local ItemInfo = require(ReplicatedStorage.Source.SharedModules.Info.ItemInfo)

local ItemModules = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PlayerItems: {
    [Player]: {
        {Name: string, Last: string, Effect: UnitEnum.Effect?, Cooldown: number, Connection: RBXScriptConnection?}
    }
} = {}

local Events = ServerStorage.Events

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CreateNewItemModel(Item: string, Position: Vector3): boolean?
    local Info = ItemInfo[Item]
    if not Info then return end

    local NewItem: Model = New.Instance("Model", Item, Workspace)
    NewItem:AddTag("Item")

    local NewBase = New.Instance("Part", "Base", NewItem,
        {
            Anchored = true, CanCollide = false, CanQuery = true, CanTouch = false, Color = Color3.fromRGB(200, 255, 255), 
            Material = Enum.Material.Metal, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(Position)
        }
    )

    NewItem.PrimaryPart = NewBase

    return true
end

-- Add stat changes from item
local function ApplyItemEffect(Player: Player, SlotNum: number, ItemName: string)
    local P_Items, Info = PlayerItems[Player], ItemInfo[ItemName]
    if not P_Items or not Info then return end

    -- Add Items stat changes
    local EffectDetails: UnitEnum.EffectDetails = {
        Name = Info.Name,
        From = Info.Name,
        Description = Info.Description,
        IsBuff = true,
        Icon = Info.Icon,
        Duration = -1,
        MaxStacks = Info.MaxStacks or 1,
        DoNotDisplay = true,
    }
    local ItemEffect = UnitValuesService:AddEffect(Player, EffectDetails, Info.Attributes, {})
    P_Items[SlotNum].Effect = ItemEffect
end

-- Clean up the stat changes from item
local function CleanupItemEffect(Player: Player, SlotNum: number, ItemName: string)
    local P_Items, Info = PlayerItems[Player], ItemInfo[ItemName]
    if not P_Items or not Info then return end

    UnitValuesService:CleanThisEffect(Player, P_Items[SlotNum].Effect)
    P_Items[SlotNum].Effect = nil
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Apply or clean up all the effects of the players (first 3) items
function ItemService.ToggleAllItemEffects(Player: Player, Apply: boolean)
    local P_Items = PlayerItems[Player]
    if not P_Items then return end

    for x = 1, 3 do
        local Slot = P_Items[x]
        if not Slot then continue end

        if Apply then
            ApplyItemEffect(Player, x, P_Items[x].Name)
        else
            CleanupItemEffect(Player, x, P_Items[x].Name)
        end
    end
end

-- Equip a Item, add its stat changes, and ability connection
-- @SlotNum : Which slot to add the Item
function ItemService:EquipItem(Player: Player, SlotNum: number, ItemName: string)
    local P_Items, Info = PlayerItems[Player], ItemInfo[ItemName]
    if not P_Items or not Info then return end

    Remotes.ItemService.Equipped:Fire(Player, ItemName)

    -- Unequip the old Item if it exists
    if P_Items[SlotNum].Name ~= "None" then
        ItemService:UnequipItem(Player, SlotNum, P_Items[SlotNum].Name)
    end
    
    P_Items[SlotNum].Last = P_Items[SlotNum].Name
    P_Items[SlotNum].Name = ItemName
    DataService:SetItem(Player, SlotNum, ItemName)

    -- Anything past 3 is the backpack; inactive Items
    if SlotNum > 3 then return end

    if ServerGlobalValues.InLevel then
        ApplyItemEffect(Player, SlotNum, ItemName)
    end

    if not Info.Ability then return end
    
    -- Add the Item as an ability to AbilityService to track its cooldown
    AbilityService:AddNew(Player, ItemName, {[Info.Ability.Type] = {Equipped = true, BaseCooldown = Info.Ability.Cooldown}})

    -- If the Item has a passive, add a connection to check the players history
    if Info.Ability.Type == "Passive" then
        local Module = ItemModules[ItemName]
        if not Module then return end

        P_Items[SlotNum].Connection = Events.Unit.NewHistoryEntry.Event:Connect(function(Unit: Player, Entry: UnitEnum.HistoryEntry)
            if P_Items[SlotNum].Name ~= ItemName then return end
            if not Unit or not Entry or not Module then return end
            if not Unit:IsA("Player") then return end
            Module:UsePassive(Player, Entry)
        end)
    end
end

-- Unequip a Item, remove its effect (stat) changes and remove the ability connection
function ItemService:UnequipItem(Player: Player, SlotNum: number, ItemName: string, IgnoreSetters: boolean?)
    local P_Items, Info = PlayerItems[Player], ItemInfo[ItemName]
    if not P_Items or not Info then return end

    Remotes.ItemService.Unequipped:Fire(Player, ItemName)

    if not IgnoreSetters then 
        P_Items[SlotNum].Name = "None"
        P_Items[SlotNum].Last = ItemName
        DataService:SetItem(Player, SlotNum, "None")
        print("Unequipping")
    end

    CleanupItemEffect(Player, SlotNum, ItemName)

    -- Disconnect passive ability if exists
    local Connection = PlayerItems[Player][SlotNum].Connection
    if Connection then
        Connection:Disconnect()
        P_Items[SlotNum].Connection = nil
    end
end

function ItemService:UseActive(Player: Player, SlotNum: number, ShootFrom: Vector3?, ShootGoal: Vector3?): (number?, number?)
    local Slot = PlayerItems[Player][SlotNum]
    local Info = ItemInfo[Slot.Name]
    if not Info then return CustomEnum.ReturnCodes.ComplexError, -1 end
    if not Info.Ability then return CustomEnum.ReturnCodes.ComplexError, -2 end
    if Info.Ability.Type == "Passive" then return CustomEnum.ReturnCodes.ComplexError, -3 end
    
    local Module = ItemModules[Slot.Name]
    return Module:UseActive(Player, ShootFrom, ShootGoal)
end

function ItemService:RequestSwapItems(Player: Player, SlotNum_A: number, SlotNum_B: number): (number?, number?)
    local P_Items = PlayerItems[Player]
    if not P_Items then return end

    local Slot_A = P_Items[SlotNum_A]
    local Slot_B = P_Items[SlotNum_B]
    local A_Info, B_Info = ItemInfo[Slot_A.Name], ItemInfo[Slot_B.Name]
    if not A_Info then return CustomEnum.ReturnCodes.ComplexError, -1 end
    if Slot_B.Name ~= "None" and not B_Info then return CustomEnum.ReturnCodes.ComplexError, -2 end

    -- Make sure the DataService approves of the swap
    if not DataService:SwapItems(Player, SlotNum_A, SlotNum_B) then return CustomEnum.ReturnCodes.ComplexError, -3 end

    ItemService:UnequipItem(Player, SlotNum_A, A_Info.Name)
    ItemService:EquipItem(Player, SlotNum_B, A_Info.Name)

    if B_Info then
        ItemService:EquipItem(Player, SlotNum_A, B_Info.Name)
    end

    return 1
end

-- Player attempts to drop a Item out near them
-- @SlotNum : The Item slot in their data they wish to drop
-- @DropTo : Where to drop it
function ItemService:RequestDropItem(Player: Player, SlotNum: number, DropTo: Vector3?)
    if not Player or not SlotNum then return end
    local Alive, _, Root = Utility:CheckPlayerAlive(Player)
    if not Alive or not Root then return end

    local Items = DataService:GetPlayerItems(Player)
    if not Items then return end
    if not Items[SlotNum] then return end
    if Items[SlotNum] == "None" then return end

    local DropPosition = DropTo
    
    if not DropPosition then
        -- If DropTo was not provided, set DropPosition to be in front of the player
        DropPosition = (Root.CFrame * CFrame.new(0, 0, -10)).Position

    else
        -- If DropTo is too far, bring reduce its distance but keeping it in the same direction
        DropPosition = (CFrame.new(Root.Position, DropPosition) * CFrame.new(0, 0, -10)).Position
    end

    -- Try to drop the Item onto the ground using a raycast
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {Player.Character, Workspace.Units}
    Params.IgnoreWater = true
    local NewRay, Dropped = Workspace:Raycast(DropPosition + Vector3.new(0, 10, 0), Vector3.new(0, -25, 0), Params), false
    if NewRay then
        if NewRay.Position then
            Dropped = CreateNewItemModel(Items[SlotNum], NewRay.Position)
        end
    end

    if not Dropped then return end

    ItemService:UnequipItem(Player, SlotNum, Items[SlotNum])

    return true
end

-- Player attempts to pick up / equip a Item that is on the ground
-- @Item : The model of the Item in the 3D world
function ItemService:RequestPickupItem(Player: Player, Item: Model)
    if not Player or not Item then return end
    local Info = ItemInfo[Item.Name]
    if not Info then return end

    local Full, OpenSlot = DataService:AreItemSlotsFull(Player)
    if Full or not OpenSlot then return end

    ItemService:EquipItem(Player, OpenSlot, Info.Name)

    Item:Destroy()

    return true
end

function ItemService:Init()
    Remotes:CreateToClient("Equipped", {"string"}, "Reliable")
    Remotes:CreateToClient("Unequipped", {"string"}, "Reliable")
    Remotes:CreateToClient("ItemSlotsUpdated", {"table"}, "Reliable")

    -- Remote to use active ability of a Item
    Remotes:CreateToServer("UseActive", {"number", "Vector3?", "Vector3?"}, "Returns", function(Player: Player, SlotNum: number, ShootFrom: Vector3?, ShootGoal: Vector3?)
        return ItemService:UseActive(Player, SlotNum, ShootFrom, ShootGoal)
    end)

    Remotes:CreateToServer("RequestSwapItems", {"number", "number"}, "Returns", function(Player: Player, SlotNum_A: number, SlotNum_B: number)
        return ItemService:RequestSwapItems(Player, SlotNum_A, SlotNum_B)
    end)

    Remotes:CreateToServer("RequestDropItem", {"number", "Vector3?"}, "Returns", function(Player: Player, SlotNum: number, DropTo: Vector3?)
        return ItemService:RequestDropItem(Player, SlotNum, DropTo)
    end)

    Remotes:CreateToServer("RequestPickupItem", {"Model"}, "Returns", function(Player: Player, Item: Model)
        return ItemService:RequestPickupItem(Player, Item)
    end)

    for _, Module in ServerScriptService.Source.ServerModules.Items:GetChildren() do
        if Module.Name == "ItemService" then continue end
        ItemModules[string.sub(Module.Name, 1, string.len(Module.Name) - 7)] = require(Module) 
    end

	print("ItemService initialized...")
end

function ItemService:Deferred()
    print("ItemService deferred...")
end

function ItemService.PlayerAdded(Player: Player)
    local CurrentItems = DataService:GetPlayerItems(Player)

    PlayerItems[Player] = {
        {Name = CurrentItems[1], Last = CurrentItems[1], Effect = nil, Cooldown = 0},
        {Name = CurrentItems[2], Last = CurrentItems[2], Effect = nil, Cooldown = 0},
        {Name = CurrentItems[3], Last = CurrentItems[3], Effect = nil, Cooldown = 0},
        {Name = CurrentItems[4], Last = CurrentItems[4], Effect = nil, Cooldown = 0},
        {Name = CurrentItems[5], Last = CurrentItems[5], Effect = nil, Cooldown = 0},
        {Name = CurrentItems[6], Last = CurrentItems[6], Effect = nil, Cooldown = 0},
    }

    task.delay(1, function()
        for x = 1, 3 do
            local Slot = PlayerItems[Player][x]
            if Slot.Name == "None" then continue end

            local Info = ItemInfo[Slot.Name]

            ItemService:EquipItem(Player, x, Info.Name)
        end
    
        if not CurrentItems then return end
        Remotes.ItemService.ItemSlotsUpdated:Fire(Player, CurrentItems)
    end)

end

return ItemService