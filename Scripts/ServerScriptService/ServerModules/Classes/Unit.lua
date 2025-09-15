-- OmniRal
--!nocheck

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UnitInfo = require(ServerScriptService.Source.ServerModules.Info.UnitInfo)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local SHOW_STATE = false

local UPDATE_PATH_TIME = 0.25 -- in seconds of how often a unit should pathfind when going towards a target
local SHOW_PATH = true -- If TRUE, it will create bricks to visualize a path the unit is currently using

local LOSE_VISION_TIME = 4 -- How long it takes for a unit to FULLY lose vision of a target

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

export type UnitConstructor = {
    Name: string,
    Module: ModuleScript,

    SpawnPoints: {CFrame}, -- All the CFs the Unit can spawn at
    PatrolPoints: Folder | Model | {Vector3}?, -- If folder or model, it should contain parts that represent the points the unit can travel between
    PatrolStyle: UnitInfo.UnitPatrolStyle,
    UsePathfinding: boolean?,
    IdleTime: NumberRange,
    CleanDelay: NumberRange, -- How long to wait before the unit is destroyed fully. Only once this unit is gone, can it respawn (if respawning is enabled),

    OverrideChaseRange: NumberRange?,
}

export type UnitStates = "None" | "Spawning" | "Dying" | "Fixing" | "Idling" | "Patrolling" | "Chasing" | "Attacking" | "Searching" | "Stuck" | string

