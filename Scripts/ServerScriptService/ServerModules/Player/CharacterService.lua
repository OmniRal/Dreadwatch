--OmniRal

local CharacterService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
local SignalService = require(ServerScriptService.Source.ServerModules.General.SignalService)
local WeaponService = require(ServerScriptService.Source.ServerModules.General.WeaponService)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Sides = {-1, 1}
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function TestButtons()
    local function SetButton(Button: any)
        if not Button then return end
        Button:SetAttribute("Debounce", false)

        Button.Touched:Connect(function(Hit: any)
            if Button:GetAttribute("Debounce") or not Hit.Parent then return end
            local Player = Players:FindFirstChild(Hit.Parent.Name)
            if not Player then return end

            Button:SetAttribute("Debounce", true)

            if Button.Name == "DamageButton" then
                --CharacterService:ApplyDamage("Test Damage", Player, Button:GetAttribute("Amount"), Button:GetAttribute("DamageName"), Button:GetAttribute("Type"))
            else
                --CharacterService:ApplyHealthGain("Test Heal", Player, Button:GetAttribute("Amount"), "Jizz")
            end

            task.delay(2, function()
                Button:SetAttribute("Debounce", false)
            end)
        end)
    end

    for _, Button in pairs(Workspace:GetChildren()) do
        if Button.Name ~= "DamageButton" and Button.Name ~= "HealButton" then continue end
        SetButton(Button)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function CharacterService:SetupCharacter(Player: Player, SpawnHere: CFrame?)
    task.spawn(function()
        while Player.Character == nil do task.wait() end

        local Character = Player.Character
        if Character:GetAttribute("Loaded") then return end

        warn("Loading", Player, "'s character!")
        Character:SetAttribute("Loaded", true)

        local Human, Root = Character:WaitForChild("Humanoid"), Character:WaitForChild("HumanoidRootPart")

        if SpawnHere then
            Character:PivotTo(SpawnHere)
        end

        for _, Part in pairs(Character:GetDescendants()) do
            if not Part:IsA("BasePart") then continue end
            Part.CollisionGroup = "Players"
        end

        WeaponService:EquipWeapon(Player, "BasicSword", "Default", true)

        --[[for _, Sound in pairs(Assets.Misc.CharacterSounds:GetChildren()) do
            print(Sound.Name, " added to ", Player.Name)
            Sound:Clone().Parent = Root
        end]]

        --AddNewAnimateScript(Character)
    end)
end

-- Levacy function that may be useful later?
function CharacterService:SpawnCharacter(Player: Player)
    --[[task.spawn(function()
        local PlayerData = DataService:GetProfileTable(Player)
        if not PlayerData then return end

        print("Checking player data: ", PlayerData)
        
        local CurrentChar = PlayerData.CurrentChar
        local CharData, Char = PlayerData["Char" .. CurrentChar], Player.Character

        if not CharData or not Char then return end
        local Race = CharData.Char.Race
        if not RacesInfo[Race] then return end

        local Human = Char.Humanoid
        local Shirt, Pants = Char:WaitForChild("Shirt", 10), Char:WaitForChild("Pants", 10)
        if not Shirt then
            Shirt = New.Instance("Shirt", Char)
        end
        if not Pants then
            Pants = New.Instance("Pants", Char)
        end

        Shirt.ShirtTemplate = "rbxassetid://" .. if CharData.Equipped.Shirt > 0 then CharData.Equipped.Shirt else 139501158037070
        Pants.PantsTemplate = "rbxassetid://" .. if CharData.Equipped.Pants > 0 then CharData.Equipped.Pants else 118872171199593

        for _, Object in Char:GetChildren() do
            if Object.ClassName == "Accessory" then
                if not Object:FindFirstChild("Handle") then
                    Object:Destroy()
                    continue
                end

                if Object.Handle:FindFirstChild("HairAttachment") then
                    Object.Handle.TextureID = ""
                    Object.Handle.Color = RacesInfo[Race].HairColors["Hair " .. CharData.Char.HairColor]
                else
                    Object:Destroy()
                end
            end
        end

        local Head = Char:WaitForChild("Head", 3)
        local Face = Head:WaitForChild("face", 3)
        if Face then
            Face.Texture = "rbxassetid://" .. RacesInfo[Race].Faces["Face " .. CharData.Char.Face]
        end

        local BodyColors = Char:WaitForChild("Body Colors", 3)
        if BodyColors then
            local SkinTone = RacesInfo[Race].SkinColors["Color " .. CharData.Char.SkinTone]
            BodyColors.HeadColor3 = SkinTone
            BodyColors.TorsoColor3 = SkinTone
            BodyColors.LeftArmColor3 = SkinTone
            BodyColors.RightArmColor3 = SkinTone
            BodyColors.LeftLegColor3 = SkinTone
            BodyColors.RightLegColor3 = SkinTone
        end

        for Scaler, Val in RacesInfo[Race].Scales do
            if not Human:FindFirstChild(Scaler) then continue end
            Human[Scaler].Value = Val
        end        
        
        Player:SetAttribute("Race", Race)
        UnitValuesService:RecalculateAttributes(Player, RacesInfo[Race].BaseStats, RacesInfo[Race].BaseAttributes)
    end)]]
end

-- Plainly adds or subtracts to a units attribute; e.g. players passively gaining health over time.
function CharacterService:IncrementAttribute(Source: Player | Model | string, Receiver: Player | Model, Amount: number)
    if not Source or not Receiver then return end

    local ReceiverModel = Receiver
    if Receiver:IsA("Player") then
        ReceiverModel = Receiver.Character
    end

    if not ReceiverModel then return end
end

function CharacterService:Init()
    --TestButtons()
end

return CharacterService