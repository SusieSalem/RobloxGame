-- Shared
-- Things every client module needs: config, remotes, the local player and the
-- mutable controller state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(script.Parent.Signal)

local Config = require(ReplicatedStorage:WaitForChild("HFFMovementConfig"))
if Config.Version ~= 22 then
	warn("[HFF] HFFMovementConfig is out of date; sync ReplicatedStorage/HFFMovementConfig.luau again")
end

local remotes = ReplicatedStorage:WaitForChild("HFFRemotes")

local Shared = {
	Config = Config,
	Player = Players.LocalPlayer,
	Remotes = {
		Grab = remotes:WaitForChild("Grab") :: RemoteEvent,
		Knockdown = remotes:WaitForChild("Knockdown") :: RemoteEvent,
	},
	GRIP_NAME = "HFFGrip",

	State = {
		rig = nil, -- current character controller (Rig.build), nil while dead/loading
		jumpQueued = false,
		mouseFree = not Config.CameraLockMouse,
	},

	-- Fired by the input module when the player switches device:
	-- "KeyboardMouse", "Gamepad" or "Touch".
	InputModeChanged = Signal.new(),
	-- Fired when a setting changes from the settings menu: (name, value).
	SettingChanged = Signal.new(),
}

return Shared
