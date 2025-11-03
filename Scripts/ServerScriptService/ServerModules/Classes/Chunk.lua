-- OmniRal

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local Utility = require(ReplicatedStorage.Source.SharedModules.Other.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PERIMETER_SLOT_EDGE_TOLERANCE = 0.4 -- How close a slot can be near the edge lines of a chunks bounding box in order to be used as a perimeter slot 

local DRAW_CHUNK_BOXES = false
local SHOW_CHUNK_SLOTS_OPEN = false
local SHOW_CHUNK_ID = true

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Chunk = {}
Chunk.__index = Chunk

local Assets = ServerStorage.Assets

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Checks through a hubs chunk connections, and adds whichever ones are not already in side of the BaseChunks connected chunks list
local function CheckHubChunksToAdd(BaseChunk: CustomEnum.Chunk, ThisHub: CustomEnum.Hub)
	for _, OtherChunk in ThisHub.ChunkConnections do
		task.wait()
		
		if not OtherChunk or OtherChunk == BaseChunk then continue end
		if table.find(BaseChunk.ConnectedChunks, OtherChunk) then continue end
		table.insert(BaseChunk.ConnectedChunks, OtherChunk)
	end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Chunk.new(ID: number): CustomEnum.Chunk
	local self: CustomEnum.Chunk = setmetatable({}, Chunk)
	
	self.SystemType = "Chunk"
	self.ID = ID
	self.CFrame = CFrame.new(0, 0, 0)
	self.Size = Vector3.new(0, 0, 0)
	self.Rooms = {}
	self.Hubs = {}
	self.ConnectedChunks = {}
	
	print("NEW CHUNK")
	print(self)
	
	return self
end

-- Sets the CFrame center and size of the chunk based on the rooms the chunk has. 
function Chunk:FinalizeBoundingBox()
	local self: CustomEnum.Chunk = self
	
	local TempModel = Instance.new("Model")
	TempModel.Name = "TempModel"
	TempModel.Parent = Workspace

	local OriginalParents: {Instance} = {}

	-- Move rooms into the temp model
	for _, Room in ipairs(self.Rooms) do
		table.insert(OriginalParents, Room.Build.Parent)
		Room.Build.Parent = TempModel
	end

	local CF, Size = TempModel:GetBoundingBox()

	if DRAW_CHUNK_BOXES or SHOW_CHUNK_ID then
		local Box = Utility:CreateDot(CF, Size, Enum.PartType.Block, Color3.fromRGB(100, 225, 100))
		
		local Gui = Assets.Other.ChunkGui:Clone()
		Gui.Parent = Box
		Gui._1.Text = self.ID
		
		Box.Transparency = if DRAW_CHUNK_BOXES then 0.5 else 1
	end
	
	-- Put rooms back into their original parent
	for n, Parent in ipairs(OriginalParents) do
		self.Rooms[n].Parent = Parent
	end
	
	self.CFrame = CF
	self.Size = Size
end

-- Get the open slots around the perimeter of a chunk
function Chunk:GetChunkOpenPerimeterSlots(HallWidth: number)
	local self: CustomEnum.Chunk = self
	
	local Sides = {
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, -1),
		Vector3.new(1, 0, 0),
		Vector3.new(0, 0, 1),
	}
	local SideColors = {
		Color3.fromRGB(255, 50, 50),
		Color3.fromRGB(100, 255, 100),
		Color3.fromRGB(50, 150, 255),
		Color3.fromRGB(255, 100, 255),
	}

	local GotSlots: {
		{Room: CustomEnum.Room, SlotNum: number}
	} = {}

	for Index, Side in ipairs(Sides) do

		local Point = self.CFrame * CFrame.new(
			Side.X * ((self.Size.X / 2) + (HallWidth * 2)), 
			0, 
			Side.Z * ((self.Size.Z / 2) + (HallWidth * 2))
		)

		Point = CFrame.new(Point.Position, self.CFrame.Position) -- Set up a point on the outside of the perimeter (of the chunk), facing towards it from the given side

		if SHOW_CHUNK_SLOTS_OPEN then
			local Dot = Utility:CreateDot(Point, Vector3.new(4, 4, 4), Enum.PartType.Block, SideColors[Index])
			Dot.FrontSurface = "Hinge"
		end

		for _, Room in self.Rooms do
			if not Room then continue end

			for Num, Slot in ipairs(Room.Slots) do
				if not Slot.Open or not Slot.SlotPart then continue end

				-- Make sure the point and slot are facing eachother
				local Dot_P = Point.LookVector:Dot(Slot.SlotPart.CFrame.LookVector)
				if Dot_P > -0.99 then continue end -- Tolerance

				-- Make sure the point is somewhat near that side of the perimeter
				local Relative_CFrame = Point:PointToObjectSpace(Slot.SlotPart.Position)
				if #self.Rooms > 1 and math.abs(Relative_CFrame.Z) > self.Size.Z * PERIMETER_SLOT_EDGE_TOLERANCE then continue end

				if SHOW_CHUNK_SLOTS_OPEN then
					Slot.SlotPart.Transparency = 0
					Slot.SlotPart.Color = SideColors[Index]
				end

				table.insert(GotSlots, {Room = Room, SlotNum = Num})
			end
		end
	end

	return GotSlots
