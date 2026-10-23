--!strict
-- Every sound in the game. Each event is one or more layers played together, so a
-- headshot can be a sharp "tink" and a deep thump at once.
--
-- PLACEHOLDERS: these use sounds that ship with Roblox so the game isn't silent.
-- To use your own: upload an audio file at create.roblox.com (Creations → Audio),
-- copy its ID, and replace the Id here with "rbxassetid://<the number>".

export type Layer = {
	Id: string,
	Volume: number,
	Pitch: number,
	PitchVariation: number?, -- random ± added to Pitch each play
}

export type SoundEvent = { Layer }

local Events: { [string]: SoundEvent } = {
	-- Sniper
	Fire = {
		{ Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.7, Pitch = 1.35, PitchVariation = 0.04 },
		{ Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = 0.5 },
	},
	Bolt = {
		{ Id = "rbxasset://sounds/clickfast.wav", Volume = 0.8, Pitch = 0.75 },
	},
	ReloadStart = {
		{ Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5, Pitch = 0.7 },
	},
	ReloadFinish = {
		{ Id = "rbxasset://sounds/clickfast.wav", Volume = 0.8, Pitch = 1.1 },
	},
	ScopeIn = {
		{ Id = "rbxasset://sounds/button.wav", Volume = 0.25, Pitch = 1.6 },
	},
	DistantShot = { -- other players' shots, played in 3D at the shooter
		{ Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.8, Pitch = 1.2, PitchVariation = 0.05 },
	},

	-- Hits (the headshot pitch also rises with the headshot streak)
	HitBody = {
		{ Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = 1.5 },
		{ Id = "rbxasset://sounds/collide.wav", Volume = 0.3, Pitch = 0.8 },
	},
	Headshot = {
		{ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 1.9 }, -- the tink
		{ Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = 0.65 }, -- the thump
		{ Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.25, Pitch = 2.2 }, -- the tail
	},
	Kill = {
		{ Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = 0.42 }, -- low boom
		{ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.15 }, -- bell ring
	},
	FlowKill = {
		{ Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.6, Pitch = 0.8 },
	},
	Damaged = {
		{ Id = "rbxasset://sounds/collide.wav", Volume = 0.6, Pitch = 0.6 },
	},

	-- Knife
	KnifeSwing = {
		{ Id = "rbxasset://sounds/swordslash.wav", Volume = 0.5, Pitch = 1.2, PitchVariation = 0.08 },
	},
	KnifeLunge = {
		{ Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.6, Pitch = 1.1 },
	},
	Slice = {
		{ Id = "rbxasset://sounds/unsheath.wav", Volume = 0.8, Pitch = 1.6 },
		{ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.5 },
	},
	Inspect = {
		{ Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.3, Pitch = 1.8 },
		{ Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Pitch = 1.3 },
	},
	Equip = {
		{ Id = "rbxasset://sounds/unsheath.wav", Volume = 0.35, Pitch = 1.2 },
	},

	-- Movement
	Jump = {
		{ Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.25, Pitch = 1.1, PitchVariation = 0.05 },
	},
	PerfectHop = {
		{ Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.3, Pitch = 1.3 },
		{ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.08, Pitch = 2.4 },
	},
	Land = {
		{ Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.35, Pitch = 1, PitchVariation = 0.05 },
	},
	Slide = {
		{ Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.35, Pitch = 1.8 },
	},
	WallKick = {
		{ Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.35, Pitch = 1.6 },
		{ Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.4, Pitch = 1.3 },
	},
	Slingshot = {
		{ Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.6, Pitch = 1.1 },
	},
	OverflowStart = {
		{ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 0.8 },
		{ Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.45, Pitch = 0.7 },
	},

	-- Menus and match
	UiHover = {
		{ Id = "rbxasset://sounds/clickfast.wav", Volume = 0.15, Pitch = 1.8 },
	},
	UiClick = {
		{ Id = "rbxasset://sounds/button.wav", Volume = 0.3, Pitch = 1.2 },
	},
	MatchStart = {
		{ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 0.9 },
	},
	MatchEnd = {
		{ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 0.6 },
	},
}

local SoundConfig = {
	Events = Events,

	-- Looping wind that gets louder with speed.
	Wind = { Id = "rbxasset://sounds/action_falling.mp3", MinSpeed = 20, MaxSpeed = 48, MaxVolume = 0.35 },

	HeadshotStreakPitchStep = 0.03, -- +3% pitch per headshot in a row
	HeadshotStreakPitchMax = 0.15,

	DistantShotRange = 600, -- 3D shots fade out by this distance
}

return SoundConfig
