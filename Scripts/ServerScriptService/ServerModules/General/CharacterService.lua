--OmniRal

local CharacterService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

local DataService = require(ServerScriptService.Source.ServerModules.Top.DataService)
--local UnitAttributeService = require(ServerScriptService.Source.ServerModules.Units.UnitAttributeService)
--local WorldUIService = require(ReplicatedStorage.Source.SharedModules.UI.WorldUIService)


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Sides = {-1, 1}
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------
-- Private API --
-----------------

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
                CharacterService:ApplyDamage("Test Damage", Player, Button:GetAttribute("Amount"), Button:GetAttribute("DamageName"), Button:GetAttribute("Type"))
            else
                CharacterService:ApplyHealthGain("Test Heal", Player, Button:GetAttribute("Amount"), "Jizz")
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
----------------
-- Public API --
----------------

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
        UnitAttributeService:RecalculateAttributes(Player, RacesInfo[Race].BaseStats, RacesInfo[Race].BaseAttributes)
    end)]]
end

function CharacterService:ApplyDamage(Source: Player | Model | string, Victim: Player | Model, Damage: number, DamageName: string, DamageType: string, CritPossible: boolean?)
    if not Source or not Victim then return end

    local VictimModel = Victim
    if Victim:IsA("Player") then
        VictimModel = Victim.Character
    end

    if not VictimModel then return end
    local AttributesFolder = VictimModel:FindFirstChild("UnitAttributes")
    if not AttributesFolder then return end

    local TotalDamage = Damage
    local IsCrit = false
    local TrueStrike = false
    local Missed = false
    local Evade = false

    local From, Affects, DisplayType, Position, OtherDetails = Source, Victim.Name, CustomEnum.TextDisplayType.KillerDamage, Vector3.new(0, 0, 0), {}

    local SourceAttributes
    if typeof(Source) ~= "string" then
        SourceAttributes = UnitAttributeService:Get(Source) :: CustomEnum.UnitAttributes

        if DamageType == CustomEnum.DamageType.Physical then
            TotalDamage += math.clamp(SourceAttributes.Base.PhysicalDamageAmp + SourceAttributes.Offsets.PhysicalDamageAmp, CustomEnum.BaseAttributeLimits.PhysicalDamageAmp.Min, CustomEnum.BaseAttributeLimits.PhysicalDamageAmp.Max)
            
            local MissChance = math.clamp(SourceAttributes.Base.MissChance + SourceAttributes.Offsets.MissChance, CustomEnum.BaseAttributeLimits.MissChance.Min, CustomEnum.BaseAttributeLimits.MissChance.Max)
            if RNG:NextInteger(1, 100) <= MissChance then
                Missed = true
            end
            
            if CritPossible then
                local CritChance = SourceAttributes.Base.CritChance + SourceAttributes.Offsets.CritChance
                if RNG:NextInteger(1, 100) <= CritChance then
                    IsCrit = true
                    TotalDamage += (TotalDamage * ((SourceAttributes.Base.CritPercent + SourceAttributes.Offsets.CritPercent) / 100))

                    DisplayType = CustomEnum.TextDisplayType.Crit
                end
            end

        elseif DamageType == CustomEnum.DamageType.Magical then
            TotalDamage += math.clamp(SourceAttributes.Base.MagicalDamageAmp + SourceAttributes.Offsets.MagicalDamageAmp, CustomEnum.BaseAttributeLimits.MagicalDamageAmp.Min, CustomEnum.BaseAttributeLimits.MagicalDamageAmp.Max)
        elseif DamageType == CustomEnum.DamageType.Pure then
            
        end

        local KillerTrueStrike = math.clamp(SourceAttributes.Base.TrueStrike + SourceAttributes.Offsets.TrueStrike, CustomEnum.BaseAttributeLimits.TrueStrike.Min, CustomEnum.BaseAttributeLimits.TrueStrike.Max)
        if RNG:NextInteger(1, 100) <= KillerTrueStrike then
            TrueStrike = true
        end

        From = Source.Name
    end

    local VictimAttributes = UnitAttributeService:Get(Victim) :: CustomEnum.UnitAttributes
    if not VictimAttributes then return end

    if DamageType == CustomEnum.DamageType.Physical then
        TotalDamage -= (TotalDamage * (math.clamp(VictimAttributes.Base.Armor + VictimAttributes.Offsets.Armor, CustomEnum.BaseAttributeLimits.Armor.Min, CustomEnum.BaseAttributeLimits.Armor.Max) / 100))
    elseif DamageType == CustomEnum.DamageType.Magical then
        TotalDamage -= (TotalDamage * math.clamp(VictimAttributes.Base.MagicalResist + VictimAttributes.Offsets.MagicalResist, CustomEnum.BaseAttributeLimits.MagicalResist.Min, CustomEnum.BaseAttributeLimits.MagicalResist.Max) / 100)
    elseif DamageType == CustomEnum.DamageType.Pure then

    end

    if DamageType == CustomEnum.DamageType.Physical or DamageType == CustomEnum.DamageType.Pure then
        local VictimEvasion = math.clamp(VictimAttributes.Base.Evasion + VictimAttributes.Offsets.Evasion, CustomEnum.BaseAttributeLimits.Evasion.Min, CustomEnum.BaseAttributeLimits.Evasion.Max)
        if Missed or RNG:NextInteger(1, 100) <= VictimEvasion then
            if not TrueStrike then
                Evade = true
                if not Missed then
                    DisplayType = CustomEnum.TextDisplayType.Miss
                else
                    DisplayType = CustomEnum.TextDisplayType.AttackMiss
                end
            else
                OtherDetails.TrueStrikeDamage = true
            end
        end
    end

    local RootPart = VictimModel.PrimaryPart

    if not RootPart then return end

    Position = RootPart.Position + Vector3.new(
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25)
    )

    TotalDamage = math.round(TotalDamage)

    if TotalDamage < 0 then return end
    
    if not Evade then
        AttributesFolder.Current.Health.Value = math.clamp(AttributesFolder.Current.Health.Value - TotalDamage, 0, VictimAttributes.Base.Health + VictimAttributes.Offsets.Health)
        OtherDetails.Amount = TotalDamage
    end
    
    local HistoryEntry : CustomEnum.HistoryEntry = {
        Source = Source,
        Name = DamageName,
        Type = CustomEnum.HistoryEntryType.Damage,
        Amount = TotalDamage,
        TimeAdded = os.clock(),
        CleanTime = CustomEnum.DefaultHistoryEntryCleanTime
    }
    UnitAttributeService:AddHistoryEntry(Victim, HistoryEntry)
    Remotes.VisualService.SpawnTextDisplay:FireAll(From, Affects, DisplayType, Position, OtherDetails)
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

