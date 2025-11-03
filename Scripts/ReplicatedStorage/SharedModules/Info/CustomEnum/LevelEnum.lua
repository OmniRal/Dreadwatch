-- OmniRal

local LevelEnum = {}

export type SystemType = "Slot" | "Hall" | "Room" | "Chunk" | "Biome" | "Level"

export type Slot = {
    SystemType: SystemType,
    Open: boolean, -- If the slot can allow a connection
    Index: number, -- Identification
    SlotPart: BasePart, -- This part is inside the room, represents where the slot is and which way it's facing.
    ConnectedTo: Hall? | Room?,
}

export type Hall = {
    SystemType: SystemType,

    CFrame: CFrame,
    Size: Vector3,
    Build: Model,
    Occupied: {Vector2},

    FloorParts: {BasePart}, -- The core floor pieces that the grid system will use to figure out what space it occupies

    Slots: {[number]: Slot},
    OpenSlots: {number},
    ClosedSlots: {number},

    Decor: {BasePart? | Model?},
}

export type RoomType = "Normal" | "Trap" | "Miniboss" | "Boss" | "Shop" | "Lore"
export type Room = {
    SystemType: SystemType,
    
    Name: string,
    RoomType: RoomType,
    Values: {any}, -- Rooms don't need this, but handy if certain rooms have specific functionality; such as traps 

    CFrame: CFrame,
    Size: Vector3,
    Build: Model,
    Occupied: {Vector2},

    FloorParts: {BasePart},

    Slots: {[number]: Slot},
    OpenSlots: {number},
    ClosedSlots: {number},

    Players: {Player}, -- Each room will track which players are in it
    
    Spawners: {}, -- Still need to be defined, these will be the spawners, which manage their own NPCs
    NPCs: {}, -- Still need to be define, will mostly contain enemies, occasionaly friendly NPCs

    Decor: {BasePart? | Model?},

    Lighting: UniqueLighting?, -- Rooms don't _need_ to have custom lighting like biomes, but the option is there
}

export type Chunk = {
    SystemType: SystemType,
    
    Model: Model, -- Easy reference 
    Rooms: {Room},
    Halls: {Hall},

    Biome: string?,
    
    Amount_Rooms: NumberRange?, -- Amount of rooms that can be in this chunk
    Amount_Choices: NumberRange?, -- Amount of choices that can be given
    SpecificRooms: {string}?,
    
    TitleCard: string?, -- If there is a title card, this will show up in the players UI when they first enter the chunk. Ideal for biome transitions    
}

export type BiomeTypes = "Test"
export type Biome = {
    SystemType: SystemType,

    Name: string,

    CloseSlot: (Room: Room, Slot: Slot) -> (),

	RoomMethods: {
		[string]: {
			Init: () -> ()?, -- Only happens once when the floor is done being built
			Enter: () -> ()?, -- Triggers anytime a player enters the room
			Update: () -> ()?, -- Updates the room on every frame
			Exit: () -> ()?, -- Triggers anytime a player leaves the room
		}?
	},

    Lighting: UniqueLighting,
}

export type Grid = {
    Center: Vector3,
    Occupied: {Vector2}, -- Spaces taken up
}

export type LevelScale = "Routine" | "Hazard" | "Crisis" | "Disaster" | "Cataclysm"

-- Contains everything that is within the level. From chunks, to flavor details.
export type Level = {
    Details: LevelDetails,
    Chunks: {Chunk},
    Rooms: {Room},
    Halls: {Hall},
    Grid: Grid,

    Model: Model
}

export type LevelDetails = {
    ID: number,
    Name: string,
    Description: string,
    Scale: LevelScale,

    ModelID: number,

    RandomizedLayout: boolean? -- If true, it will generate a random amount of rooms
}

-- When a biome or room has custom lighting, it can use these parameters. From their, the system can adjust the lighting accordingly
export type UniqueLighting = {
	Base: {
		Ambient: Color3?,
		Brightness: number?,
		ColorShift_Bottom: Color3?,
		ColorShift_Top: Color3?,
		EnvironmentDiffuseScale: number?,
		EnvironmentSpecularScale: number?,
		OutdoorAmbient: Color3?,
		ClockTime: number?,
		GeographicLatitude: number?,
		ExposureCompensation: number?,
	}?,
	
	Atmosphere: {
		Density: number?,
		Offset: number?,
		Color: Color3?,
		Decay: Color3?,
		Glare: number?,
		Haze: number?,
	}?,
	
	Bloom: {
		Intensity: number?,
		Size: number?,
		Threshold: number?,
	}?,
	
	DepthOfField: {
		FarIntensity: number?,
		FocusDistance: number?,
		InFocusRadius: number?,
		NearIntensity: number?,
	}?,
	
	SunRays: {
		Intensity: number?,
		Spread: number?,
	},
}

return LevelEnum