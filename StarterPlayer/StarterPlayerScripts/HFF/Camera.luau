-- Camera
-- The normal Roblox camera, but it follows a smoothed point instead of the
-- wobbling ragdoll, and turns with the mouse while the cursor is locked.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Input = require(script.Parent.Input)

local Config = Shared.Config
local State = Shared.State
local player = Shared.Player

local Camera = {}

function Camera.start()
	local cameraFocus = Instance.new("Part")
	cameraFocus.Name = "HFFCameraFocus"
	cameraFocus.Anchored = true
	cameraFocus.CanCollide = false
	cameraFocus.CanQuery = false
	cameraFocus.CanTouch = false
	cameraFocus.Transparency = 1
	cameraFocus.Size = Vector3.new(0.2, 0.2, 0.2)
	cameraFocus.Parent = Workspace


	RunService:BindToRenderStep("HFFCameraFocus", Enum.RenderPriority.Camera.Value - 1, function(dt)
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local torso = character and character:FindFirstChild("UpperTorso")
		if not camera or not torso or not torso:IsA("BasePart") then
			return
		end

		local target = torso.Position + Vector3.new(0, Config.CameraHeightOffset, 0)
		local distance = (target - cameraFocus.Position).Magnitude
		if distance > 50 then
			cameraFocus.CFrame = CFrame.new(target) -- respawned or teleported: snap
		else
			local alpha = 1 - math.exp(-Config.CameraFollowSharpness * dt)
			cameraFocus.CFrame = CFrame.new(cameraFocus.Position:Lerp(target, alpha))
		end

		if camera.CameraSubject ~= cameraFocus then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = cameraFocus
		end
	end)

	-- Runs after the default camera so our mouse lock wins.
	RunService:BindToRenderStep("HFFMouseLock", Enum.RenderPriority.Camera.Value + 1, function()
		if State.mouseFree or Input.isTouch() or UserInputService:GetFocusedTextBox() then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end)

	Shared.InputModeChanged:Connect(function(mode)
		if mode == "Touch" then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end)
end

return Camera