export type Unit = {
    Name: string,
    Module: nil,
    Info: UnitInfo.UnitBase,

    DisplayName: string,

    ChosenModel: Model,
    Model: Model?,
    Human: Humanoid?,
    Root: BasePart?,

    Alive: boolean,
    Paused: boolean,
    State: UnitStates,
    LastState: UnitStates,

    Spawning: {
        Time: number, -- When the unit spawned
        Here: CFrame, -- Where the unit spawned in last time
        Points: {CFrame}, -- Available points the unit can spawn
    },

    Death: {
        Time: number, -- When the unit died
        CleanDelay: number, -- How long before the unit is destroyed in workspace fully and removed from it's spawners list
        ReadyToClean: boolean,
    },

    Animations: {
        Base: {[string]: {Track: AnimationTrack, Set: boolean}},
        Actions: {[string]: {Track: AnimationTrack, Set: boolean}},

        CurrentAction: string,
    },

    Idle: {
        Time: NumberRange,
        Until: number,
    },

    Patrolling: {
        Style: UnitInfo.UnitPatrolStyle,
        Current: number,
        Direction: number,
        Points: {Vector3},
    }?,

    Goal: {
        Point: Vector3?,
        Reached: boolean,
        LookTo: Vector3?, -- Once reached, force the unit to look towards this
    }?,

    Path: {
        Generating: boolean,
        UsePathfinding: boolean,
        LastUpdated: number,
        Points: {Vector3}, -- Pathfinding points
        Num: number,

        Dots: {BasePart}? -- Store the bricks that visualize the path (optional)
    },

    Target: {
        Locked: boolean,
        Active: boolean,
        VisionTimer: number,
        OutOfVision: boolean,
        LastTimeSeen: number,
        LastPositionSeen: Vector3,

        Model: Model,
        Human: Humanoid,
        Root: BasePart,

        ChaseRange: NumberRange,

        Searching: {
            Active: boolean,
            Started: number,
        }
    }?,

    Attacks: {
        LastAttack: string,
        
        AllAttacks: {
            [string]: {LastTimeUsed: number, CooldownTime: number}
        }
    }?,

    StuckChecker: {
        Time: number,
        LastPosition: Vector3,
    }?,
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UNSTUCK_TIME = 15 -- How long the unit can remain stuck before the system resets that unit
local DEFAULT_ROAM_RANGE = 50

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Unit = {}
Unit.__index = Unit

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function LoadAnimations(Animator: Animator, List: {[string]: {ID: number, Priority: Enum.AnimationPriority}}): {[string]: {Track: AnimationTrack, Set: boolean}}
    if not Animator or not List then return end

    local Tracks: {[string]: {Track: AnimationTrack, Set: boolean}} = {}
    
    for Name, Info in List do
        local NewAnim = Instance.new("Animation")
        NewAnim.AnimationId = "rbxassetid://" .. Info.ID
        local NewTrack = Animator:LoadAnimation(NewAnim)
        Tracks[Name] = {Track = NewTrack, Set = false}
    end

    return Tracks
end

-- Base animations being idle, walking, running, etc. No attacks or other special actions
local function PlayBaseAnimation(List: {[string]: {Track: AnimationTrack, Set: boolean}}, Name: string, FadeTime: number?)
    if not List then return end
    if not List[Name] then return end
    if List[Name].Track.IsPlaying then return end

    List[Name].Track:Play(FadeTime)
end

local function StopBaseAnimation(List: {[string]: {Track: AnimationTrack, Set: boolean}}, Name: string, FadeTime: number?)
    if not List then return end
    if not List[Name] then return end
    if not List[Name].Track.IsPlaying then return end

    List[Name].Track:Stop(FadeTime)
end

-- Checks which attacks for a unit are eligable to be used; not on cooldown, enemy within range, etc
local function GetAvailableAttacks(Info: UnitInfo.UnitBase, List: {[string]: {LastTimeUsed: number, CooldownTime: number}},  Human: Humanoid, DistanceToTarget: number, VisionOfTarget: boolean): {{Choice: string, Chance: number}}?
    if not Info or not List or not Human then return end

    local Available: {{Choice: string, Chance: number}} = {}

    for Name, Details in List do
        if os.clock() < Details.LastTimeUsed + Details.CooldownTime then continue end
        
        local AttackInfo = Info.EnemyStats.Attacks[Name]
        if not AttackInfo then continue end
        local HealthPercent = (Human.Health / Info.BaseStats.Health) * 100
        if HealthPercent > AttackInfo.HealthThreshold then continue end
        if DistanceToTarget > AttackInfo.UseRange then continue end
        if not VisionOfTarget and not AttackInfo.DoesNotRequireVision then continue end

        table.insert(Available, {Choice = Name, Chance = AttackInfo.Chance})
    end

    return Available
end

local function IsGoalBlocked(Start: Vector3, Goal: Vector3, Ignore: {any}): boolean?
    if not Start or not Goal or not Ignore then return true end
    
    local Distance = (Start - Goal).Magnitude

    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Ignore
    Params.IgnoreWater = true

    local Ray = Workspace:Raycast(Start, (Goal - Start).Unit * Distance, Params)
    if Ray then
        if Ray.Instance then
            return  true
        end
    end

    return false
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Unit.new(NewUnit: UnitConstructor): Unit?
    local Info = UnitInfo[NewUnit.Name]
    if not Info then return end

    -- Picks an Unit model from the available selection from a specific Unit's info table
    local UnitModel = Utility:RollPick(Info.Models)
    if not UnitModel then return end
    
    local self: Unit = setmetatable({}, Unit)
    self.Name = NewUnit.Name
    self.Module = require(NewUnit.Module)
    self.Info = Info

    self.DisplayName = Info.DisplayName
    self.ChosenModel = UnitModel
    self.Model = nil
    self.Alive = false
    self.Paused = false
    self.State = "None"
    self.LastState = "None"
    
    self.Spawning = {
        Time = 0,
        Here = CFrame.new(0, 0, 0),
        Points = NewUnit.SpawnPoints,
    }

    self.Death = {
        Time = 0,
        CleanDelay = RNG:NextNumber(NewUnit.CleanDelay.Min, NewUnit.CleanDelay.Max)
    }

    self.Idle = {
        Time = NewUnit.IdleTime,
        Until = os.clock(),
    }

    ---------------------------------------------------

    if NewUnit.PatrolStyle ~= "Stationary" then
        local Points: {Vector3} = {}
        if typeof(NewUnit.PatrolPoints) == "Folder" or typeof(NewUnit.PatrolPoints) == "Model" then
            for x = 1, #NewUnit.PatrolPoints:GetChildren() do
                local Point: BasePart = NewUnit.PatrolPoints:FindFirstChild(x)
                if not Point then continue end
                table.insert(Points, Point.Position)
            end
        else
            Points = NewUnit.PatrolPoints
        end
        
        self.Patrolling = {
            Style = NewUnit.PatrolStyle,
            Current = 1,
            Direction = 1,
            Points = NewUnit.PatrolPoints,
        }

        self.Goal = {
            Point = Vector3.new(0, 0, 0),
            Reached = true,
            LookTo = nil,
        }

        self.Path = {
            Generating = false,
            UsePathfinding = NewUnit.UsePathfinding,
            LastUpdated = 0,
            Points = {},
            Num = -1,
            Dots = {},
        }

        if Info.EnemyStats then
            self.Target = {
                Locked = false,
                Active = false,
                VisionTimer = 0,
                OutOfVision = false,
                LastTimeSeen = 0,
                LastPositionSeen = Vector3.new(0, 0, 0),
                
                Model = nil,
                Human = nil,
                Root = nil,

                ChaseRange = NewUnit.OverrideChaseRange or Info.EnemyStats.ChaseRange,

                Searching = {
                    Active = false,
                    Started = 0,
                }
            }

            self.Attacks = {
                LastAttack = "None",
                AllAttacks = {},
            }

            for Name, Details in self.Info.EnemyStats.Attacks do
                self.Attacks.AllAttacks[Name] = {LastTimeUsed = 0, CooldownTime = 0}
            end
        end

        self.StuckChecker = {
            LastPosition = Vector3.new(0, 0, 0),
            Time = 0
        }
    end

    ---------------------------------------------------

    self:Spawn()

    return self
end

function Unit:ResetValues()
    local self: Unit = self

    self.Human.Health = self.Info.BaseStats.Health
    self.Human.MaxHealth = self.Info.BaseStats.Health
    self.Human.WalkSpeed = self.Info.BaseStats.WalkSpeed
        
    self.Patrolling.Current = 0
    self.Patrolling.Direction = 1

    self.Goal.Point = Vector3.new(0, 0, 0)
    self.Goal.Reached = true

    self.StuckChecker.LastPosition = Vector3.new(0, 0, 0)
    self.StuckChecker.Time = 0
end

function Unit:Spawn()
    local self: Unit = self

    if self.State == "Spawning" or self.Alive then return end

    local NewModel = self.ChosenModel:Clone()
    local SpawnHere = self.Spawning.Points[RNG:NextInteger(1, #self.Spawning.Points)]
    NewModel:PivotTo(SpawnHere)
    NewModel.Parent = Workspace.Units

    self.Spawning.Time = os.clock()
    self.Spawning.Here = SpawnHere
    self.Model = NewModel
    self.Human = NewModel:FindFirstChild("Humanoid")
    self.Root = NewModel:FindFirstChild("HumanoidRootPart")

    ---------------------------------------------------

    local Base = LoadAnimations(self.Human:FindFirstChild("Animator"), self.Info.Animations.Base)
    local Actions = LoadAnimations(self.Human:FindFirstChild("Animator"), self.Info.Animations.Actions)

    self.Animations = {
        Base = Base,
        Actions = Actions,
    }

    self.Human.StateChanged:Connect(function(Old: Enum.HumanoidStateType, New: Enum.HumanoidStateType)
        
    end)

    self.Human.Running:Connect(function(Speed: number)
        if Speed <= 0 then
            PlayBaseAnimation(self.Animations.Base, "Idle", 0.1)
            StopBaseAnimation(self.Animations.Base, "Walk", 0.1)
            StopBaseAnimation(self.Animations.Base, "Run", 0.1)

        elseif Speed > 0.1 and Speed <= self.Info.BaseStats.WalkSpeed * 1.25 then
            StopBaseAnimation(self.Animations.Base, "Idle", 0.1)
            PlayBaseAnimation(self.Animations.Base, "Walk", 0.1)
            StopBaseAnimation(self.Animations.Base, "Run", 0.1)

        elseif Speed > self.Info.BaseStats.WalkSpeed * 1.25 then
            StopBaseAnimation(self.Animations.Base, "Idle", 0.1)
            StopBaseAnimation(self.Animations.Base, "Walk", 0.1)
            PlayBaseAnimation(self.Animations.Base, "Run", 0.1)

        end
    end)

    self.Human.HealthChanged:Connect(function()
        if self.Human.Health > 0 then return end
        self:Died()
    end)

    ---------------------------------------------------

    self:ResetValues()

    self.State = "Spawning"
    self.Alive = true

    task.delay(0.5, function()
        self:SetState("None", nil, true)
    end)
end

function Unit:Died()
    local self: Unit = self

    if not self.Alive or self.State == "Dying" then return end

    self.Alive = false
    self.State = "Dying"
    self.Death.Time = os.clock()

    UnitInfo.UnitDied:Fire(self.Name)
end

function Unit:Clean()
    local self: Unit = self

    for _, Part in self.Model:GetChildren() do
        if not Part:IsA("BasePart") then continue end
        Part.Anchored = true
    end

    local CF = Instance.new("CFrameValue")
    CF.Name = "CF"
    CF.Value = self.Model.PrimaryPart.CFrame
    CF.Parent = self.Model
    
    CF.Changed:Connect(function()
        self.Model:PivotTo(CF.Value)
    end)

    local SinkCFrame = CFrame.new(self.Model.PrimaryPart.Position + Vector3.new(0, -10, 0))
    TweenService:Create(CF, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Value = SinkCFrame}):Play()
    Debris:AddItem(self.Model, 5)
end

-- Moves the unit back to its spawn area when it's stuck
function Unit:Fix()
    local self: Unit = self
    
    self.State = "Fixing"

    task.delay(0.25, function()        
        local SpawnHere = self.Spawning.Points[RNG:NextInteger(1, #self.Spawning.Points)]
        self.Spawning.Here = SpawnHere
        self.Model:PivotTo(SpawnHere)

        self:ResetValues()

        task.wait(1)

        self:SetState("None", nil, true)
    end)
end

function Unit:PlayActionAnimation(Name: string, FadeTime: number?, Speed: number?, Func: () -> ()?, ForcePlay: boolean?)
    local self: Unit = self

    local Anim = self.Animations.Actions[Name]
    
    if not Anim then return end
    if not Anim.Set then
        Anim.Set = true
        Anim.Track.KeyframeReached:Connect(function(Keyframe: string)
            if Func then
                Func(self, Name, Keyframe)
            end

            if Keyframe == "End" then
                self.Animations.CurrentAction = "None"

                if string.find(Name, "Attack") then
                    local AttackInfo = self.Info.EnemyStats.Attacks[Name]
                    self.Attacks.AllAttacks[Name].LastTimeUsed = os.clock()
                    self.Attacks.AllAttacks[Name].CooldownTime = RNG:NextNumber(AttackInfo.Cooldown.Min, AttackInfo.Cooldown.Max)

                    self:SetState("Idling")
                end
            end
        end)
    end

    if Anim.Track.IsPlaying and not ForcePlay then return end

    local CurrentAnim = self.Animations.Actions[self.Animations.CurrentAction]
    if CurrentAnim then
        CurrentAnim:Stop(FadeTime or 0)
    end

    Anim.Track:Play(FadeTime or 0, nil, Speed or 1)
end

-- Cleanly switch between states except for Spawning, Dying and Fixing
function Unit:SetState(NewState: UnitStates, Details: {any}, Force: boolean?)
    local self: Unit = self

    if (self.State == "Spawning" or self.State == "Dying" or self.State == "Fixing") and (not Force) then return end
    if self.State == NewState then return end

    self.LastState = self.State

    if self.Module then
        if self.Module[self.LastState .. "Exit"] ~= nil then
            self.Module[self.LastState .. "Exit"]()
        end
    end

    if self.LastState == "Searching" then
        self:ClearTargetSearching()
    end

    self.State = NewState

    --warn("_______________________________________")
    --warn("New State : " .. NewState)
    --warn("Last State : " .. self.LastState)
    --warn("_______________________________________")

    if NewState == "None" then
        return

    elseif NewState == "Idling" then
        self.Human:MoveTo(self.Root.Position)

        local Time = os.clock() + RNG:NextNumber(self.Idle.Time.Min, self.Idle.Time.Max)
        if Details then
            if Details.FixedTime then
                Time = Details.FixedTime
            elseif Details.AddTime then
                Time += Details.AddTime
            end
        end

        self.Idle.Until = Time

    elseif NewState == "Patrolling" then
        self:Patrol()
        if self.Goal.Point then
            if IsGoalBlocked(self.Root.Position, self.Goal.Point, {self.Model}) then
                self:CreateNewPath()
            end
        end

        if not self.Target.Locked then
            self.Human.WalkSpeed = self.Info.BaseStats.WalkSpeed

        else
            -- Return to patrolling area quicker after the target has become out of range
            self.Human.WalkSpeed = self.Info.BaseStats.RunSpeed
        end

    elseif NewState == "Chasing" then
        self.Target.Active = true
        self.Human.WalkSpeed = self.Info.BaseStats.RunSpeed

        if Details then
            self.Target.Model = Details.Target
            self.Target.Human = Details.Target.Humanoid
            self.Target.Root = Details.Target.HumanoidRootPart
        end
    
    elseif NewState == "Attacking" then
        if not self.Module then return end
        if not self.Module[Details.AttackName] then return end
        
        self.Module[Details.AttackName](self)
        self.Attacks.LastAttack = Details.AttackName
        self.Human.WalkSpeed = self.Info.BaseStats.RunSpeed * self.Info.EnemyStats.Attacks[Details.AttackName].MoveSpeedWhileAttacking

    elseif NewState == "Searching" then
        self.Target.Searching.Started = os.clock()
        self.Target.Searching.Active = true

    elseif NewState == "Stuck" then
        self.Human.WalkSpeed = 0
    end
end

function Unit:ClearOldPath()
    local self: Unit = self

    table.clear(self.Path.Points)

    if SHOW_PATH then
        for _, Dot in self.Path.Dots do
            if not Dot then continue end
            Dot:Destroy()
        end
        table.clear(self.Path.Dots)
    end

    self.Path.Num = 0
end

function Unit:CreateNewPath(Start: Vector3?, Goal: Vector3?): boolean?
    local self: Unit = self

    if not self.Info.PathParams then return end

    self.Path.Generating = true

    self:ClearOldPath()

    self.Path.Num = 1

    Start = Start or self.Root.Position
    Goal = Goal or self.Goal.Point

    local NewPath = PathfindingService:CreatePath(
        {
            AgentRadius = self.Info.PathParams.Radius or 3,
            AgentHeight = self.Info.PathParams.Height or 6,
            AgentCanJump = self.Info.PathParams.CanJump or false,
            Costs = self.Info.PathParams.Costs or {},
        }
    )
    local Success, Error = pcall(function()
        NewPath:ComputeAsync(Start, Goal)
    end)

    if Success then
        local Waypoints = NewPath:GetWaypoints()
        for x = 1, #Waypoints - 1 do
            local Point = Waypoints[x]
            table.insert(self.Path.Points, Point.Position)
            
            if not SHOW_PATH then continue end
            local Dot = Utility:CreateDot(Point.Position, Color3.fromRGB(25, 200, 255), 1, 10000)
            table.insert(self.Path.Dots, Dot)
        end

        self.Path.LastUpdated = os.clock()
    
    else
        self.Path.Num = 0

        if not SHOW_PATH then return end
        print(Error)
    end

    self.Path.Generating = false

    return Success
end

function Unit:Patrol()
    local self: Unit = self

    if not self.Goal.Reached then return end
    if self.Patrolling.Style == "Stationary" then return end 

    self.Goal.Reached = false

    if self.Patrolling.Style == "Loop" then
        self.Patrolling.Current += 1
        if self.Patrolling.Current > #self.Patrolling.Points then
            self.Patrolling.Current = 1
        end

        self.Goal.Point = self.Patrolling.Points[self.Patrolling.Current]

    elseif self.Patrolling.Style == "BackNForth" then
        if self.Patrolling.Direction == 1 then
            if self.Patrolling.Current >= #self.Patrolling.Points then
                self.Patrolling.Direction = -1
            end
        else
            if self.Patrolling.Current <= 1 then
                self.Patrolling.Direction = 1
            end
        end

        self.Patrolling.Current += self.Patrolling.Direction
        self.Goal.Point = self.Patrolling.Points[self.Patrolling.Current]

    elseif self.Patrolling.Style == "RandomPoints" then
        self.Goal.Point = (self.Spawning.Here * CFrame.Angles(0, RNG:NextNumber(-math.pi, math.pi), 0) * CFrame.new(0, 0, -RNG:NextInteger(0, self.RoamRange or DEFAULT_ROAM_RANGE)))

        local AvailablePoints: {number} = {}

        for x = 1, #self.Patrolling.Points do
            if x == self.Patrolling.Current then continue end
            table.insert(AvailablePoints, x)
        end

        local RandNum = RNG:NextInteger(1, #AvailablePoints)
        self.Patrolling.Current = RandNum
        self.Goal.Point = self.Patrolling.Points[RandNum]

    else -- For FreeRoam or a typo in PatrolStyle, lol
        self.Goal.Point = (self.Spawning.Here * CFrame.Angles(0, RNG:NextNumber(-math.pi, math.pi), 0) * CFrame.new(0, 0, -RNG:NextInteger(0, self.RoamRange or DEFAULT_ROAM_RANGE))).Position

    end

    if not self.Path.UsePathfinding then return end

    local GoalBlocked = IsGoalBlocked(self.Root.Position, self.Goal.Point, {self.Model})
    print("Patrolling to point :", self.Goal.Point)
    print("Point Blocked :", GoalBlocked)

    if GoalBlocked then
        self:CreateNewPath()
    end
end

function Unit:CanSee(Position: Vector3, GoalObject: BasePart | Model, Ignore: {}?): (boolean?, number?)
    local self: Unit = self

    if not self.Alive or not self.Info or not self.Human or not self.Root then return end

    local CanSee = false
    local Distance = (self.Root.Position - Position).Magnitude
    local Direction = (Position - self.Root.Position).Unit

    if Distance < self.Info.Vision.Range then
        CanSee = true
    end    

    if self.Info.Vision.Type == "Cone" and Distance > 14 then
        if math.deg(math.acos(self.Root.CFrame.LookVector:Dot(Direction))) > self.Info.Vision.Angle then
            CanSee = false
        end
    end

    if self.Target.Active and self.Target.Model then
        if Distance <= self.Info.Vision.Range / 2 then
            return CanSee, Distance
        end
    end

    if CanSee and GoalObject then
        local Params = RaycastParams.new()
        Params.FilterType = Enum.RaycastFilterType.Exclude
        Params.FilterDescendantsInstances = Ignore or {self.Model}
        Params.IgnoreWater = true

        local RayHitGoal = false

        local Ray = Workspace:Raycast(self.Root.Position, Direction * 1000, Params)
        if Ray then
            if (GoalObject:IsA("BasePart") and Ray.Instance == GoalObject) or (GoalObject:IsA("Model") and Ray.Instance:IsDescendantOf(GoalObject)) then
                --print("Ray Hit : " .. Ray.Instance.Name)
                --print("Goal Object : " .. GoalObject.Name)
                RayHitGoal = true
            end
        end

        if not RayHitGoal then
            CanSee = false
        end
    end

    return CanSee, Distance
end

function Unit:FindTarget(): Model?
    local self: Unit = self

    local ClosestEnemy, LastRange = nil, math.huge

    for _, Player in Players:GetPlayers() do
        if not Player then continue end
        if not Player.Character then continue end
        local Human: Humanoid, Root: BasePart = Player.Character:FindFirstChild("Humanoid"), Player.Character:FindFirstChild("HumanoidRootPart")
        if not Human or not Root then continue end
        if Human.Health <= 0 then continue end
        
        local GoalObject = Player.Character
        
        if self.Info.Vision.XRay then
            GoalObject = nil
        end
        
        local CanSee, Distance = self:CanSee(Root.Position, GoalObject)
        if not CanSee then continue end
        if Distance >= LastRange then continue end
        ClosestEnemy = Player.Character
        LastRange = Distance
    end

    return ClosestEnemy
end

function Unit:ClearTarget(Lock: boolean?, SetIdle: boolean?, AddTime: number?)
    local self: Unit = self

    self.Target.Locked = Lock or false
    self.Target.Active = false
    self.Target.Model = nil
    self.Target.Human = nil
    self.Target.Root = nil
    self.Target.OutOfVision = false
    self.Target.VisionTimer = 0

    if not SetIdle then return end
    self:SetState("Idling", {AddTime = AddTime or 0})
end

function Unit:ClearTargetSearching()
    local self: Unit = self

    self.Target.Searching.Active = false
    self.Target.Searching.Started = 0
end

function Unit:CheckTarget()
    local self: Unit = self

    local SetInactive = true

    if self.Target.Model then
        if self.Target.Human and self.Target.Root then
            if self.Target.Human.Health <= 0 then
                print("Target died; going to IDLE.")
                self:SetState("Idling")

            else
                if self.Target.Searching.Active then
                    print("Searching...")
                    if os.clock() >= self.Target.Searching.Started + self.Info.EnemyStats.SearchTime then
                        print("Target not found during search; resetting target and going to IDLE.")
                        self:ClearTarget(true, true, 2)
                        return
                    end
                end

                local UnitDistanceFromSpawn = (self.Root.Position - self.Spawning.Here.Position).Magnitude
                if UnitDistanceFromSpawn > self.Target.ChaseRange.Max then
                    print("Target out of range; going to SEARCH.")
                    self:SetState("Searching")
                    return
                end

                local CanSee, Distance = self:CanSee(self.Target.Root.Position, self.Target.Model, {self.Model})

                --print("Can See :", CanSee)
                --print("Distance : ", Distance)

                if self.Target.OutOfVision then
                    if CanSee then
                        print("Target WAS out of vision; now found and going to CHASE.")
                        self.Target.OutOfVision = false
                        self.Target.VisionTimer = 0
                        self.Target.Searching.Active = false
                        self:SetState("Chasing")
                    end

                else
                    if not CanSee then
                        if self.Target.VisionTimer <= 0 then
                            print("Started OUT OF VISION timer.")
                            self.Target.VisionTimer = os.clock()
                        
                        elseif os.clock() >= self.Target.VisionTimer + LOSE_VISION_TIME then
                            print(#self.Path.Points .. " | " .. self.Path.Num)
                            if #self.Path.Points > 0 or self.Path.Generating then
                                if self.Path.Num < #self.Path.Points then
                                    return
                                end
                            end
                            print("Target is OUT OF VISION; going to SEARCH.")
                            self.Target.OutOfVision = true
                            self.Target.LastTimeSeen = os.clock()
                            self.Target.LastPositionSeen = self.Target.Root.Position
                            self:SetState("Searching")
                        end
                    end

                    local AvailableAttacks = GetAvailableAttacks(self.Info, self.Attacks.AllAttacks, self.Human, Distance, CanSee)
                    if #AvailableAttacks <= 0 then return end

                    print("Attacks available : " .. #AvailableAttacks)

                    if not self.Module.CheckToAttack then
                        local ChosenAttack = Utility:RollPick(AvailableAttacks)
                        if not ChosenAttack then return end

                        print("Attack chosen : " .. ChosenAttack)
                        self:SetState("Attacking", {AttackName = ChosenAttack})
                    else
                        -- Run unit specific conditions before attacking
                        self.Module.CheckToAttack(self, AvailableAttacks)
                    end
                end
            end
        end
    end
end

function Unit:MoveOnPath(CheckForNewPath: boolean?, AddTime: number?)
    local self: Unit = self

    if self.Path.Generating then return end

    if #self.Path.Points <= 0 then
        self:ClearOldPath()
        return
    end
    
    local CurrentGoal = self.Path.Points[self.Path.Num]
    if not CurrentGoal then
        self.Path.Num = 0
        return
    end
    
    if (self.Root.Position - CurrentGoal).Magnitude > 5 then
        self.Human:MoveTo(CurrentGoal)
    
    else
        self.Path.Num += 1
        if self.Path.Num > #self.Path.Points then
            self.Path.Num = 0
            return
        end
    end
end

function Unit:Move()
    local self: Unit = self

    if not self.Alive then return end
    if not self.Human or not self.Root then return end

    if self.State == "Patrolling" then
        
        if not self.Goal.Reached then
            if self.Path.Num <= 0 then
                if (self.Root.Position - self.Goal.Point).Magnitude > 5 then
                    self.Human:MoveTo(self.Goal.Point)
                    
                else
                    self.Goal.Reached = true
                    if self.Target.Locked then
                        self.Target.Locked = false
                        self.Target.Active = false
                        self.Target.Model = nil
                    end
                    self:SetState("Idling") 
                end

            else
                self:MoveOnPath()
            end
        end

    elseif self.State == "Chasing" then
        local GoalPosition = self.Target.Root.Position
        if self.Target.OutOfVision then
            GoalPosition = self.Target.LastPositionSeen
        else
            if (self.Root.Position - self.Target.Root.Position).Magnitude <= self.Target.ChaseRange.Min then
                self.Human:MoveTo(self.Root.Position)
                return
            end
        end

        if IsGoalBlocked(self.Root.Position, GoalPosition, {self.Model, self.Target.Model}) then
            if self.Path.Num <= 0 then
                self:CreateNewPath(nil, GoalPosition)
            else
                if self.Target.OutOfVision then
                    if self.Path.Num >= #self.Path.Points then
                        self:SetState("Searching")
                    else
                        self:MoveOnPath()
                    end
                else
                    if self.Path.Generating or #self.Path.Points <= 0 then return end
                    if not self.Path.Points[#self.Path.Points] then 
                        self:ClearOldPath() 
                    end

                    local LastPoint = self.Path.Points[#self.Path.Points]
                    local Distance = (GoalPosition - LastPoint).Magnitude
                    if Distance > 5 then
                        self:CreateNewPath(nil, GoalPosition)
                    else
                        self:MoveOnPath()
                    end
                end
            end
        
        else
            self.Human:MoveTo(GoalPosition)
        end

        --[[if self.Path.Num <= 0 then
            if not self.Target.OutOfVision then
                self.Human:MoveTo(self.Target.Root.Position)
            
            else
                self.Human:MoveTo(self.Target.LastPositionSeen)
            end
        
        else
            self:MoveOnPath(true)
        end]]

    elseif self.State == "Attacking" then
        if (self.Root.Position - self.Target.Root.Position).Magnitude > 8 then return end
        self.Human:MoveTo(self.Target.Root.Position)

    elseif self.State == "Searching" then
        -- Continue moving to the last known position
        local GoalPosition = self.Target.LastPositionSeen
        
        -- Check if we've reached the last known position
        if (self.Root.Position - GoalPosition).Magnitude <= 5 then
            -- We've reached the spot, now just stand and search
            self.Human:MoveTo(self.Root.Position)
        else
            -- Still need to get to the last known position
            if IsGoalBlocked(self.Root.Position, GoalPosition, {self.Model}) then
                if self.Path.Num <= 0 then
                    self:CreateNewPath(nil, GoalPosition)
                else
                    self:MoveOnPath()
                end
            else
                self.Human:MoveTo(GoalPosition)
            end
        end
    end
end

function Unit:CheckStuck()
    local self: Unit = self

    if self.Patrolling.Style == "Stationary" then return end
    if self.State ~= "Patrolling" and self.State ~= "Chasing" then return end
    
    local Distance = (self.Root.Position - self.StuckChecker.LastPosition).Magnitude
    if Distance > 1 then
        self.StuckChecker.LastPosition = self.Root.Position
        self.StuckChecker.Time = os.clock()

    else
        if os.clock() < self.StuckChecker.Time + UNSTUCK_TIME then return end

        self:Fix()
    end
end

function Unit:Update()
    local self: Unit = self

    if self.Paused then return end
    if self.State == "Fixing" then return end

    if self.Alive then
        if self.State == "None" then
            if self.Patrolling.Style ~= "Stationary" then
                self:SetState("Patrolling")
            end

        elseif self.State == "Idling" then
            if os.clock() >= self.Idle.Until then
                if not self.Target.Active then
                    self:SetState("None")
                else
                    self:SetState("Chasing")
                end 
            end

        elseif self.State == "Patrolling" then
            self:Patrol()
            self:Move()

        elseif self.State == "Chasing" then
            self:CheckTarget()
            self:Move()

        elseif self.State == "Searching" then
            self:CheckTarget()

        elseif self.State == "Attacking" then
            self:Move()
        end

        if self.Info.EnemyStats and not self.Target.Locked then
            if self.State ~= "Chasing" and self.State ~= "Attacking" then
                if self.Info.EnemyStats.Agro.Is then
                    local TargetFound = self:FindTarget()
                    if TargetFound then
                        self:SetState("Chasing", {Target = TargetFound})
                    end
                end
            end
        end

        if not self.Human or not self.Root then return end
        
    else
        if os.clock() <= self.Death.Time + self.Death.CleanDelay then return end
        if self.Death.ReadyToClean then return end
        self.Death.ReadyToClean = true
    end

    if SHOW_STATE then
        print(self)
    end
end

return Unit