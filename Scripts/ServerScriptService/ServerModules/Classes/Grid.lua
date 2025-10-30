-- OmniRal
--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum.LevelEnum)
local Utilities = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local GRID_SIZE = 2
local SHOW_GRID_USED = false -- Only for debugging
local DISTANCE_TO_CHANGE_DIR = 12
local MAX_PATH_SEARCH = 100

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CardDirections = {
	Vector2.new(-1, 0),
	Vector2.new(1, 0),
	Vector2.new(0, -1),
	Vector2.new(0, 1)
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Grid = {}
Grid.__index = Grid

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CalculateDistance(PointA: Vector2, PointB: Vector2): number
	return math.abs(PointA.X - PointB.X) + math.abs(PointA.Y - PointB.Y)
end

local function CFrameToVector2(ThisCFrame: CFrame): Vector2
	return Vector2.new(math.round(ThisCFrame.Position.X), math.round(ThisCFrame.Position.Z))
end

local function StringToVector2(VectorString: string): Vector2
	local Nums = string.split(VectorString, ",")
	return Vector2.new(tonumber(Nums[1]), tonumber(Nums[2]))
end

local function GetDirection(A: Vector2, B: Vector2): Vector3?
	local Diff = B - A
	local X = math.abs(Diff.X)
	local Y = math.abs(Diff.Y)

	if X > Y then
		return Vector3.new(if X > 0 then 1 else -1, 0, 0)
	elseif X < Y then
		return Vector3.new(0, 0, if Y > 0 then 1 else -1)
	end

	return -- Diagonal?
end


local function GetCorner(A: CFrame, B: Vector3): (Vector3, number)
	local RelativeCFrame = A:PointToObjectSpace(B)
	local NewCFrame = A * CFrame.new(0, 0, RelativeCFrame.Z)

	return NewCFrame.Position, RelativeCFrame.X
end

local function ArePointsClose(A: Vector2, B: Vector2): boolean?
	if not A or not B then return true end
	local Distance = (A - B).Magnitude
	return Distance <= 0.2
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Grid.new(Center: CFrame)
	local self: CustomEnum.Grid = setmetatable({}, Grid)
	
	self.Center = Center
	self.Occupied = {} :: {Vector2}
	
	return self
end

function Grid:CheckPartsOccupy(Parts: {BasePart | {CFrame: CFrame, Size: Vector3}}): {Vector2}?
	local Occupied = {}

	for _, Part in Parts do
		if not Part then continue end

		local StartFrom = Part.CFrame * CFrame.new((-Part.Size.X / 2) + (GRID_SIZE / 2), 0, (-Part.Size.Z / 2) + (GRID_SIZE / 2))
		for x = 0, (Part.Size.X / GRID_SIZE) - 1 do
			for z = 0, (Part.Size.Z / GRID_SIZE) - 1 do
				local Point = StartFrom * CFrame.new(x * (GRID_SIZE), 0, z * (GRID_SIZE))
				table.insert(Occupied, Vector2.new(math.floor(Point.Position.X + 0.5), math.floor(Point.Position.Z + 0.5)))
			end
		end

		--[[local StepX = math.floor(Part.Size.X / 4)
		local StepZ = math.floor(Part.Size.Z / 4)

		local OffsetX = -(StepX // 2) * 4
		local OffsetZ = -(StepZ // 2) * 4

		for x = 0, StepX - 1 do
			for z = 0, StepZ - 1 do
				local Pos = Part.CFrame * CFrame.new(OffsetX + x * 4, 0, OffsetZ + z * 4)
				table.insert(Occupied, Vector2.new(math.floor(Pos.Position.X + 0.5), math.floor(Pos.Position.Z + 0.5)))
			end
		end]]
	end

	return Occupied
end

function Grid:IsOccupied(Point: Vector2, Radius: number?): boolean
	local self: CustomEnum.Grid = self
	
	Radius = Radius or 0
	
	for _, OtherPoint in self.Occupied do
		if (Point - OtherPoint).Magnitude > Radius then continue end
		return true
	end
	
	return false
end

function Grid:GetNeighbors(Point: Vector2)
	local self: CustomEnum.Grid = self
	
	local Neighbors = {} :: {Vector2}
	
	for _, Direction in CardDirections do
		if self:IsOccupied(Point + Direction) then continue end 
		table.insert(Neighbors, Point + Direction)
	end
	
	return Neighbors
end

function Grid:CheckColliding(Floor: CustomEnum.Floor, Object: CustomEnum.Room)
	local self: CustomEnum.Grid = self
	
	local Occupied = self:CheckPartsOccupy(Object.FloorParts)
	if not Occupied then return end
	
	local List = {Floor.Hubs, Floor.Rooms}
	for _, Section in List do
		for _, OtherObject in Section do
			if not OtherObject then continue end
			if not OtherObject.Build then continue end
			if not OtherObject.Build.PrimaryPart then continue end
			local Distance = (Object.Build.PrimaryPart.Position - OtherObject.Build.PrimaryPart.Position).Magnitude
			if Distance > 300 then continue end
			
			for _, OtherPoint in OtherObject.Occupied do
				for _, ObjectPoint in Occupied do
					if OtherPoint ~= ObjectPoint then continue end
					return true
				end
			end 
		end
	end
	
	return false
end

-- Finalize the points a hub or room occupy
function Grid:FinalizeOccupation(Object: CustomEnum.Room)
	local self: CustomEnum.Grid = self
	
	local Check
	Check = Object.FloorParts
	
	local Occupied = self:CheckPartsOccupy(Check)
	
	for _, Point in Occupied do
		table.insert(self.Occupied, Point)
		if SHOW_GRID_USED then
			Utilities:CreateDot(
				CFrame.new(Vector3.new(Point.X, 0, Point.Y)),
				Vector3.new(1, 10, 1),
				Enum.PartType.Block,
				Color3.fromRGB(255, 100, 100),
				nil,
				Object.Build
			)
		end
	end
	
	Object.Occupied = Occupied
end

--[[

function Grid:CreatePath(Start: CFrame, Goal: CFrame, HallRadius: number): {Vector2}?
	print("________")
	print("Start looking for path")
	local self: CustomEnum.Grid = self
	
	if SHOW_GRID_USED then
		Utilities:CreateDot(Start, Vector3.new(1, 15, 1), Enum.PartType.Block, Color3.fromRGB(0, 255, 0))
		Utilities:CreateDot(Goal, Vector3.new(1, 15, 1), Enum.PartType.Block, Color3.fromRGB(255, 0, 0))
	end
	
	Start = CFrameToVector2(Start)
	Goal = CFrameToVector2(Goal)
	--HallRadius = 6--math.floor(( Utilities:SnapUp(HallRadius, 4) / 4) / 2)
	--HallRadius += 2
	
	local Open = {[tostring(Start)] = true}
	local CameFrom = {} :: {[string]: string}
	local GScore = {[tostring(Start)] = 0}
	local FScore = {[tostring(Start)] = CalculateDistance(Start, Goal)}
	
	print("START : ", Start)
	print("GOAL : ", Goal)
	
	local PathSearchNum = 0
	
	while next(Open) do
		local CurrentKey: string, CurrentPoint: Vector2
		local LowestF = math.huge
		
		for Key in Open do
			local F = FScore[Key] or math.huge
			if F >= LowestF then continue end
			LowestF = F
			CurrentKey = Key
		end
		
		CurrentPoint = StringToVector2(CurrentKey)
		
		if (CurrentPoint - Goal).Magnitude <= 1.1 then
			local PathPoints = {}
			local StepKey = CurrentKey
			while StepKey do
				local StepPoint = StringToVector2(StepKey)
				table.insert(PathPoints, 1, StepPoint)
				StepKey = CameFrom[StepKey]
			end
			
			for _, Point in PathPoints do
				table.insert(self.Occupied, Point)
			end
			
			warn("Path found!")
			
			return PathPoints
		end
		
		Open[CurrentKey] = nil
		
		for _, Dir in CardDirections do
			local NeighborPoint = CurrentPoint + (Dir * GRID_SIZE)
			local NeighborKey = tostring(NeighborPoint)
			
			--Utilities:CreateDot(CFrame.new(NeighborPoint.X, 0, NeighborPoint.Y), Vector3.new(1, 15, 1), Enum.PartType.Block, Color3.fromRGB(255, 255, 0))
			
			if self:IsOccupied(NeighborPoint, HallRadius) then
				if (NeighborPoint - Goal).Magnitude > 1.1 then
					continue 
				end
			end
			
			local TempG = (GScore[CurrentKey] or math.huge) + 1
			
			if TempG < (GScore[NeighborKey] or math.huge) then
				CameFrom[NeighborKey] = CurrentKey
				GScore[NeighborKey] = TempG
				FScore[NeighborKey] = TempG + CalculateDistance(NeighborPoint, Goal)
				Open[NeighborKey] = true
				
			end
		end
		
		PathSearchNum += 1
		if PathSearchNum > MAX_PATH_SEARCH then
			break
		end
	end
	
	print("No path found.")
	
	return {}
end

function Grid:SimplifyPath(Path: {Vector2}, GoalPoint: Vector2): {Vector2}
	local self: CustomEnum.Grid = self
	local CorePoints = {Path[1]}
	local CurrentDir = GetDirection(Path[1], Path[2])

	for n = 2, #Path - 1 do
		local NewDir = GetDirection(Path[n], Path[n + 1])

		if NewDir ~= CurrentDir then
			local Vector = Vector3.new(CorePoints[#CorePoints].X, 0, CorePoints[#CorePoints].Y)
			local A = CFrame.new(Vector, Vector + CurrentDir)
			local B = Vector3.new(Path[n].X, 0, Path[n].Y)
			
			local OffsetCorner = GetCorner(A, B)
			local Distance = (B - OffsetCorner).Magnitude

			if Distance >= DISTANCE_TO_CHANGE_DIR then
				CurrentDir = NewDir
				table.insert(CorePoints, Vector2.new(OffsetCorner.X, OffsetCorner.Z))
				
			end
		end
	end
	
	local FinalDir = GetDirection(Path[#Path - 1], GoalPoint)
	local AngleDir = (CorePoints[#CorePoints] - GoalPoint).Unit
	
	if CurrentDir ~= FinalDir or not Utilities:IsLineStraight(AngleDir) then
		local Vector = Vector3.new(CorePoints[#CorePoints].X, 0, CorePoints[#CorePoints].Y)
		local A = CFrame.new(Vector, Vector + CurrentDir)
		local B = Vector3.new(Path[#Path].X, 0, Path[#Path].Y)
		local OffsetCorner, OffsetX = GetCorner(A, B)

		table.insert(CorePoints, Vector2.new(OffsetCorner.X, OffsetCorner.Z))
		
		if math.abs(OffsetX) > 0.2 and not ArePointsClose(CorePoints[#CorePoints], Path[#Path]) then
			table.insert(CorePoints, Path[#Path])
		end

	else
		if not ArePointsClose(CorePoints[#CorePoints], GoalPoint) then
			table.insert(CorePoints, GoalPoint)
		end
	end
	

	return CorePoints
end

-- Adds the points between the start and goal into the occupied list of the grid
function Grid:FinalizeStraightPath(Start: CFrame, Goal: CFrame)
	local self: CustomEnum.Grid = self
	
	for x = 1, 100 do
		local Point = Start * CFrame.new(0, 0, (-1 * x) * GRID_SIZE)
		if (Point.Position - Goal.Position).Magnitude <= GRID_SIZE / 1.5 then break end
		local Vector2 = CFrameToVector2(Point)
		if table.find(self.Occupied, Vector2) then continue end
		
		Utilities:CreateDot(Point, Vector3.new(1, 15, 1), Enum.PartType.Block, Color3.fromRGB(200, 80, 200))
		table.insert(self.Occupied, Vector2)
	end
end

]]

return Grid