end

-- Gets the perimeter hubs created for this chunk, with their Start and Goal rooms they were assigned to
function Chunk:GetPerimeterHubConnections(): { {Room: CustomEnum.Room, Hub: CustomEnum.Hub, StartSlot: CustomEnum.Slot, GoalSlot: CustomEnum.Slot} }
	local self: CustomEnum.Chunk = self
	
	local List: {
		{Room: CustomEnum.Room, Hub: CustomEnum.Hub, StartSlot: CustomEnum.Slot, GoalSlot: CustomEnum.Slot}
	} = {}
	
	for _, Hub in self.Hubs do
		if not Hub then continue end
		
		-- The first room the hub was branched out of
		if Hub.StartRoom.Room and Hub.StartRoom.SlotNum then
			local StartSlot = Hub.StartRoom.Room.Slots[Hub.StartRoom.SlotNum]
			local GoalSlot = Hub.Slots[Hub.StartRoom.Hub_SlotNum]
			
			table.insert(List, {
				Room = Hub.StartRoom.Room,
				Hub = Hub,
				StartSlot = StartSlot,
				GoalSlot = GoalSlot
			})
		end

		-- The room branched from this hub that was used to start a new chunk
		if #Hub.GoalRooms > 0 then
			for _, GoalRoom in Hub.GoalRooms do
				if not GoalRoom then continue end
				if not GoalRoom.Room or not GoalRoom.SlotNum then continue end
				
				local StartSlot = GoalRoom.Room.Slots[GoalRoom.SlotNum]
				local GoalSlot = Hub.Slots[GoalRoom.Hub_SlotNum]

				table.insert(List, {
					Room = GoalRoom.Room,
					Hub = Hub,
					StartSlot = StartSlot,
					GoalSlot = GoalSlot
				})
			end
		end
	end
	
	return List
end

-- Updates what chunks this chunk connects to through their hubs and rooms
function Chunk:UpdateConnections()
	local self: CustomEnum.Chunk = self
	
	for _, Hub in self.Hubs do
		if not Hub then continue end
		if not Hub.ChunkConnections then continue end

		CheckHubChunksToAdd(self, Hub)
	end
	
	for _, Room in self.Rooms do
		if not Room then continue end
		if not Room.ClosedSlots then continue end
		if #Room.ClosedSlots <= 0 then continue end
		
		for _, SlotNum in Room.ClosedSlots do
			local Slot = Room.Slots[SlotNum]
			if not Slot then continue end
			if not Slot.ConnectTo then continue end
			
			if Slot.ConnectTo.SystemType == "Hub" then
				CheckHubChunksToAdd(self, Slot.ConnectTo)
			
			elseif Slot.ConnectTo.SystemType == "Room" then
				if Slot.ConnectTo.Chunk == self or table.find(self.ConnectedChunks, Slot.ConnectTo.Chunk) then continue end
				table.insert(self.ConnectedChunks, Slot.ConnectTo.Chunk)
			end
		end
	end
end

return Chunk