function CharacterService:ApplyHealthGain(Source: Player | Model | string, Receiver: Player | Model, Amount: number, GainName: string?)
    if not Source or not Receiver then return end

    local ReceiverModel = Receiver
    if Receiver:IsA("Player") then
        ReceiverModel = Receiver.Character
    end

    if not ReceiverModel then return end

    local ReceiverAttributes, AttributesFolder = UnitAttributeService:Get(Receiver) :: CustomEnum.UnitAttributes, ReceiverModel:FindFirstChild("UnitAttributes")
    if not ReceiverAttributes or not AttributesFolder then return end

    AttributesFolder.Current.Health.Value = math.clamp(AttributesFolder.Current.Health.Value + Amount, 0, ReceiverAttributes.Base.Health + ReceiverAttributes.Offsets.Health)

    if not GainName then return end

    local From, Affects, DisplayType, Position, OtherDetails = Source, Receiver.Name, CustomEnum.TextDisplayType.HealthGain, Vector3.new(0, 0, 0), {Amount = Amount}

    if typeof(Source) ~= "string" then
        From = Source.Name
    end

    local RootPart = ReceiverModel.PrimaryPart
    if not RootPart then return end

    Position = RootPart.Position + Vector3.new(
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25),
        math.sign(RNG:NextNumber(-1, 1)) * RNG:NextNumber(0.75, 1.25)
    )

    local HistoryEntry : CustomEnum.HistoryEntry = {
        Source = Source,
        Name = GainName,
        Type = CustomEnum.HistoryEntryType.HealthGain,
        Amount = Amount,
        TimeAdded = os.clock(),
        CleanTime = CustomEnum.DefaultHistoryEntryCleanTime,
    }
    UnitAttributeService:AddHistoryEntry(Receiver, HistoryEntry)
    Remotes.VisualService.SpawnTextDisplay:FireAll(From, Affects, DisplayType, Position, OtherDetails)
end

function CharacterService:ApplyManaGain(Source: Player | Model | string, Receiver: Player | Model, Amount: number, GainName: string?)
    if not Source or not Receiver then return end

    local ReceiverModel = Receiver
    if Receiver:IsA("Player") then
        ReceiverModel = Receiver.Character
    end

    if not ReceiverModel then return end

    local ReceiverAttributes, AttributesFolder = UnitAttributeService:Get(Receiver) :: CustomEnum.UnitAttributes, ReceiverModel:FindFirstChild("UnitAttributes")
    if not ReceiverAttributes or not AttributesFolder then return end

    AttributesFolder.Current.Mana.Value = math.clamp(AttributesFolder.Current.Mana.Value + Amount, 0, ReceiverAttributes.Base.Mana + ReceiverAttributes.Offsets.Mana)
end

function CharacterService:Init()
    TestButtons()
end

return CharacterService