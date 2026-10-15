-- HFFClient
-- Entry point for the Human Fall Flat style controller and HUD. The logic
-- lives in the modules next to this script:
--   HFF/  Input, Rig, Drives, Controller, LegIK, Knockdown, Reactions, Grab, Camera
--   UI/   Theme, Strings, Components, Responsive and the HUD pieces
--
-- The server turns the character into a ragdoll and gives this client network
-- ownership, so every force and drive constraint is created locally and the
-- resulting motion replicates to everyone else.

local RunService = game:GetService("RunService")

local HFF = script.Parent:WaitForChild("HFF")
local UI = script.Parent:WaitForChild("UI")

local Shared = require(HFF:WaitForChild("Shared"))
local Input = require(HFF:WaitForChild("Input"))
local Rig = require(HFF:WaitForChild("Rig"))
local Controller = require(HFF:WaitForChild("Controller"))
local Knockdown = require(HFF:WaitForChild("Knockdown"))
local Camera = require(HFF:WaitForChild("Camera"))
local RemoteSmoothing = require(HFF:WaitForChild("RemoteSmoothing"))
local UIController = require(UI:WaitForChild("UIController"))

local State = Shared.State
local player = Shared.Player

local function toggleRagdoll()
	Knockdown.toggleRagdoll(State.rig)
end

local function onCharacterAdded(character: Model)
	if State.rig then
		Rig.destroy(State.rig)
		State.rig = nil
	end
	local rigState = Rig.build(character)
	if rigState and player.Character == character and character.Parent then
		State.rig = rigState
		local count = 0
		for _ in rigState.joints do
			count += 1
		end
		print(string.format("[HFF] Controller active on %s (%d joints)", character.Name, count))
	elseif rigState then
		Rig.destroy(rigState)
	end
end

print(string.format("[HFF] Client running (config version %s)", tostring(Shared.Config.Version)))

Input.start(toggleRagdoll)
Camera.start()
RemoteSmoothing.start()
UIController.start(toggleRagdoll)

Shared.Remotes.Knockdown.OnClientEvent:Connect(function(duration: number?)
	if State.rig then
		Knockdown.knockDown(State.rig, duration)
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

RunService.PreSimulation:Connect(Controller.step)
