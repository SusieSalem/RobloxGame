-- Input
-- Reads movement, arms, jump and ragdoll from keyboard/mouse, gamepad and
-- touch, and tracks which kind of device the player is using.
--
-- Movement comes from Roblox's default control module when it exists, which
-- already merges keyboard, gamepad left stick and the mobile thumbstick. If the
-- game has no PlayerModule we read keyboard and gamepad ourselves.

local UserInputService = game:GetService("UserInputService")

local Shared = require(script.Parent.Shared)
local Util = require(script.Parent.Util)

local Config = Shared.Config
local State = Shared.State

local Input = {}

local controls = nil -- ControlModule, if available
local touchArmHeld = { Left = false, Right = false } -- set by the on-screen buttons
local mode = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch" else "KeyboardMouse"

local GAMEPAD_DEADZONE = 0.2

local function readKeyboardAndGamepad(): Vector3
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		z -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		z += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x += 1
	end
	local input = Vector3.new(x, 0, z)
	if input.Magnitude > 0 then
		return input.Unit
	end
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 then
			local stick = Vector3.new(state.Position.X, 0, -state.Position.Y)
			if stick.Magnitude > GAMEPAD_DEADZONE then
				return if stick.Magnitude > 1 then stick.Unit else stick
			end
		end
	end
	return Vector3.zero
end

function Input.getMode(): string
	return mode
end

function Input.isTouch(): boolean
	return mode == "Touch"
end

function Input.getMoveDirection(): Vector3
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	local input = if controls then controls:GetMoveVector() else readKeyboardAndGamepad()
	input = Vector3.new(input.X, 0, input.Z)
	if input.Magnitude < 0.05 then
		return Vector3.zero
	end
	if input.Magnitude > 1 then
		input = input.Unit
	end
	-- Keeps analog stick strength (half tilt = half speed).
	return CFrame.Angles(0, Util.getCameraYaw(), 0):VectorToWorldSpace(input)
end

function Input.isArmHeld(side: string): boolean
	if touchArmHeld[side] then
		return true
	end
	local mouseButton = if side == "Left" then Enum.UserInputType.MouseButton1 else Enum.UserInputType.MouseButton2
	local trigger = if side == "Left" then Enum.KeyCode.ButtonL2 else Enum.KeyCode.ButtonR2
	local bumper = if side == "Left" then Enum.KeyCode.ButtonL1 else Enum.KeyCode.ButtonR1
	-- Touch screens report taps as mouse clicks, so ignore the mouse there.
	return (mode ~= "Touch" and UserInputService:IsMouseButtonPressed(mouseButton))
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, trigger)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, bumper)
end

-- Called by the on-screen L / R buttons.
function Input.setTouchArm(side: string, held: boolean)
	touchArmHeld[side] = held
end

local TOUCH_TYPES = { [Enum.UserInputType.Touch] = true }
local MOUSE_KEYBOARD_TYPES = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseWheel] = true,
}

local function setMode(newMode: string)
	if newMode == mode then
		return
	end
	mode = newMode
	if mode ~= "Touch" then
		touchArmHeld.Left = false
		touchArmHeld.Right = false
	end
	Shared.InputModeChanged:Fire(mode)
end

-- onRagdoll is called when the ragdoll key/button is pressed.
function Input.start(onRagdoll: () -> ())
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Config.MouseUnlockKey then
			State.mouseFree = not State.mouseFree
			if State.mouseFree then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
			return
		end
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.RagdollKey or input.KeyCode == Config.RagdollGamepadButton then
			onRagdoll()
		elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			State.jumpQueued = true
		end
	end)

	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if TOUCH_TYPES[inputType] then
			setMode("Touch")
		elseif MOUSE_KEYBOARD_TYPES[inputType] then
			setMode("KeyboardMouse")
		elseif inputType.Name:match("^Gamepad") then
			setMode("Gamepad")
		end
	end)

	-- Keep Roblox's default controls on: they give us the mobile thumbstick and
	-- jump button, and gamepad support. The Humanoid is in the Physics state, so
	-- they can't move it themselves; we only read their move vector and Jump.
	task.spawn(function()
		local module = Shared.Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		if not module then
			return -- no default controls in this game; keyboard/gamepad fallback is used
		end
		local ok, playerModule = pcall(require, module)
		if ok and playerModule then
			controls = playerModule:GetControls()
		end
	end)
end

return Input
